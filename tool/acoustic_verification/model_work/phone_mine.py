"""Real phone recordings for G19 (2026-10-21): greentechapps/user_recited_verses_full (CC BY 4.0;
8,950 Tarteel users' recordings of single ayahs, 23 h, 16 kHz, filtered by its authors to
clips two ASR models transcribe within 0.3 CER) -> candidate shards + an index of where v3.6
hears a letter the teacher does not.

  TEACHER_WEIGHTS=teachers/teacher_ft5.pt python phone_mine.py <out dir> \
      --student init/G2e/student.pt --test tlog_audio.npz tlog_cases.json
  (an event: [expected, heard, student margin, teacher's mean p(expected) over the span,
  1 if the expected letter is the teacher's own top letter there])

Per recording:
- overlap: never kept if it is one of the held-out Tarteel test clips (`tlog`): same ayah,
  length within 0.3 s and waveforms correlating >= 0.8 at their best lag (4 kHz envelope);
- the spliced-mistake benchmark's ayahs (blocked_ayahs.json) are skipped, as for every source;
- alignment: the teacher forced-aligned to the ayah's expected Hafs sounds; its mean cost per
  frame (as hf_ayah_data.Fit) must be <= --max-cost, else the clip is dropped (another ayah,
  noise, a broken file);
- hard letters: each expected letter the teacher is sure of (its probability >= --sure at
  some frame of the letter's span) where v3.6 — the streaming student run as in training
  validation (torch, stateful chunks) — prefers another letter over the span (+-1 frame:
  streaming may lag): its mean probability of that letter above the expected one's. Each
  such letter is an event (expected -> heard).
Writes <out>/cand_NNNN.npz (audio, offsets, empty targets, ayahs) and <out>/index.json (per
clip: shard, index, ayah, seconds, cost, events).
"""
import argparse, glob, io, json, os, re
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

REPO = 'greentechapps/user_recited_verses_full'
LETTERS = {ds.ID[c] for c in 'ءبتثجحخدذرزسشصضطظعغفقكلمنهوي'}


