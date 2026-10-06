"""sobolev210/quran-recitation-errors (MIT; recitations reviewed word by
word: Letters / Tajweed / Tashkeel / Wording) -> a test pack: artifacts/
errors_cases.json + errors_audio.npz. Ḥafṣ recordings that a reviewer
checked only; a clip with a reviewed mistake is kind 'mistake' (its words
the targets), one without is 'clean'. Laptop-only test data
(docs/THIRD_PARTY_RESOURCES.md).

  python errors_pack.py
"""
import ast, io, json, os, re, unicodedata
import numpy as np, pyarrow.parquet as pq, soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
words = json.load(open(os.path.join(HERE, '..', '..', '..', 'assets', 'quran', 'quran_dataset.json')))['ayahWords']
ayah_words = {}
for w in words:
    ayah_words.setdefault(w['ayahId'], {})[w['wordIndex']] = w['text']


def bare(s):
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.translate(str.maketrans({'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ٰ': 'ا'}))
    return re.sub(r'[^ء-ي]', '', s)


cases, blobs = [], {}
for r in pq.read_table(os.path.join(ART, 'external', 'sobolev_errors.parquet')).to_pylist():
    if r['riwayah'] != 'Hafs' or r['reviewer_id'] == 'not reviewed':
        continue
    aid = int(r['surah']) * 1000 + int(r['ayah'])
    if aid not in ayah_words:
        continue
    e = r['errors']
    e = ast.literal_eval(e) if isinstance(e, str) else (e or {})
    marked = {bare(k): v for k, v in e.items() if v}
    ours = ayah_words[aid]
    targets = sorted(i for i, t in ours.items() if bare(t) in marked)
    kinds = sorted({k for i in targets for k in marked[bare(ours[i])]})
    w, sr = sf.read(io.BytesIO(r['audio']['bytes']), dtype='float32')
    if w.ndim > 1:
        w = w.mean(1)
    if sr != 16000:
        import librosa
        w = librosa.resample(w, orig_sr=sr, target_sr=16000)
    kind = 'mistake' if targets else 'clean'
    blobs[f'c{len(cases)}'] = w.astype(np.float32)
    cases.append(dict(set='clean' if kind == 'clean' else 'real', kind=kind,
                      category=f'errors_{kind}', name=f"errors_{r['recording_id'][:8]}_{aid}",
                      ayahId=aid, firstWord=0, lastWord=max(ours), targetWords=targets,
                      kinds=kinds, openStart=False, openEnd=False, screen=True))
json.dump(cases, open(os.path.join(ART, 'errors_cases.json'), 'w'), ensure_ascii=False)
np.savez(os.path.join(ART, 'errors_audio.npz'), **blobs)
print(len(cases), 'clips;', sum(c['kind'] == 'mistake' for c in cases), 'with reviewed mistakes')
