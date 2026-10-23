"""G25's TLOG shards from tlog_mine.py's candidates (with --embed): test speakers out, a held-out
validation split by speaker, a random pool and a pair-balanced hard pool.

  python tlog_select.py <cand dir> <out dir> [--dev-share 0.03] [--per-pair 60]

- Same voice: ECAPA cosine similarity. The threshold is calibrated on the Juz 30 test pack's
  reciters (their speaker labels known): midway between the 99.9th percentile of two
  different reciters' clips and the median of one reciter's (printed; --thr overrides).
- Test speakers out: a candidate whose voice matches any test clip (a Tarteel-200 clip, a
  Juz 30 reciter's centroid) is never trained on — TLOG has no user ids, and Tarteel-200's
  speakers may have recorded other ayahs too.
- Validation by speaker: candidates grouped by voice (greedy, against group centroids, on the
  GPU when there is one); --dev-share of the groups — every clip of theirs — become the pack
  tlogdev (<out>/tlogdev_audio.npz + _cases.json), never trained on.
- Hard pool (shard_71NN): clips with an event where the teacher is not confused itself (the
  expected letter its own top letter, mean p >= 0.6), the student prefers another letter by
  >= 0.15, alignment cost <= 0.4; drawn --per-pair per confusion pair (x3 for FOCUS), a clip
  at most 4 times; ں never counted. Random pool (shard_70NN): every other training clip.
Shards keep their expected Hafs tokens (weak CTC: distill_student.py --ctc-scale).
"""
import argparse, collections, json, os
import numpy as np
import torch

FOCUS = {('ح', 'ه'), ('ض', 'د'), ('ق', 'ك'), ('ك', 'ق'), ('ء', 'ي'), ('ن', 'ي'), ('خ', 'ف'), ('ث', 'ت')}
DEV = 'cuda' if torch.cuda.is_available() else 'cpu'


def load(cand):
    state = json.load(open(os.path.join(cand, 'index.json')))
    clips = state['clips']
    emb = {}
    for sh in sorted({c['shard'] for c in clips}):
        emb[sh] = np.load(os.path.join(cand, sh), allow_pickle=True)['emb'].astype(np.float32)
    E = np.stack([emb[c['shard']][c['index']] for c in clips])
    return state, clips, E


def threshold(test):
    """Same-voice cosine from the Juz 30 reciters' clips (labelled)."""
    m = test['pack'] == 'juz30h'
    e, r = test['emb'][m].astype(np.float32), test['reciter'][m]
    s = e @ e.T
    same = r[:, None] == r[None, :]
    iu = np.triu_indices(len(e), 1)
    sv, dv = s[iu][same[iu]], s[iu][~same[iu]]
    thr = (np.percentile(dv, 99.9) + np.median(sv)) / 2
    print(f'voices: same reciter median {np.median(sv):.2f} (5th pct {np.percentile(sv, 5):.2f}); '
          f'different 99.9th pct {np.percentile(dv, 99.9):.2f} -> threshold {thr:.2f}')
    return float(thr)


def groups(E, thr):
    """Greedy speaker groups: each clip joins the closest group centroid >= thr, else founds one."""
    X = torch.from_numpy(E).to(DEV)
    cent = torch.zeros((len(E), E.shape[1]), device=DEV)     # at most one group per clip
    count = []
    label = np.empty(len(E), np.int64)
    for i in range(len(E)):
        n = len(count)
        if n:
            sims = cent[:n] @ X[i]
            j = int(sims.argmax())
            if float(sims[j]) >= thr:
                label[i] = j
                count[j] += 1
                c = cent[j] * (count[j] - 1) + X[i]
                cent[j] = c / c.norm()
                continue
        label[i] = n
        count.append(1)
        cent[n] = X[i]
    return label


def balanced(a, clips, ids):
    rng = np.random.default_rng(25)
    by_pair = collections.defaultdict(set)
    for i in ids:
        c = clips[i]
        if c['cost'] > 0.4:
            continue
        for e in c['events']:
            if 'ں' in e[:2] or not e[4] or e[3] < 0.6 or e[2] < 0.15:
                continue
            by_pair[(e[0], e[1])].add(i)
    picks = []
    for pair, s in sorted(by_pair.items(), key=lambda kv: -len(kv[1])):
        s = sorted(s)
        want = min(a.per_pair * (3 if pair in FOCUS else 1), 4 * len(s))
        picks += (list(rng.permutation(s)) * 4)[:want]
    print(f'hard: {len(by_pair)} pairs, {len({*picks})} clips, {len(picks)} draws; focus: ' +
          ', '.join(f'{p[0]}→{p[1]} {len(by_pair.get(p, ()))}' for p in sorted(FOCUS)))
    return picks


