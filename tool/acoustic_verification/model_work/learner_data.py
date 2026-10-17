"""Learners' real recitation with mistakes -> distillation shards without transcripts
(the teacher's frames are the target, as for diverse_data.py), so the student hears how
real mistakes sound and follows a teacher that hears them (the teachers catch case-ending
swaps 76-86% of the time; v3.5 10%).

EXPERIMENTAL / NOT YET CLEARED FOR DISTRIBUTION (docs/THIRD_PARTY_RESOURCES.md).

  python learner_data.py <out dir> [--recordings DIR]

Sources:
- IqraEval/Iqra_Extra_IS26 (artifacts/external/Iqra_Extra_IS26.parquet; gated, no licence
  on its card): 1,330 real clips, ~10 speakers, the QuranMB.v2 phrase pool, 74% with a
  mistake -> shard_97NN;
- QuranMB.v2, its even-numbered speakers (IDs 00000_..., 00002_..., ...) ->
  shard_98NN; the odd-numbered speakers become the test pack quranmbh (see
  quranmbh_split below), so no QuranMB speaker is both trained on and tested;
- the user's own recordings ([--recordings], WAVs; the user agreed to training on them,
  2026-10-17), cut at the quietest point into pieces of at most 18 s -> shard_99NN.
"""
import argparse, glob, io, json, os, wave

import numpy as np
import pyarrow.parquet as pq
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
EXT = os.path.join(ART, 'external')
MAX_S, MIN_S = 18.0, 1.0


def decode(b):
    w, sr = sf.read(io.BytesIO(b), dtype='float32')
    if w.ndim > 1:
        w = w.mean(1)
    assert sr == 16000, sr
    return w


def pieces(w, max_s=MAX_S):
    """[w] cut into pieces of at most [max_s] seconds, each cut at the quietest 100 ms
    window of the last 4 s before the limit."""
    out, start, n, lim = [], 0, len(w), int(max_s * 16000)
    while n - start > lim:
        lo, hi = start + lim - 4 * 16000, start + lim
        energy = [float(np.mean(w[i:i + 1600] ** 2)) for i in range(lo, hi - 1600, 400)]
        cut = lo + 400 * int(np.argmin(energy)) + 800
        out.append(w[start:cut]); start = cut
    out.append(w[start:])
    return [p for p in out if len(p) >= MIN_S * 16000]


def write(out_dir, first, clips, per=400):
    for k in range(0, len(clips), per):
        part = clips[k:k + per]
        np.savez(os.path.join(out_dir, f'shard_{first + k // per:04d}.npz'),
                 audio=np.concatenate([np.clip(x, -1, 1) * 32767 for x in part]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x in part]),
                 targets=np.array([[] for _ in part] + [None], dtype=object)[:-1])
    return (len(clips) + per - 1) // per


def quranmb_speaker(clip_id):
    return int(clip_id.split('_')[0])


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--recordings')
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stats = {}
    extra = pq.read_table(os.path.join(EXT, 'Iqra_Extra_IS26.parquet'), columns=['audio']).to_pylist()
    clips = [decode(r['audio']['bytes']) for r in extra]
    stats['iqra_extra'] = (write(a.out, 9700, clips), len(clips), round(sum(map(len, clips)) / 16000 / 3600, 2))
    mb = pq.read_table(os.path.join(EXT, 'IqraEval_QuranMB.v2__data_test-00000-of-00001.parquet')).to_pylist()
    clips = [decode(r['audio']['bytes']) for r in mb if quranmb_speaker(r['ID']) % 2 == 0]
    stats['quranmb_even'] = (write(a.out, 9800, clips), len(clips), round(sum(map(len, clips)) / 16000 / 3600, 2))
    if a.recordings:
        clips = []
        for f in sorted(glob.glob(os.path.join(a.recordings, '*.wav'))):
            with wave.open(f) as w:
                x = np.frombuffer(w.readframes(w.getnframes()), '<i2').astype(np.float32) / 32767
            clips += pieces(x)
        stats['recordings'] = (write(a.out, 9900, clips), len(clips), round(sum(map(len, clips)) / 16000 / 3600, 2))
    print({k: dict(shards=s, clips=c, hours=h) for k, (s, c, h) in stats.items()})


def quranmbh_split():
    """The test pack quranmbh: quranmb's cases (and frames, per model tag) of the
    odd-numbered speakers only — the speakers no student of this round trained on.
      python -c 'import learner_data; learner_data.quranmbh_split()'
    Writes artifacts/quranmbh_cases.json + quranmbh_audio.npz, and results/
    quranmbh_<tag>.{json,f32} for every results/quranmb_<tag> already computed."""
    cases = json.load(open(os.path.join(ART, 'quranmb_cases.json')))
    audio = np.load(os.path.join(ART, 'quranmb_audio.npz'))
    keep = [i for i, c in enumerate(cases) if int(c['name'].split('_')[1]) % 2 == 1]
    json.dump([cases[i] for i in keep], open(os.path.join(ART, 'quranmbh_cases.json'), 'w'), ensure_ascii=False)
    np.savez(os.path.join(ART, 'quranmbh_audio.npz'), **{f'c{j}': audio[f'c{i}'] for j, i in enumerate(keep)})
    names = {cases[i]['name'] for i in keep}
    R = os.path.join(ART, 'results')
    for f in glob.glob(os.path.join(R, 'quranmb_*.json')):
        tag = os.path.basename(f)[len('quranmb_'):-len('.json')]
        if tag.endswith('.perf'):
            continue
        idx = json.load(open(f))
        lp = np.fromfile(f[:-5] + '.f32', dtype=np.float32)
        out_idx, parts, off = [], [], 0
        for c in (idx if isinstance(idx, list) else idx['cases']):
            if c['name'] not in names:
                continue
            c = json.loads(json.dumps(c))
            for k, v in c.items():
                if isinstance(v, dict) and 'offset' in v and 'frames' in v:
                    n = v['frames'] * 43
                    parts.append(lp[v['offset']:v['offset'] + n]); v['offset'] = off; off += n
            out_idx.append(c)
        json.dump(out_idx if isinstance(idx, list) else {**idx, 'cases': out_idx},
                  open(os.path.join(R, f'quranmbh_{tag}.json'), 'w'), ensure_ascii=False)
        np.concatenate(parts).astype(np.float32).tofile(os.path.join(R, f'quranmbh_{tag}.f32'))
    print(len(keep), 'held-out cases')


if __name__ == '__main__':
    main()
