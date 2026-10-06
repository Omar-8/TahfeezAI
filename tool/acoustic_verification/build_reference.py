"""Build assets/quran/recitation/phonetic_reference_hafs.json: the expected
pronunciation of every ayah (Hafs, Quran Phonetic Script) as the acoustic
verifier's CTC tokens, each mapped back to its Tahfeez word and letter.

The phonemes come from the rule-based `quran_transcript` phonetizer (MIT)
over its bundled Tanzil Uthmani text. No Quran text is generated or edited:
the build aborts unless, for every ayah, the word count matches Tahfeez's
dataset. Per word it also checks that the base letters agree with
Tahfeez's own text, so a letter position here is a letter position there.

Per ayah (strings of one character per token):
  t  token symbol (phoneme vocabulary)
  u  sound unit       chr(48 + n)
  w  word index       chr(48 + n)
  l  letter ordinal   chr(48 + n)   within the word
  c  source Uthmani character
  f  flags            chr(64 + mask): 1 vowel, 2 long, 4 consonant,
                      8 marker (optional), 16 geminate, 32 unit-final vowel
  v  per sound unit, its forms at a pause, from the phonetizer on the text
     cut there: {unit: {"w": waqf (stopping after it), "i": ibtida
     (starting with it), "b": both}}, each [drop, t, w, l, c, f] — drop
     tokens from the unit's end (w, b: all for b) or start (i), and put
     these tokens there instead. The ayah's last unit may also have "c"
     (continuing into the next ayah without stopping, an end edit) and its
     first unit "j" (joined on from the previous ayah, a start edit).

Usage: python build_reference.py <repo root>
"""
import json, os, sys, unicodedata
from multiprocessing import Pool

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from acoustic import Aya, has_letter, join_forms, reference, unit_variants  # noqa: E402

LETTERS = lambda w: [c for c in w if ("ء" <= c <= "ي" or c in "ٱٰ") and c != "ـ"]


def build(key):
    s, a = key
    uth = Aya(s, a).get().uthmani
    toks = reference(uth)
    words = [w for w in uth.split(' ') if has_letter(w)]
    flag = lambda t: (1 * (t.kind == 'vowel') | 2 * (t.kind == 'long') | 4 * (t.kind == 'consonant')
                      | 8 * (t.kind == 'marker') | 16 * t.geminate | 32 * t.unit_final_vowel)
    enc = lambda ts: [''.join(t.sym for t in ts), ''.join(chr(48 + t.word) for t in ts),
                      ''.join(chr(48 + t.letter) for t in ts), ''.join(t.uth_char for t in ts),
                      ''.join(chr(64 + flag(t)) for t in ts)]
    key = lambda t: (t.label, t.geminate)
    variants = {}
    for u, var in unit_variants(uth, toks).items():
        default = [t for t in toks if t.unit == u]
        out = {}
        for kind, pick in var.items():
            if kind == 'waqf':
                n = 0
                while n < min(len(default), len(pick)) and key(default[n]) == key(pick[n]):
                    n += 1
                out['w'] = [len(default) - n] + enc(pick[n:])
            elif kind == 'ibtida':
                n = 0
                while (n < min(len(default), len(pick))
                       and key(default[-1 - n]) == key(pick[-1 - n])):
                    n += 1
                out['i'] = [len(default) - n] + enc(pick[:len(pick) - n])
            else:
                out['b'] = [len(default)] + enc(pick)
        # "both" is usually waqf and ibtida applied together: keep it only
        # when it is not.
        if 'b' in out:
            syms = [t.sym for t in default]
            if 'w' in out:
                syms = syms[:len(syms) - out['w'][0]] + list(out['w'][1])
            if 'i' in out:
                syms = list(out['i'][1]) + syms[out['i'][0]:]
            if syms == list(out['b'][1]):
                del out['b']
        variants[str(u)] = out
    row = dict(
        t=''.join(t.sym for t in toks),
        u=''.join(chr(48 + t.unit) for t in toks),
        w=''.join(chr(48 + t.word) for t in toks),
        l=''.join(chr(48 + t.letter) for t in toks),
        c=''.join(t.uth_char for t in toks),
        f=''.join(chr(64 + flag(t)) for t in toks),
    )
    # Joined to the neighbouring ayahs of the same surah (wasl).
    def end_edit(default, pick):
        n = 0
        while n < min(len(default), len(pick)) and key(default[n]) == key(pick[n]):
            n += 1
        return [len(default) - n] + enc(pick[n:])

    def start_edit(default, pick):
        n = 0
        while n < min(len(default), len(pick)) and key(default[-1 - n]) == key(pick[-1 - n]):
            n += 1
        return [len(default) - n] + enc(pick[:len(pick) - n])

    last_u, first_u = toks[-1].unit, toks[0].unit
    nxt = Aya(s, a + 1).get().uthmani if a < Aya(s, a).get().num_ayat_in_sura else None
    prv = Aya(s, a - 1).get().uthmani if a > 1 else None
    if nxt is not None:
        j = join_forms(uth, nxt)
        default = [t for t in toks if t.unit == last_u]
        if j and [key(t) for t in j[0]] != [key(t) for t in default]:
            variants.setdefault(str(last_u), {})['c'] = end_edit(default, j[0])
    if prv is not None:
        j = join_forms(prv, uth)
        default = [t for t in toks if t.unit == first_u]
        if j and [key(t) for t in j[1]] != [key(t) for t in default]:
            variants.setdefault(str(first_u), {})['j'] = start_edit(default, j[1])
    if variants:
        row['v'] = variants
    return s * 1000 + a, words, row


def main():
    root = sys.argv[1]
    data = json.load(open(os.path.join(root, 'assets/quran/quran_dataset.json')))
    ours = {}
    for w in data['ayahWords']:
        ours.setdefault(w['ayahId'], {})[w['wordIndex']] = w['text']
    keys = [(x['chapterNo'], x['verseNo']) for x in data['ayahs']]
    with Pool() as pool:
        rows = pool.map(build, keys, chunksize=16)
    ayahs, letter_mismatch = {}, 0
    for ayah_id, words, row in rows:
        mine = [ours[ayah_id][i] for i in sorted(ours[ayah_id])]
        if len(mine) != len(words):
            sys.exit(f'{ayah_id}: {len(words)} words, dataset has {len(mine)}')
        for x, y in zip(words, mine):
            if LETTERS(unicodedata.normalize('NFC', x)) != LETTERS(unicodedata.normalize('NFC', y)):
                letter_mismatch += 1
        ayahs[str(ayah_id)] = row
    out = dict(format=3, tokens=sum(len(r['t']) for r in ayahs.values()),
               letter_mismatched_words=letter_mismatch,
               source='quran_transcript 0.6.4 (MIT) over its Tanzil Uthmani text; Hafs, madd 4/4/4/2',
               ayahs=ayahs)
    path = os.path.join(root, 'assets/quran/recitation/phonetic_reference_hafs.json')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(out, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(f"{len(ayahs)} ayahs, {out['tokens']} tokens, {letter_mismatch} words whose letters differ",
          f"{os.path.getsize(path) // 1000} kB")


if __name__ == '__main__':
    main()
