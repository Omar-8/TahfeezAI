"""G19's real phone shards from phone_mine.py's candidates: hard clips (an event where v3.6
prefers another letter by >= --margin over the expected one the teacher is sure of, or any
tracked confusion) -> shard_61NN; every other kept clip (random real phone) -> shard_60NN.

  python phone_select.py data_phone_cand data_phone [--margin 0.2] [--clips 500]
"""
import argparse, json, os
import numpy as np

TRACKED = {('ذ', 'ل'), ('خ', 'ف'), ('ث', 'ت'), ('ص', 'س'), ('ض', 'د'), ('ط', 'ت'), ('ظ', 'ذ'),
           ('ق', 'ك'), ('ح', 'ه')}


FOCUS = {('ح', 'ه'), ('ض', 'د'), ('ك', 'ق'), ('ء', 'ي'), ('ن', 'ي')}


def balanced(a, clips):
    """G20's hard shards (shard_62NN): clips whose alignment is confident (cost <= --hard-cost)
    with an event where the teacher is not confused itself (the expected letter is its own top
    letter over the span, mean probability >= --teacher-mean) and the student prefers another
    letter by >= --margin; ں (the teacher's own weak spot) never counted. Drawn per confusion
    pair: --per-pair draws each (x3 for FOCUS), a clip at most 4 times per pair."""
    rng = np.random.default_rng(20)
    by_pair = {}
    for i, c in enumerate(clips):
        if c['cost'] > a.hard_cost:
            continue
        for e in c['events']:
            if len(e) < 5 or 'ں' in e[:2] or not e[4] or e[3] < a.teacher_mean or e[2] < a.margin:
                continue
            by_pair.setdefault((e[0], e[1]), set()).add(i)
    picks, report = [], []
    for pair, ids in sorted(by_pair.items(), key=lambda kv: -len(kv[1])):
        ids = sorted(ids)
        want = min(a.per_pair * (3 if pair in FOCUS else 1), 4 * len(ids))
        draw = list(rng.permutation(ids)) * 4
        picks += draw[:want]
        report.append(f'{pair[0]}→{pair[1]} {len(ids)} clips -> {want}')
    print(f'{len(by_pair)} pairs; draws {len(picks)}; ' + ', '.join(report[:30]))
    for f in FOCUS:
        print('focus', f'{f[0]}→{f[1]}', len(by_pair.get(f, ())), 'clips')
    return [clips[i] for i in picks]


def main():
    p = argparse.ArgumentParser()
    p.add_argument('cand')
    p.add_argument('out')
    p.add_argument('--margin', type=float, default=0.2)
    p.add_argument('--clips', type=int, default=500)
    p.add_argument('--balanced', action='store_true', help='G20: balanced hard shards only (62NN)')
    p.add_argument('--hard-cost', type=float, default=0.4)
    p.add_argument('--teacher-mean', type=float, default=0.6)
    p.add_argument('--per-pair', type=int, default=40)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    clips = json.load(open(os.path.join(a.cand, 'index.json')))['clips']
    if a.balanced:
        groups = {62: balanced(a, clips)}
    else:
        hard = lambda c: any(e[2] >= a.margin or (e[0], e[1]) in TRACKED for e in c['events'])
        groups = {61: [c for c in clips if hard(c)], 60: [c for c in clips if not hard(c)]}
    cache = {}
    for base, cs in groups.items():
        cs = sorted(cs, key=lambda c: (c['shard'], c['index']))   # one candidate shard at a time
        for k in range(0, len(cs), a.clips):
            part = cs[k:k + a.clips]
            xs = []
            for c in part:
                if c['shard'] not in cache:
                    # (each z['audio'] would read the whole file again: once per shard)
                    z = np.load(os.path.join(a.cand, c['shard']), allow_pickle=True)
                    cache.clear()
                    cache[c['shard']] = (z['audio'], z['offsets'])
                au, off = cache[c['shard']]
                xs.append(au[off[c['index']]:off[c['index'] + 1]].copy())
            np.savez(os.path.join(a.out, f'shard_{base}{k // a.clips:02d}.npz'),
                     audio=np.concatenate(xs), offsets=np.cumsum([0] + [len(x) for x in xs]),
                     targets=np.array([[] for _ in xs] + [None], dtype=object)[:-1],
                     ayahs=np.array([c['ayah'] for c in part], np.int32))
        print(f'shard_{base}xx: {len(cs)} clips ({len({(c["shard"], c["index"]) for c in cs})} distinct), '
              f'{sum(c["seconds"] for c in cs) / 3600:.1f} h')


if __name__ == '__main__':
    main()
