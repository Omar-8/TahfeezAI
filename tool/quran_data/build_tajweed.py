#!/usr/bin/env python3
"""Builds the tajweed colours for Ayah mode (assets/quran/tajweed/tajweed.json)
from cpfair/quran-tajweed (CC BY 4.0; vendored in sources/cpfair-tajweed/).

Its annotations give each rule's exact code points in Tanzil's Uthmani text as
downloaded in 2017. The app's canonical text is Tanzil Uthmani 1.1
(tool/quran_data/.cache/tanzil_uthmani.txt, fetched by fetch_sources.dart),
which writes 309 ayahs slightly differently (a hamza on a tatweel, a small yā'
on a tatweel, three spaces, two letters). Each ayah of the old text is aligned
to the new one and every annotation carried across; then split at the spaces
into the app's words (the Bismillah before each surah's first ayah left out,
as the app's data does). The Quran text itself is never changed: the output
holds only (word, start, end, rule) positions in the app's own words.

Fails loudly when an annotation lands on text other than its own (beyond the
known spelling changes) or breaks a rule's letter check (qalqala on ق ط ب ج د,
ghunnah on a doubled ن or م, iqlāb before ب, ...).

  python3 tool/quran_data/build_tajweed.py
"""
import difflib, hashlib, io, json, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'tool/quran_data/sources/cpfair-tajweed/cpfair-tajweed.zip'
APP_TEXT = ROOT / 'tool/quran_data/.cache/tanzil_uthmani.txt'
OUT = ROOT / 'assets/quran/tajweed/tajweed.json'

# Stable order: the app refers to rules by these names.
RULES = [
    'hamzat_wasl', 'lam_shamsiyyah', 'silent',
    'madd_2', 'madd_246', 'madd_munfasil', 'madd_muttasil', 'madd_6',
    'ghunnah', 'ikhfa', 'ikhfa_shafawi', 'iqlab',
    'idghaam_ghunnah', 'idghaam_shafawi',
    'idghaam_no_ghunnah', 'idghaam_mutajanisayn', 'idghaam_mutaqaribayn',
    'qalqalah',
]

# The spelling changes between the 2017 copy and Tanzil 1.1 (old, new): the
# only differences an annotation may cover.
KNOWN = {
    ('\u0621', '\u0640\u0654'),  # hamza -> tatweel + hamza above
    ('\u06e6', '\u0640\u06e7'),  # small yā' -> tatweel + high small yā'
    ('\u0649', ''),  # an alif maqṣūra dropped (twice)
    ('', ' '),  # a space added (three times)
    ('', '\u0640'),  # a tatweel added (twice)
}


def lines(text):
    out = {}
    for line in text.splitlines():
        parts = line.lstrip('\ufeff').rstrip('\r').split('|')
        if len(parts) >= 3 and parts[0].isdigit():
            out[(int(parts[0]), int(parts[1]))] = parts[2]
    return out


def same_but_known(old, new):
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, old, new, autojunk=False).get_opcodes():
        if op != 'equal' and (old[i1:i2], new[j1:j2]) not in KNOWN:
            return False
    return True


def aligner(old, new):
    """Maps a start / end offset in [old] to [new]."""
    starts, ends = {}, {}
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, old, new, autojunk=False).get_opcodes():
        if op == 'equal':
            for k in range(i2 - i1 + 1):
                starts.setdefault(i1 + k, j1 + k)
                ends[i1 + k] = j1 + k
        else:
            starts.setdefault(i1, j1)
            for k in range(i1 + 1, i2 + 1):
                starts.setdefault(k, j2)
                ends[k] = j2
            ends.setdefault(i1, j1)
    return starts.__getitem__, ends.__getitem__


QALQALA = set('قطبجد')
SHADDA = 'ّ'


