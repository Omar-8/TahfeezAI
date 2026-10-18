"""Cut-ghunnah training pairs from correct recitation (route 1): professional clips of
obadx/muaalem-annotated-v3 whose transcript holds a ghunnah (a doubled noon / meem written
«نننن» / «مممم»), each kept as is and copied with that ghunnah cut to about one count —
the original Muaalem force-aligned to the transcript locates its four noons; the copy
keeps the first 30% of their span (a 10 ms crossfade) and drops the rest. Targets: the
transcript, and for the copy its «نننن» written «نن» (a plain doubled noon).

  python ghunnah_cut_data.py <out dir> [--clips 3000]   # shard_93NN.npz, ghunnah_cut.json

No benchmark ayah is used (benchmark_ayahs.json), as for every training source.
"""
import argparse, json, os, random, re

import numpy as np
import torch
import torch.nn.functional as F
import torchaudio

import distill_student as ds

HERE = os.path.dirname(os.path.abspath(__file__))
FRAME = 640          # samples per teacher frame (40 ms)
KEEP = 0.30


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--clips', type=int, default=3000)
    p.add_argument('--seed', type=int, default=0)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    from datasets import Audio, get_dataset_config_names, load_dataset
    from quran_muaalem import Muaalem
    m = Muaalem(model_name_or_path='obadx/muaalem-model-v3_2', device=ds.DEV,
                dtype=torch.bfloat16 if ds.DEV == 'cuda' else torch.float32)
    m.model.eval()
    fe = getattr(m.processor, 'feature_extractor', m.processor)
    bench = {tuple(x) for x in json.load(open(os.path.join(HERE, 'benchmark_ayahs.json')))}
    configs = [c for c in get_dataset_config_names('obadx/muaalem-annotated-v3')
               if c.startswith('moshaf_') and c != 'moshaf_metadata']
    random.Random(a.seed).shuffle(configs)
    per = max(1, a.clips // len(configs))
    shard, n_shard, stats, log = [], 0, {'pairs': 0, 'no_align': 0, 'seen': 0}, []

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        np.savez(os.path.join(a.out, f'shard_{9300 + n_shard:04d}.npz'),
                 audio=np.concatenate([x for x, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _ in shard]),
                 targets=np.array([t for _, t in shard] + [None], dtype=object)[:-1])
        n_shard += 1
        shard = []

    for cfg in configs:
        got = 0
        dset = load_dataset('obadx/muaalem-annotated-v3', name=cfg, split='train', streaming=True)
        dset = dset.cast_column('audio', Audio(sampling_rate=16000))
        for row in dset:
            if got >= per or stats['pairs'] >= a.clips:
                break
            stats['seen'] += 1
            if str(row.get('has_quran')) != 'True':
                continue
            s, e = row.get('start_span') or {}, row.get('end_span') or {}
            try:
                if any((int(s['sura_idx']), x) in bench
                       for x in range(int(s['aya_idx']), int(e['aya_idx']) + 1)):
                    continue
            except Exception:
                continue
            phon = (row.get('phonemes') or '').replace(' ', '')
            if not phon or any(c not in ds.ID for c in phon):
                continue
            hits = [mm.start() for mm in re.finditer('نننن|مممم', phon)]
            if not hits:
                continue
            x = np.asarray(row['audio']['array'], dtype=np.float32)
            if not 1 <= len(x) / 16000 <= 18:
                continue
            ids = [ds.ID[c] for c in phon]
            feats = fe([x], sampling_rate=16000, return_tensors='pt')
            with torch.no_grad():
                lp = F.log_softmax(m.model(**{k: v.to(ds.DEV, dtype=m.model.dtype if v.is_floating_point() else v.dtype)
                                              for k, v in feats.items()}, return_dict=False)[0]['phonemes'].float(), -1)
            try:
                path, _ = torchaudio.functional.forced_align(lp.cpu(), torch.tensor([ids], dtype=torch.int32), blank=0)
            except Exception:
                stats['no_align'] += 1
                continue
            path = path[0].tolist()
            # frame of each target token: CTC paths emit token k on a run of frames
            starts, ends, k, prev = [None] * len(ids), [None] * len(ids), -1, 0
            for f, tok in enumerate(path):
                if tok != 0 and (tok != prev or (k + 1 < len(ids) and path[f - 1] == 0 and ids[k + 1] == tok)):
                    k += 1
                if tok != 0 and 0 <= k < len(ids):
                    starts[k] = f if starts[k] is None else starts[k]
                    ends[k] = f
                prev = tok
            h = random.Random(len(log)).choice(hits)
            if starts[h] is None or ends[h + 3] is None:
                stats['no_align'] += 1
                continue
            a0, a1 = starts[h] * FRAME, (ends[h + 3] + 1) * FRAME
            cut_at = a0 + int((a1 - a0) * KEEP)
            fade = 160
            head, tail = x[:cut_at], x[a1:]
            if len(head) > fade and len(tail) > fade:
                w = np.linspace(1, 0, fade, dtype=np.float32)
                head = head.copy(); head[-fade:] = head[-fade:] * w + tail[:fade] * (1 - w)
                tail = tail[fade:]
            y = np.concatenate([head, tail])
            cut_ids = ids[:h + 2] + ids[h + 4:]       # «نننن» -> «نن»
            shard.append(((np.clip(x, -1, 1) * 32767).astype(np.int16), ids))
            shard.append(((np.clip(y, -1, 1) * 32767).astype(np.int16), cut_ids))
            log.append({'cfg': cfg, 'pos': h, 'letter': phon[h], 'cut_ms': round((a1 - cut_at) / 16), 'span_ms': round((a1 - a0) / 16)})
            stats['pairs'] += 1
            got += 1
            if len(shard) >= 400:
                flush()
        print(cfg, stats, flush=True)
    flush()
    json.dump({'stats': stats, 'pairs': log}, open(os.path.join(a.out, 'ghunnah_cut.json'), 'w'), ensure_ascii=False)
    print('done', stats)


if __name__ == '__main__':
    main()
