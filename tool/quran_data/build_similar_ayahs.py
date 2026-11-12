#!/usr/bin/env python3
"""Builds the similar ayahs (mutashābihāt) for the ayah sheet and Hifz
(assets/quran/similar_ayahs.json), computed from the app's own Quran text
(assets/quran/quran_dataset.json: Tanzil Uthmani 1.1, its `ayahWords`). No
outside list, no AI: two ayahs are "similar" when their words, compared
without vowel marks (hamza and alef forms folded, tā' marbūṭa as hā'), are
mostly the same in the same order, or share a long run of words:

  - the share of matching words (difflib's ratio over the two word lists)
    is at least 0.6, both ayahs having 3 words or more; or
  - they share a run of 6 words or more, at least half the shorter ayah; or
  - they share a run of 4 words or more, at least 80% of the shorter one
    (at least 4 words long).

The Quran text itself is never changed or copied: the output holds only
ayah ids, a score, and the positions (word indexes, the app's own) of the
words that differ, which the app shows in its canonical text.

  python3 tool/quran_data/build_similar_ayahs.py

Output: {"version": 1, "source": <the dataset's version>, "pairs":
[[ayahA, ayahB, score (0-100), "differing word indexes of A",
"... of B"], ...]} with ayahA < ayahB, indexes comma-separated ("" when
none: the same words).
"""
import collections
import difflib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = ROOT / 'assets/quran/quran_dataset.json'
OUT = ROOT / 'assets/quran/similar_ayahs.json'

# Vowel and Quranic marks, tatweel; the letter folds a reciter's ear ignores
# when comparing (أ إ آ ٱ → ا, ى → ي, ة → ه, ؤ → و, ئ → ي).
MARKS = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')
FOLDS = str.maketrans({'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ى': 'ي',
                       'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي'})

# A three-word phrase found in more ayahs than this is a formula ("إن الله
# على كل"), not a lead to a similar ayah: not used to find candidates.
COMMON = 60


def folded(word):
    return MARKS.sub('', word).translate(FOLDS)


def main():
    data = json.load(open(DATASET))
    words = collections.defaultdict(list)
    for w in data['ayahWords']:
        words[w['ayahId']].append((w['wordIndex'], w['text']))
    ayahs = {a: [folded(t) for _, t in sorted(ws)] for a, ws in words.items()}
    assert len(ayahs) == 6236, len(ayahs)

    trigrams = collections.defaultdict(set)
    for a, w in ayahs.items():
        for i in range(len(w) - 2):
            trigrams[tuple(w[i:i + 3])].add(a)

    pairs = []
    for a in sorted(ayahs):
        wa = ayahs[a]
        candidates = set()
        for i in range(len(wa) - 2):
            group = trigrams[tuple(wa[i:i + 3])]
            if len(group) <= COMMON:
                candidates |= {b for b in group if b > a}
        for b in sorted(candidates):
            wb = ayahs[b]
            sm = difflib.SequenceMatcher(None, wa, wb, autojunk=False)
            ratio = sm.ratio()
            blocks = sm.get_matching_blocks()
            run = max(m.size for m in blocks)
            shorter = min(len(wa), len(wb))
            if not ((ratio >= 0.6 and shorter >= 3)
                    or (run >= 6 and run >= 0.5 * shorter)
                    or (run >= 4 and run >= 0.8 * shorter and shorter >= 4)):
                continue
            same_a = {m.a + k for m in blocks for k in range(m.size)}
            same_b = {m.b + k for m in blocks for k in range(m.size)}
            diff_a = [i for i in range(len(wa)) if i not in same_a]
            diff_b = [i for i in range(len(wb)) if i not in same_b]
            pairs.append([a, b, round(ratio * 100),
                          ','.join(map(str, diff_a)),
                          ','.join(map(str, diff_b))])

    out = {
        'version': 1,
        'source': data['metadata']['datasetVersion'],
        'pairs': pairs,
    }
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':'))
                   + '\n')
    linked = {p[0] for p in pairs} | {p[1] for p in pairs}
    print(f'{OUT.relative_to(ROOT)}: {len(pairs)} pairs, '
          f'{len(linked)} ayahs, {OUT.stat().st_size // 1024} KB')


if __name__ == '__main__':
    main()
