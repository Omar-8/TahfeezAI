"""Minimal word pairs for the calibration set (see build_calibration.py).

A pair (expected word E, recited word R): R's phonemes are E's with one edit of a
mistake category. Both words come from the calibration ayahs only — ayahs the
student never trained on (benchmark_ayahs.json) and the final test does not use
(artifacts/bench_cases.json) — so no recording segment is shared across roles.
Edits avoid each word's first and last sound (the ones neighbours change).
"""
import collections, json, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
VOWELS = {'َ': 'FATHA', 'ُ': 'DAMMA', 'ِ': 'KASRA'}
CONS = set('ءبتثجحخدذرزسشصضطظعغفقكلمنهوي')


def calibration_ayahs():
    excluded = {tuple(x) for x in json.load(open(os.path.join(HERE, 'benchmark_ayahs.json')))}
    test = {(c['ayahId'] // 1000, c['ayahId'] % 1000)
            for c in json.load(open(os.path.join(HERE, 'artifacts', 'bench_cases.json')))}
    return sorted(excluded - test)


def words_of(ayah_row):
    """Per word index: its sound symbols (markers dropped), as a string."""
    out = collections.defaultdict(str)
    for t, w, f in zip(ayah_row['t'], ayah_row['w'], ayah_row['f']):
        if (ord(f) - 64) & 8:
            continue
        out[ord(w) - 48] += t
    return dict(out)


def edits(e):
    """(category, recited) for each one-sound mistake on expected sounds [e]."""
    out = []
    for i in range(1, len(e) - 1):              # interior sounds only
        c = e[i]
        if c in VOWELS:
            for v in VOWELS:
                if v != c:
                    pair = sorted([VOWELS[c], VOWELS[v]], key=['DAMMA', 'FATHA', 'KASRA'].index)
                    out.append((f'vowel_{pair[0]}_{pair[1]}', e[:i] + v + e[i + 1:]))
            if e[i - 1] in CONS and e[i + 1] in CONS:   # said without its vowel
                out.append(('missing_vowel', e[:i] + e[i + 1:]))
        elif c in CONS:
            for k in CONS:
                if k != c and k not in 'وي':     # (w/y also act as long vowels)
                    out.append(('consonant', e[:i] + k + e[i + 1:]))
            if e[i + 1] == c:                     # shadda said single
                out.append(('shadda_missing', e[:i] + e[i + 1:]))
            elif e[i + 1] in VOWELS and e[i - 1] != c:
                out.append(('shadda_extra', e[:i] + c + e[i:]))
            if e[i + 1] in CONS and e[i + 1] != c:   # sakin said with a vowel
                for v in VOWELS:
                    out.append(('sukun', e[:i + 1] + v + e[i + 1:]))
    return out


def find_pairs():
    ref = json.load(open(os.path.join(ROOT, 'assets/quran/recitation/phonetic_reference_hafs.json')))['ayahs']
    ayahs = calibration_ayahs()
    pool = collections.defaultdict(list)          # sounds -> [(ayahId, word)]
    words = {}
    for s, a in ayahs:
        aid = s * 1000 + a
        ws = words_of(ref[str(aid)])
        last = max(ws)
        for w, snd in ws.items():
            words[(aid, w)] = snd
            if 0 < w < last:                          # not ayah-initial / -final
                pool[snd].append((aid, w))
    pairs = []
    for (aid, w), e in words.items():
        if (aid, w) not in pool.get(e, []):
            continue
        for cat, r in edits(e):
            for src in pool.get(r, []):
                if src[0] != aid:
                    pairs.append(dict(category=cat, ayahId=aid, word=w, expected=e,
                                      srcAyahId=src[0], srcWord=src[1], recited=r))
    return ayahs, pairs


if __name__ == '__main__':
    ayahs, pairs = find_pairs()
    print(len(ayahs), 'calibration ayahs')
    c = collections.Counter(p['category'] for p in pairs)
    u = collections.Counter(p['category'] for p in {(p['category'], p['ayahId'], p['word']): p
                                                    for p in pairs}.values())
    for k in sorted(c):
        print(f'{k:20s} pairs {c[k]:4d}   distinct target words {u[k]:4d}')