def check(rule, span, after):
    """The letters a rule must sit on — a broken alignment would miss them."""
    letters = [c for c in span if 'ء' <= c <= 'ي' or c in 'ٱ']
    if rule == 'qalqalah':
        return any(c in QALQALA for c in span)
    if rule == 'ghunnah':
        return any(c in 'نم' for c in span) and SHADDA in span
    if rule == 'iqlab':
        return 'ب' in span or 'ب' in after[:2]
    if rule == 'hamzat_wasl':
        return span.startswith('ٱ')
    if rule == 'lam_shamsiyyah':
        return 'ل' in span
    if rule in ('ikhfa_shafawi', 'idghaam_shafawi'):
        return 'م' in span
    if rule in ('ikhfa', 'idghaam_ghunnah', 'idghaam_no_ghunnah'):
        # A noon sākina (or the small high noon of «نُـۨجِى», 21:88) or a
        # tanwīn (fatḥatān, ḍammatān, kasratān, or their open forms).
        return 'ن' in span or any(c in span for c in (
            '\u06e8\u064b\u064c\u064d\u08f0\u08f1\u08f2'))
    return bool(span.strip()) or not letters


def main():
    with zipfile.ZipFile(SRC) as z:
        annotations = json.loads(z.read('tajweed.json'))
        old_text = lines(z.read('quran-uthmani-2017.txt').decode('utf-8'))
    new_text = lines(APP_TEXT.read_text(encoding='utf-8'))
    assert len(old_text) == len(new_text) == 6236, (len(old_text), len(new_text))

    ayahs, bad, total, counts = {}, [], 0, {r: 0 for r in RULES}
    for entry in annotations:
        key = (entry['surah'], entry['ayah'])
        old, new = old_text[key], new_text[key]
        start_of, end_of = aligner(old, new)
        # The app's words: whitespace tokens, the Bismillah dropped from
        # surah openings (tanzil_source.dart).
        offsets, pos = [], 0
        for token in new.split(' '):
            if token:
                offsets.append((pos, pos + len(token)))
            pos += len(token) + 1
        skip = 4 if key[1] == 1 and key[0] not in (1, 9) else 0
        flat = []
        for a in entry['annotations']:
            rule = a['rule']
            if rule not in counts:
                sys.exit(f'unknown rule {rule}')
            s, e = start_of(a['start']), end_of(a['end'])
            if not same_but_known(old[a['start']:a['end']], new[s:e]):
                bad.append((key, rule, old[a['start']:a['end']], new[s:e]))
                continue
            if not check(rule, new[s:e], new[e:]):
                bad.append((key, rule, 'letter check', new[s:e]))
                continue
            total += 1
            counts[rule] += 1
            for w, (ws, we) in enumerate(offsets):
                lo, hi = max(s, ws), min(e, we)
                if lo < hi and w >= skip:
                    flat += [w - skip, lo - ws, hi - ws, RULES.index(rule)]
        if flat:
            ayahs[str(key[0] * 1000 + key[1])] = flat
    if bad:
        for b in bad[:20]:
            print('MISMATCH', b)
        sys.exit(f'{len(bad)} annotations do not line up with the app text')

    # The app's words (AyahWords), one ayah a line: "<id>|<words>" — the
    # integrity test recomputes this from the bundled Quran database.
    def words_of(s, a):
        words = new_text[(s, a)].split()
        return words[4:] if a == 1 and s not in (1, 9) else words
    canonical = '\n'.join(
        f'{s * 1000 + a}|{" ".join(words_of(s, a))}' for (s, a) in sorted(new_text))
    out = {
        'source': 'cpfair/quran-tajweed 496f71cd (CC BY 4.0), output/tajweed.hafs.uthmani-pause-sajdah.json',
        'rules': RULES,
        'text_sha256': hashlib.sha256(canonical.encode('utf-8')).hexdigest(),
        'ayahs': ayahs,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, separators=(',', ':'), sort_keys=True), encoding='utf-8')
    print(f'{total} annotations, {len(ayahs)} ayahs -> {OUT.relative_to(ROOT)} '
          f'({OUT.stat().st_size // 1024} KB)')
    for r in RULES:
        print(f'  {r}: {counts[r]}')


if __name__ == '__main__':
    main()
