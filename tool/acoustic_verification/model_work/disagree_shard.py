"""The clips disagree_mine.py found the student confidently wrong on, as training shards
(shard_91NN.npz: audio, offsets, targets) — to be oversampled (--repeat shard_91=N) so the
student learns the teachers' verdict exactly where it misses it.

  python disagree_shard.py <out dir> <mine.json>... [--min-events 1] [--max-clips 4000]
         [--holdout holdout.json]

A clip from a training shard keeps its transcript; a test pack's clip (pack:<name>, a
whole recorded session repeated once per ayah case) is taken once, without one (the
teachers' distribution is its whole target), and only when its session is not listed
in --holdout (a JSON list of session names: kept back to judge the result on).
"""
import argparse, json, os

import numpy as np

import distill_student as ds

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('mined', nargs='+')
    p.add_argument('--min-events', type=int, default=1)
    p.add_argument('--max-clips', type=int, default=4000)
    p.add_argument('--holdout')
    p.add_argument('--first', type=int, default=9100, help='first shard number')
    p.add_argument('--data-dirs', default='data_retasy,data_learn,data_real,data_juz30,data_orig')
    a = p.parse_args()
    held = set(json.load(open(a.holdout))) if a.holdout else set()
    rows = [r for m in a.mined for r in json.load(open(m))['clips']
            if len(r['events']) >= a.min_events]
    rows.sort(key=lambda r: -r['per_min'])
    os.makedirs(a.out, exist_ok=True)
    shard, n_shard, taken, seen = [], 0, [], set()
    cache = {}

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        np.savez(os.path.join(a.out, f'shard_{a.first + n_shard:04d}.npz'),
                 audio=np.concatenate([x for x, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _ in shard]),
                 targets=np.array([t for _, t in shard] + [None], dtype=object)[:-1])
        n_shard += 1
        shard = []

    for r in rows:
        if len(taken) >= a.max_clips:
            break
        src = r['source']
        if src.startswith('pack:'):
            session = r['name'].split('_')[0]
            key = (session, r['seconds'])
            if session in held or key in seen:
                continue
            seen.add(key)
            pack = src[5:]
            if pack not in cache:
                cache[pack] = np.load(os.path.join(ART, f'{pack}_audio.npz'))
            x, t = cache[pack][f"c{r['index']}"].astype(np.float32), []
        else:
            if src not in cache:
                path = next((os.path.join(d, src) for d in a.data_dirs.split(',')
                             if os.path.exists(os.path.join(d, src))), None)
                if path is None:
                    continue
                cache[src] = ds.clips(path)
            x, t = cache[src][r['index']]
        shard.append(((np.clip(x, -1, 1) * 32767).astype(np.int16), t))
        taken.append({'source': src, 'index': r['index'], 'name': r['name'],
                      'events': len(r['events']), 'per_min': r['per_min']})
        if len(shard) >= 400:
            flush()
    flush()
    json.dump(taken, open(os.path.join(a.out, 'mined_clips.json'), 'w'), ensure_ascii=False)
    print(f'{len(taken)} clips in {n_shard} shards '
          f'({sum(t["events"] for t in taken)} events)')


if __name__ == '__main__':
    main()
