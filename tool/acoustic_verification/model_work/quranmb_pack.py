"""QuranMB.v2 (IqraEval; real speech of Quran phrases, experts' annotation of
what was said) -> a test pack: artifacts/quranmb_cases.json + quranmb_audio.npz.
Laptop-only test data (docs/THIRD_PARTY_RESOURCES.md).

Each clip's reference phonemes are located in the Quran (consonant skeleton,
fuzzy, over Tahfeez's own text) to get its ayah and words. Where the annotation
differs from the reference, the words holding the differences are the mistake
targets (kind 'mistake'); clips said as written are 'clean'.

  python quranmb_pack.py
"""
import csv, collections, io, json, os, re, unicodedata
import numpy as np, pyarrow.parquet as pq, soundfile as sf
from rapidfuzz import fuzz, process

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
EXT = os.path.join(ART, 'external')

# IqraEval phonemes -> Arabic consonants (vowels, long vowels, w/y/hamza and l
# dropped: they are often unwritten, silent or assimilated).
PH = {'b': 'ب', 't': 'ت', '^': 'ث', 'j': 'ج', 'H': 'ح', 'x': 'خ', 'd': 'د', '*': 'ذ',
      'r': 'ر', 'z': 'ز', 's': 'س', '$': 'ش', 'S': 'ص', 'D': 'ض', 'T': 'ط', 'Z': 'ظ',
      'E': 'ع', 'g': 'غ', 'f': 'ف', 'q': 'ق', 'k': 'ك', 'm': 'م', 'n': 'ن', 'h': 'ه'}


def ph_skeleton(phn):
    out = []
    for tok in phn.split():
        c = PH.get(tok[0]) if tok[:1] == tok[-1:] else None
        if c and (not out or out[-1] != c or len(tok) == 1):
            out.append(c)
    return ''.join(out)


def ar_skeleton(word):
    s = unicodedata.normalize('NFKD', word)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.replace('ة', 'ت')
    return ''.join(c for c in s if c in PH.values())


words = json.load(open(os.path.join(HERE, '..', '..', '..', 'assets', 'quran', 'quran_dataset.json')))['ayahWords']
ayah_words = collections.defaultdict(list)
for w in words:
    ayah_words[w['ayahId']].append((w['wordIndex'], w['text']))
index = {}  # ayahId -> (skeleton, word index of each skeleton char)
for aid, ws in ayah_words.items():
    sk, owner = '', []
    for wi, t in sorted(ws):
        k = ar_skeleton(t)
        sk += k
        owner += [wi] * len(k)
    index[aid] = (sk, owner)
ids, sks = list(index), [index[a][0] for a in index]

ref = {r['ID']: r for r in csv.DictReader(open(os.path.join(EXT, 'IqraEval_Test_GT__labels_test.csv')))}
audio = {r['ID']: r['audio'] for r in pq.read_table(
    os.path.join(EXT, 'IqraEval_QuranMB.v2__data_test-00000-of-00001.parquet')).to_pylist()}


def locate(phn):
    k = ph_skeleton(phn)
    if len(k) < 5:
        return None
    # Only ayahs at least as long as the phrase (a short one, like الٓمٓ,
    # would otherwise "contain" anything).
    pool = {j: sk for j, sk in enumerate(sks) if len(sk) >= len(k) - 1}
    best = process.extract(k, pool, scorer=fuzz.partial_ratio, limit=2)
    (s1, score, i), second = best[0], best[1]
    if score < 85 or second[1] >= score - 3:  # weak or ambiguous
        return None
    al = fuzz.partial_ratio_alignment(k, s1)
    owner = index[ids[i]][1]
    return ids[i], owner[al.dest_start], owner[max(al.dest_start, al.dest_end - 1)], k


def differing_words(refp, ann, loc):
    """Words (by position in the reference) where the annotation differs."""
    a, b = refp.split(), ann.split()
    import difflib
    bad = set()
    for op, i1, i2, _, _ in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if op != 'equal':
            bad.update(range(i1, max(i2, i1 + 1)))
    if not bad:
        return []
    # Map reference phoneme positions to words by their share of the phrase.
    aid, w0, w1, _ = loc
    n = w1 - w0 + 1
    return sorted({w0 + min(n - 1, p * n // max(1, len(a))) for p in bad})


cases, blobs, stats = [], {}, collections.Counter()
for cid, r in ref.items():
    loc = locate(r['Reference_phn'])
    if loc is None or cid not in audio:
        stats['not located'] += 1
        continue
    aid, w0, w1, _ = loc
    targets = differing_words(r['Reference_phn'], r['Annotation_phn'], loc)
    w, sr = sf.read(io.BytesIO(audio[cid]['bytes']), dtype='float32')
    if w.ndim > 1:
        w = w.mean(1)
    if sr != 16000:
        import librosa
        w = librosa.resample(w, orig_sr=sr, target_sr=16000)
    kind = 'mistake' if targets else 'clean'
    stats[kind] += 1
    blobs[f'c{len(cases)}'] = w.astype(np.float32)
    cases.append(dict(set='clean' if kind == 'clean' else 'real', kind=kind,
                      category=f'quranmb_{kind}', name=f'quranmb_{cid}',
                      ayahId=aid, firstWord=w0, lastWord=w1, targetWords=targets,
                      openStart=False, openEnd=False, screen=True))  # whole phrases, silence around
json.dump(cases, open(os.path.join(ART, 'quranmb_cases.json'), 'w'))
np.savez(os.path.join(ART, 'quranmb_audio.npz'), **blobs)
print(dict(stats), len(cases), 'cases')
