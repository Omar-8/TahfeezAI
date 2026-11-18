#!/usr/bin/env python3
"""Builds each Quran word's root (assets/quran/word_roots.json) from the
Quranic Arabic Corpus morphology, version 0.4 (Kais Dukes, GPL — see
docs/THIRD_PARTY_RESOURCES.md), for the word pill and the word's sheet in
Arabic (owner, 2026-11-18).

The corpus file is read as published (never changed); only its roots are
taken, transliterated from its Buckwalter letters to Arabic as the corpus's
own dictionary pages write them (its «A» is «أ»: «أ م ن», «ج ي أ»). The
Quran text itself is never copied: the output holds only the app's own
word positions (ayah id, 0-based word index) and the roots.

The corpus numbers words as Tanzil Uthmani 1.0.2 does, which is the app's
canonical text but for four places where the app writes as two words what
the corpus counts as one («بَعْدَ مَا» ×3, «إِلْ يَاسِينَ») — mapped
explicitly below; any other difference in an ayah's word count stops the
build.

  python3 tool/quran_data/build_word_roots.py

Input: tool/quran_data/.cache/qac_morphology/quranic-corpus-morphology-0.4.txt
(https://corpus.quran.com/download; SHA-256 checked below).

Output: {"version": 1, "source": ..., "sha256": ..., "roots": {"<ayahId>":
"<root>,<root>,...", ...}} — one entry per word in order, "" for a word
with no root (a particle, a pronoun, a name the corpus gives none);
ayahs without any root left out. Roots are written without spaces.
"""
import collections
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tool/quran_data/.cache/qac_morphology/quranic-corpus-morphology-0.4.txt'
SOURCE_SHA256 = '910b721a8f04f4334ac5d4c62b19e858f5d720c525bb975f2e750ea2c6bb532d'
DATASET = ROOT / 'assets/quran/quran_dataset.json'
OUT = ROOT / 'assets/quran/word_roots.json'

# Buckwalter (the corpus's transliteration) to Arabic, for root letters.
BUCKWALTER = {
    "'": 'ء', '>': 'أ', '&': 'ؤ', '<': 'إ', '}': 'ئ', 'A': 'أ', 'b': 'ب',
    'p': 'ة', 't': 'ت', 'v': 'ث', 'j': 'ج', 'H': 'ح', 'x': 'خ', 'd': 'د',
    '*': 'ذ', 'r': 'ر', 'z': 'ز', 's': 'س', '$': 'ش', 'S': 'ص', 'D': 'ض',
    'T': 'ط', 'Z': 'ظ', 'E': 'ع', 'g': 'غ', 'f': 'ف', 'q': 'ق', 'k': 'ك',
    'l': 'ل', 'm': 'م', 'n': 'ن', 'h': 'ه', 'w': 'و', 'Y': 'ى', 'y': 'ي',
}

# The corpus's one word that the app writes as two: (ayah, corpus word
# number) → the app's two word indexes; its root goes to the first.
SPLIT = {
    (2181, 3): (2, 3),  # بَعْدَ مَا
    (8006, 4): (3, 4),  # بَعْدَ مَا
    (13037, 8): (7, 8),  # بَعْدَ مَا
    (37130, 3): (2, 3),  # إِلْ يَاسِينَ
}


def main() -> None:
    raw = SOURCE.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != SOURCE_SHA256:
        sys.exit(f'{SOURCE.name}: SHA-256 {digest}, expected {SOURCE_SHA256}')

    # The corpus: each word's root (its stem's), by (ayah, word number).
    corpus_words = collections.defaultdict(set)
    roots: dict[tuple[int, int], str] = {}
    row = re.compile(r'\((\d+):(\d+):(\d+):(\d+)\)\t[^\t]*\t[^\t]+\t(\S+)')
    for line in raw.decode('utf-8').splitlines():
        m = row.match(line)
        if not m:
            continue
        surah, ayah, word, _, features = m.groups()
        key = (int(surah) * 1000 + int(ayah), int(word))
        corpus_words[key[0]].add(key[1])
        root = re.search(r'ROOT:([^|]+)', features)
        if root and 'STEM' in features.split('|')[0] and key not in roots:
            letters = root.group(1)
            if any(c not in BUCKWALTER for c in letters):
                sys.exit(f'{key}: unknown root letter in {letters!r}')
            roots[key] = ''.join(BUCKWALTER[c] for c in letters)

    # The app's words, per ayah (the canonical script).
    dataset = json.loads(DATASET.read_text(encoding='utf-8'))
    app_words = collections.Counter(
        w['ayahId'] for w in dataset['ayahWords'] if w['scriptId'] == 1
    )
    if set(app_words) != set(corpus_words):
        sys.exit('the corpus and the app have different ayahs')

    out: dict[str, str] = {}
    with_root = 0
    for ayah_id in sorted(app_words):
        count = app_words[ayah_id]
        splits = {w: idx for (a, w), idx in SPLIT.items() if a == ayah_id}
        if len(corpus_words[ayah_id]) + len(splits) != count:
            sys.exit(
                f'{ayah_id}: the app has {count} words, the corpus '
                f'{len(corpus_words[ayah_id])} (+{len(splits)} split)'
            )
        if corpus_words[ayah_id] != set(range(1, len(corpus_words[ayah_id]) + 1)):
            sys.exit(f'{ayah_id}: the corpus skips a word number')
        per_word = [''] * count
        shift = 0
        for word in sorted(corpus_words[ayah_id]):
            index = word - 1 + shift
            if word in splits:
                first, _ = splits[word]
                if first != index:
                    sys.exit(f'{ayah_id}: split word {word} not at {first}')
                shift += 1
            per_word[index] = roots.get((ayah_id, word), '')
        with_root += sum(1 for r in per_word if r)
        if any(per_word):
            out[str(ayah_id)] = ','.join(per_word)

    OUT.write_text(
        json.dumps(
            {
                'version': 1,
                'source': 'Quranic Arabic Corpus morphology 0.4 (corpus.quran.com)',
                'sha256': SOURCE_SHA256,
                'roots': out,
            },
            ensure_ascii=False,
            separators=(',', ':'),
        ),
        encoding='utf-8',
    )
    total = sum(app_words.values())
    print(
        f'{OUT.relative_to(ROOT)}: {with_root} of {total} words with a root, '
        f'{len(out)} ayahs, {OUT.stat().st_size} bytes'
    )


if __name__ == '__main__':
    main()