def envelope(x):
    """4 kHz, zero-mean, unit-norm: for comparing two recordings."""
    y = x[: len(x) // 4 * 4].reshape(-1, 4).mean(1)
    y = y - y.mean()
    return y / (np.linalg.norm(y) + 1e-9)


def same_recording(a, b, max_lag=1000):
    """Best normalised correlation of two envelopes over lags up to [max_lag] (0.25 s)."""
    n = 1 << (len(a) + len(b) - 1).bit_length()
    c = np.fft.irfft(np.fft.rfft(a, n) * np.conj(np.fft.rfft(b, n)), n)
    c = np.concatenate([c[-max_lag:], c[:max_lag + 1]])
    return float(c.max())


def spans(lp, toks):
    """Forced alignment: per expected token (start, end) frames, and the mean cost."""
    labels, scores = torchaudio.functional.forced_align(
        lp[None], torch.tensor([toks], device=lp.device), blank=0)
    path = labels[0]
    on = path != 0
    if not on.any():
        return None, None
    cost = float((lp.max(-1).values - lp.gather(1, path[:, None])[:, 0])[on].mean())
    ts = torchaudio.functional.merge_tokens(labels[0], scores[0].exp())
    if len(ts) != len(toks):
        return None, cost
    return [(t.start, t.end - 1) for t in ts], cost


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--student', required=True)
    p.add_argument('--stream', default='0.96,5.12')
    p.add_argument('--test', nargs=2, metavar=('AUDIO_NPZ', 'CASES_JSON'), required=True)
    p.add_argument('--sure', type=float, default=0.8)
    p.add_argument('--max-cost', type=float, default=0.6)
    p.add_argument('--shard-clips', type=int, default=1000)
    p.add_argument('--cache', default='/workspace/.hf_parquet')
    p.add_argument('--holdout', type=int, default=0,
                   help='every Nth clip that passes the filters goes to a test pack '
                        '(<out>/phonedev_audio.npz + _cases.json), never to the candidates')
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)

    test_audio = np.load(a.test[0])
    test = {}
    for i, c in enumerate(json.load(open(a.test[1]))):
        x = test_audio[f'c{i}'].astype(np.float32)
        test.setdefault(c['ayahId'], []).append((len(x) / 16000, envelope(x), c['name']))

    # As every source: no ayah of the spliced-mistake benchmark (blocked_ayahs.json).
    blocked = {s * 1000 + o for s, o in json.load(open(find('blocked_ayahs.json')))}
    fit = Fit()
    t, fe = fit.t, fit.fe
    student = ds.make_student(ds._base(t.model), 'd6h').to(ds.DEV).eval()
    student.load_state_dict(torch.load(a.student, map_location=ds.DEV))
    ds.STUDENT_CAUSAL = streaming.prior(os.path.join(ds.HERE, 'fbank_prior.json'), ds.DEV)
    streaming.enable(student, *streaming.parse(a.stream))

    files = sorted(f for f in HfApi().list_repo_files(REPO, repo_type='dataset') if f.endswith('.parquet'))
    index, shard, n_shard = [], [], 0
    stats = dict(rows=0, overlap=0, blocked=0, decode=0, unknown=0, poor_fit=0, kept=0, held_out=0)
    dev_audio, dev_cases, passed = {}, [], 0
    overlaps = []

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        name = f'cand_{n_shard:04d}.npz'
        np.savez(os.path.join(a.out, name),
                 audio=np.concatenate([x for x, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _ in shard]),
                 targets=np.array([[] for _ in shard] + [None], dtype=object)[:-1],
                 ayahs=np.array([aid for _, aid in shard], np.int32))
        n_shard += 1; shard = []

    for f in files:
        path = download(REPO, f, a.cache)
        for batch in pq.ParquetFile(path).iter_batches(batch_size=32, columns=['audio', 'sura', 'ayah']):
            for row in batch.to_pylist():
                stats['rows'] += 1
                aid = int(row['sura']) * 1000 + int(row['ayah'])
                cell = row['audio']
                try:
                    x, sr = sf.read(io.BytesIO(cell['bytes'] if isinstance(cell, dict) else cell), dtype='float32')
                    if x.ndim > 1:
                        x = x.mean(1)
                    if sr != 16000:
                        x = torchaudio.functional.resample(torch.from_numpy(x), sr, 16000).numpy()
                except Exception:
                    stats['decode'] += 1; continue
                secs = len(x) / 16000
                hit = None
                for d, env, name in test.get(aid, []):
                    if abs(d - secs) <= 0.3 and same_recording(envelope(x), env) >= 0.8:
                        hit = name; break
                if hit:
                    stats['overlap'] += 1; overlaps.append(hit); continue
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
                passed += 1
                if a.holdout and passed % a.holdout == 0:
                    # A held-out phone test clip: the whole ayah, as the tlog pack's.
                    n_words = ord(fit.ref[str(aid)]['w'][-1]) - 47
                    dev_audio[f'c{len(dev_cases)}'] = x.astype(np.float32)
                    dev_cases.append(dict(set='clean', kind='clean', category='phone_dev',
                                          name=f'gt_{aid}_{stats["rows"]}', ayahId=aid, lastAyah=aid,
                                          ayahs=[aid], firstWord=0, lastWord=n_words - 1,
                                          targetWords=[], openStart=True, openEnd=True, screen=True))
                    stats['held_out'] += 1
                    continue
                with torch.no_grad():
                    xs, sm = ds.featurize(fe, [(x, [])], ds.STUDENT_CAUSAL)
                    lp_s = F.log_softmax(student(input_features=xs, attention_mask=sm).logits['phonemes'][0].float(), -1)
                pt, ps = lp_t.exp(), lp_s.exp()
                n = min(pt.shape[0], ps.shape[0])
                letters = sorted(LETTERS)
                events = []
                for k, (s0, s1) in enumerate(sp):
                    e = toks[k]
                    if e not in LETTERS or s0 >= n:
                        continue
                    if float(pt[s0:s1 + 1, e].max()) < a.sure:
                        continue
                    seg = ps[max(0, s0 - 1):min(n, s1 + 2)].mean(0)
                    sub = seg[letters]
                    heard = letters[int(sub.argmax())]
                    if heard != e and float(seg[heard]) > float(seg[e]):
                        # The teacher over the same span: its mean probability of the expected
                        # letter, and whether that letter is its own top letter there (G20:
                        # never a case where the teacher is confused too).
                        tseg = pt[s0:s1 + 1].mean(0)
                        t_top = letters[int(tseg[letters].argmax())]
                        events.append([ds.VOCAB[e], ds.VOCAB[heard], round(float(seg[heard] - seg[e]), 3),
                                       round(float(tseg[e]), 3), int(t_top == e)])
                index.append(dict(shard=f'cand_{n_shard:04d}.npz', index=len(shard), ayah=aid,
                                  seconds=round(secs, 2), cost=round(cost, 3), events=events))
                shard.append(((np.clip(x, -1, 1) * 32767).astype(np.int16), aid))
                stats['kept'] += 1
                if len(shard) == a.shard_clips:
                    flush()
                    json.dump(dict(stats=stats, overlaps=overlaps, clips=index),
                              open(os.path.join(a.out, 'index.json'), 'w'), ensure_ascii=False)
                if stats['rows'] % 200 == 0:
                    print(stats, flush=True)
        os.remove(path)
    flush()
    json.dump(dict(stats=stats, overlaps=overlaps, clips=index),
              open(os.path.join(a.out, 'index.json'), 'w'), ensure_ascii=False)
    if dev_cases:
        np.savez(os.path.join(a.out, 'phonedev_audio.npz'), **dev_audio)
        json.dump(dev_cases, open(os.path.join(a.out, 'phonedev_cases.json'), 'w'), ensure_ascii=False)
    print('done', stats, flush=True)


if __name__ == '__main__':
    main()
