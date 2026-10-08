"""Learners' real, expert-labelled mistakes -> teacher fine-tune shards (one half of the
speakers) and test packs (the other half).

  python real_mistakes_data.py [--seed 0]

Sources (laptop test packs, already decoded): artifacts/ikhlas_* (Surah Al-Ikhlas
learners, CC BY 4.0: ikhlas_pack.py) and artifacts/qdat_* + qdat_labels.json (QDAT, MIT:
qdat_pack.py). Each clip's CTC target is what the reciter said, as far as the labels tell:
the expected Hafs pronunciation (distill_student.spoken) with the labelled mistakes
written in —
- Al-Ikhlas, "qalqala" mistakes: the qalqala echo (ڇ) left out on the named words; clips
  judged correct as expected; clips with vowel or other mistakes are not used (their
  explanations do not say what was said);
- QDAT (5:109, words 8-15), per rule the experts heard missed: the separate madd of
  «لَنَآ إِنَّكَ» held 2 counts, not 4; the noon of «إِنَّكَ» doubled without ghunnah;
  the noon of «أَنتَ» said plainly (no ikhfa).

Speakers are split in two (seeded): data_real/shard_96NN.npz holds one half's clips
(finetune_teacher.py --real, and the distillation mix); artifacts/ikhlash_* and
qdath_* the other half's, in the bench format (bench_run.py --pack ikhlash / qdath),
with artifacts/real_split.json naming the test speakers.
"""
import argparse, json, os, random

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
from distill_student import sounds_of, spoken  # noqa: E402

_REF = os.path.join(ROOT, 'assets/quran/recitation/phonetic_reference_hafs.json')
REF = json.load(open(_REF if os.path.exists(_REF)
                     else os.path.join(HERE, 'phonetic_reference_hafs.json')))['ayahs']


def sounds(aid, first, last):
    return [s for s in sounds_of(REF[str(aid)]) if first <= s[2] <= last]


def ikhlas_target(case):
    """The clip's transcript, or None when its mistakes are not known well enough."""
    s = sounds(case['ayahId'], case['firstWord'], case['lastWord'])
    if case['category'] == 'ikhlas_correct':
        return spoken(s)
    if case['category'] == 'ikhlas_qalqala':
        words = set(case['targetWords'])
        return spoken([x for x in s if not (x[0] == 'ڇ' and x[2] in words)])
    return None


def qdat_target(labels):
    """5:109 words 7-14 as said, from the three rules' labels (1: applied)."""
    if labels is None or any(v is None for v in labels.values()):
        return None
    ok = {k: int(float(v)) == 1 for k, v in labels.items()}
    out = []
    for c, n, w in sounds(5109, 7, 14):
        if w == 10 and c == 'ا' and n == 4 and not ok['separate_tide']:
            n = 2  # «لَنَآ» before «إِنَّكَ»: the separate madd cut to 2
        if w == 11 and c == 'ن' and n == 4 and not ok['the_tight_noon']:
            n = 2  # «إِنَّكَ»: doubled, no ghunnah
        if w == 12 and c == 'ں' and not ok['concealment']:
            c, n = 'ن', 1  # «أَنتَ»: a plain noon, no ikhfa
        out.append((c, n, w))
    return spoken(out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--seed', type=int, default=0)
    a = p.parse_args()
    out_dir = os.path.join(HERE, 'data_real')
    os.makedirs(out_dir, exist_ok=True)
    labels = json.load(open(os.path.join(ART, 'qdat_labels.json')))
    split, train, stats = {}, [], {}
    for pack, target in (('ikhlas', lambda c: ikhlas_target(c)),
                         ('qdat', lambda c: qdat_target(labels.get(c['name'])))):
        cases = json.load(open(os.path.join(ART, f'{pack}_cases.json')))
        audio = np.load(os.path.join(ART, f'{pack}_audio.npz'))
        speakers = sorted({c['reciter'] for c in cases})
        random.Random(a.seed).shuffle(speakers)
        test = set(speakers[:len(speakers) // 2])
        split[pack] = sorted(test)
        held, blobs = [], {}
        for i, c in enumerate(cases):
            if c['reciter'] in test:
                blobs[f'c{len(held)}'] = audio[f'c{i}']
                held.append(c)
                continue
            t = target(c)
            if t is None:
                continue
            train.append((audio[f'c{i}'], t, c['ayahId'], pack, c['category']))
        json.dump(held, open(os.path.join(ART, f'{pack}h_cases.json'), 'w'), ensure_ascii=False)
        np.savez(os.path.join(ART, f'{pack}h_audio.npz'), **blobs)
        stats[pack] = dict(speakers=len(speakers), test_speakers=len(test), test_clips=len(held))
    json.dump(split, open(os.path.join(ART, 'real_split.json'), 'w'))
    random.Random(a.seed).shuffle(train)
    per = 400
    for k in range(0, len(train), per):
        part = train[k:k + per]
        np.savez(os.path.join(out_dir, f'shard_{9600 + k // per:04d}.npz'),
                 audio=np.concatenate([np.clip(x, -1, 1) * 32767 for x, *_ in part]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, *_ in part]),
                 targets=np.array([t for _, t, *_ in part] + [None], dtype=object)[:-1],
                 ayahs=np.array([aid for _, _, aid, *_ in part], np.int32))
    from collections import Counter
    print(stats)
    print(len(train), 'training clips:', dict(Counter(f'{p}/{c}' for *_, p, c in train)))


if __name__ == '__main__':
    main()
