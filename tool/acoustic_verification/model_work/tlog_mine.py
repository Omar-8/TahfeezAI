"""TLOG for G25 (tarteel-ai/tlog, CC BY 4.0, gated — HF_TOKEN of an account that accepted it):
Tarteel app users reciting single ayahs on their own phones, ~400k clean clips in 411 parquet
files (~160 MB each, FLAC, 970 clips; the files in surah order) -> candidate shards + an index.

  HF_TOKEN=... TEACHER_WEIGHTS=teachers/teacher_ft5.pt python tlog_mine.py <out dir> \\
      --student init/v37/student.pt --test-packs tlog juz30h [--files 120] [--embed]

Per clip (as phone_mine.py, which this reuses):
- its ayah from the file name (<surah>_<ayah>_<recording id>.flac; TLOG's labels are inferred
  from it, unvalidated);
- never kept if it is a clip of a test pack (--test-packs, <pack>_audio.npz / _cases.json):
  same ayah, length within 0.3 s and waveforms correlating >= 0.8;
- the spliced-mistake benchmark's ayahs (blocked_ayahs.json) skipped;
- the teacher's forced alignment to the expected Hafs sounds: mean cost per frame <= --max-cost;
- events where the teacher is sure of an expected letter and the student (v3.7, streaming)
  prefers another: [expected, heard, student margin, teacher's mean p(expected), 1 if it is the
  teacher's own top letter there];
- with --embed, its voice: an ECAPA speaker embedding (speechbrain/spkrec-ecapa-voxceleb), and
  the test packs' clips' too (<out>/test_emb.npz) — TLOG has no user ids, so speakers are found
  by voice: tlog_select.py drops training clips of the test speakers and splits by speaker.
Writes <out>/cand_NNNN.npz (audio, offsets, targets = the expected Hafs tokens for weak CTC,
ayahs, emb) and <out>/index.json (per clip: shard, index, ayah, rec, seconds, cost, events).
Resumable: files already done (index.json's `files`) are skipped.
"""
import argparse, io, json, os, random, re
import numpy as np
import soundfile as sf
import torch
import torch.nn.functional as F
import torchaudio
import pyarrow.parquet as pq
from huggingface_hub import HfApi

import distill_student as ds
import streaming
from diverse_data import teacher_frames
from hf_ayah_data import Fit, download, find
from phone_mine import LETTERS, envelope, same_recording, spans

REPO = 'tarteel-ai/tlog'
NAME = re.compile(r'(\d+)_(\d+)_(\d+)')