def write(cand, out, base, clips, ids, size=500):
    cache = {}
    ids = sorted(ids, key=lambda i: (clips[i]['shard'], clips[i]['index']))
    for k in range(0, len(ids), size):
        xs, ts, ay = [], [], []
        for i in ids[k:k + size]:
            c = clips[i]
            if c['shard'] not in cache:
                z = np.load(os.path.join(cand, c['shard']), allow_pickle=True)
                cache.clear()
                cache[c['shard']] = (z['audio'], z['offsets'], z['targets'])
            au, off, tg = cache[c['shard']]
            xs.append(au[off[c['index']]:off[c['index'] + 1]].copy())
            ts.append(list(tg[c['index']])); ay.append(c['ayah'])
        np.savez(os.path.join(out, f'shard_{base}{k // size:02d}.npz'), audio=np.concatenate(xs),
                 offsets=np.cumsum([0] + [len(x) for x in xs]),
                 targets=np.array(ts + [None], dtype=object)[:-1], ayahs=np.array(ay, np.int32))
    print(f'shard_{base}xx: {len(ids)} clips, {sum(clips[i]["seconds"] for i in ids) / 3600:.1f} h')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('cand')
    p.add_argument('out')
    p.add_argument('--dev-share', type=float, default=0.03)
    p.add_argument('--per-pair', type=int, default=60)
    p.add_argument('--thr', type=float, default=0)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    state, clips, E = load(a.cand)
    test = dict(np.load(os.path.join(a.cand, 'test_emb.npz')))
    thr = a.thr or threshold(test)
    # Test speakers: each Tarteel-200 clip, each Juz 30 reciter's centroid.
    refs = [test['emb'][i].astype(np.float32) for i in np.where(test['pack'] != 'juz30h')[0]]
    for r in sorted(set(test['reciter'][test['pack'] == 'juz30h'])):
        c = test['emb'][(test['pack'] == 'juz30h') & (test['reciter'] == r)].astype(np.float32).mean(0)
        refs.append(c / np.linalg.norm(c))
    near = (E @ np.stack(refs).T).max(1)
    out_test = near >= thr
    print(f'{len(clips)} candidates; {int(out_test.sum())} sound like a test speaker -> excluded')
    keep = np.where(~out_test)[0]
    label = groups(E[keep], thr)
    group_of = {int(i): int(label[j]) for j, i in enumerate(keep)}
    n_groups = int(label.max()) + 1
    rng = np.random.default_rng(25)
    dev_groups = set(rng.choice(n_groups, max(1, int(round(n_groups * a.dev_share))), replace=False).tolist())
    dev = [int(keep[j]) for j in range(len(keep)) if label[j] in dev_groups]
    train = [int(keep[j]) for j in range(len(keep)) if label[j] not in dev_groups]
    print(f'speaker groups {n_groups}; held out {len(dev_groups)} groups = {len(dev)} clips (tlogdev)')
    # tlogdev: a test pack, as the tlog pack's cases.
    ref = json.load(open('phonetic_reference_hafs.json'))['ayahs']
    audio, cases, cache = {}, [], {}
    for i in dev:
        c = clips[i]
        if c['shard'] not in cache:
            z = np.load(os.path.join(a.cand, c['shard']), allow_pickle=True)
            cache.clear(); cache[c['shard']] = (z['audio'], z['offsets'])
        au, off = cache[c['shard']]
        audio[f'c{len(cases)}'] = au[off[c['index']]:off[c['index'] + 1]].astype(np.float32) / 32767
        n_words = ord(ref[str(c['ayah'])]['w'][-1]) - 47
        cases.append(dict(set='clean', kind='clean', category='tlog_dev', name=f"tlog_{c['ayah']}_{c['rec']}",
                          ayahId=c['ayah'], lastAyah=c['ayah'], ayahs=[c['ayah']], firstWord=0,
                          lastWord=n_words - 1, targetWords=[], openStart=True, openEnd=True, screen=True,
                          reciter=f"g{group_of[i]}"))
    np.savez(os.path.join(a.out, 'tlogdev_audio.npz'), **audio)
    json.dump(cases, open(os.path.join(a.out, 'tlogdev_cases.json'), 'w'), ensure_ascii=False)
    hard = balanced(a, clips, train)
    hard_set = set(hard)
    write(a.cand, a.out, 70, clips, [i for i in train if i not in hard_set])
    write(a.cand, a.out, 71, clips, hard)
    json.dump(dict(threshold=thr, excluded_test_voice=int(out_test.sum()), groups=n_groups,
                   dev_groups=len(dev_groups), dev_clips=len(dev), train_clips=len(train),
                   hard_draws=len(hard)), open(os.path.join(a.out, 'select.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