class Voices:
    """ECAPA speaker embeddings (192, unit length), on the training device."""

    def __init__(self, savedir):
        from speechbrain.inference.speaker import EncoderClassifier
        self.enc = EncoderClassifier.from_hparams(source='speechbrain/spkrec-ecapa-voxceleb',
                                                  savedir=savedir, run_opts={'device': ds.DEV})

    def __call__(self, x):
        with torch.no_grad():
            e = self.enc.encode_batch(torch.from_numpy(np.ascontiguousarray(x, np.float32))[None].to(ds.DEV))[0, 0]
        return (e / e.norm()).float().cpu().numpy()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--student', required=True)
    p.add_argument('--stream', default='0.96,5.12')
    p.add_argument('--test-packs', nargs='+', required=True)
    p.add_argument('--files', type=int, default=0, help='random files to use (0: all 411)')
    p.add_argument('--seed', type=int, default=25)
    p.add_argument('--embed', action='store_true')
    p.add_argument('--sure', type=float, default=0.8)
    p.add_argument('--max-cost', type=float, default=0.6)
    p.add_argument('--shard-clips', type=int, default=500)
    p.add_argument('--cache', default='/workspace/.hf_parquet')
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    voices = Voices(os.path.join(a.cache, 'ecapa')) if a.embed else None

    # The test packs: their clips by ayah (overlap) and, with --embed, their voices.
    test, temb = {}, []
    for pack in a.test_packs:
        audio = np.load(f'{pack}_audio.npz')
        for i, c in enumerate(json.load(open(f'{pack}_cases.json'))):
            x = audio[f'c{i}'].astype(np.float32)
            test.setdefault(c['ayahId'], []).append((len(x) / 16000, envelope(x), f"{pack}:{c['name']}"))
            if voices:
                temb.append((pack, c['name'], c.get('reciter', ''), voices(x)))
    if voices and not os.path.exists(os.path.join(a.out, 'test_emb.npz')):
        np.savez(os.path.join(a.out, 'test_emb.npz'), pack=np.array([t[0] for t in temb]),
                 name=np.array([t[1] for t in temb]), reciter=np.array([t[2] for t in temb]),
                 emb=np.stack([t[3] for t in temb]).astype(np.float16))

    blocked = {s * 1000 + o for s, o in json.load(open(find('blocked_ayahs.json')))}
    fit = Fit()
    t, fe = fit.t, fit.fe
    student = ds.make_student(ds._base(t.model), 'd6h').to(ds.DEV).eval()
    student.load_state_dict(torch.load(a.student, map_location=ds.DEV))
    ds.STUDENT_CAUSAL = streaming.prior(os.path.join(ds.HERE, 'fbank_prior.json'), ds.DEV)
    streaming.enable(student, *streaming.parse(a.stream))

    files = sorted(f for f in HfApi().list_repo_files(REPO, repo_type='dataset')
                   if f.startswith('data/clean-') and f.endswith('.parquet'))
    if a.files:
        # One fixed random order of all the files: --files N takes its first N, so a pilot's
        # files are the start of a bigger run's (resumed, not redone).
        files = sorted(random.Random(a.seed).sample(files, len(files))[:a.files])
    ix = os.path.join(a.out, 'index.json')
    state = json.load(open(ix)) if os.path.exists(ix) else dict(
        files=[], clips=[], overlaps=[], n_shard=0,
        stats=dict(rows=0, overlap=0, blocked=0, decode=0, unknown=0, poor_fit=0, kept=0))
    stats, index = state['stats'], state['clips']
    shard = []
    letters = sorted(LETTERS)

    def flush():
        if not shard:
            return
        name = f"cand_{state['n_shard']:04d}.npz"
        np.savez(os.path.join(a.out, name),
                 audio=np.concatenate([s[0] for s in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(s[0]) for s in shard]),
                 targets=np.array([s[2] for s in shard] + [None], dtype=object)[:-1],
                 ayahs=np.array([s[1] for s in shard], np.int32),
                 emb=(np.stack([s[3] for s in shard]) if voices else np.zeros((len(shard), 0))).astype(np.float16))
        state['n_shard'] += 1
        shard.clear()

    for f in files:
        if f in state['files']:
            continue
        path = download(REPO, f, a.cache)
        for batch in pq.ParquetFile(path).iter_batches(batch_size=32, columns=['audio', 'is_clean']):
            for row in batch.to_pylist():
                stats['rows'] += 1
                cell = row['audio']
                m = NAME.search(cell.get('path') or '')
                if not row['is_clean'] or not m:
                    stats['unknown'] += 1; continue
                aid, rec = int(m.group(1)) * 1000 + int(m.group(2)), m.group(3)
                try:
                    x, sr = sf.read(io.BytesIO(cell['bytes']), dtype='float32')
                    if x.ndim > 1:
                        x = x.mean(1)
                    if sr != 16000:
                        x = torchaudio.functional.resample(torch.from_numpy(x), sr, 16000).numpy()
                except Exception:
                    stats['decode'] += 1; continue
                secs = len(x) / 16000
                if not 1 <= secs <= 20:
                    stats['decode'] += 1; continue
                hit = next((name for d, env, name in test.get(aid, [])
                            if abs(d - secs) <= 0.3 and same_recording(envelope(x), env) >= 0.8), None)
                if hit:
                    stats['overlap'] += 1; state['overlaps'].append([hit, rec]); continue
                if aid in blocked:
                    stats['blocked'] += 1; continue
                if str(aid) not in fit.ref:
                    stats['unknown'] += 1; continue
                toks = fit.tokens(aid)
                lp_t = teacher_frames(t, fe, x)
                if len(toks) * 2 >= lp_t.shape[0]:
                    stats['poor_fit'] += 1; continue
                sp, cost = spans(lp_t, toks)
                if sp is None or cost is None or cost > a.max_cost:
                    stats['poor_fit'] += 1; continue
                with torch.no_grad():
                    xs, sm = ds.featurize(fe, [(x, [])], ds.STUDENT_CAUSAL)
                    lp_s = F.log_softmax(student(input_features=xs, attention_mask=sm).logits['phonemes'][0].float(), -1)
                pt, ps = lp_t.exp(), lp_s.exp()
                n = min(pt.shape[0], ps.shape[0])
                events = []
                for k, (s0, s1) in enumerate(sp):
                    e = toks[k]
                    if e not in LETTERS or s0 >= n or float(pt[s0:s1 + 1, e].max()) < a.sure:
                        continue
                    seg = ps[max(0, s0 - 1):min(n, s1 + 2)].mean(0)
                    heard = letters[int(seg[letters].argmax())]
                    if heard != e and float(seg[heard]) > float(seg[e]):
                        tseg = pt[s0:s1 + 1].mean(0)
                        t_top = letters[int(tseg[letters].argmax())]
                        events.append([ds.VOCAB[e], ds.VOCAB[heard], round(float(seg[heard] - seg[e]), 3),
                                       round(float(tseg[e]), 3), int(t_top == e)])
                index.append(dict(shard=f"cand_{state['n_shard']:04d}.npz", index=len(shard), ayah=aid,
                                  rec=rec, seconds=round(secs, 2), cost=round(cost, 3), events=events))
                shard.append(((np.clip(x, -1, 1) * 32767).astype(np.int16), aid, list(toks),
                              voices(x) if voices else None))
                stats['kept'] += 1
                if len(shard) == a.shard_clips:
                    flush()
        flush()                       # a file's clips saved before it counts as done
        state['files'].append(f)
        json.dump(state, open(ix + '.tmp', 'w'), ensure_ascii=False)
        os.replace(ix + '.tmp', ix)
        os.remove(path)
        print(f"{len(state['files'])}/{len(files)} files", stats, flush=True)
    print('done', stats, flush=True)


if __name__ == '__main__':
    main()
