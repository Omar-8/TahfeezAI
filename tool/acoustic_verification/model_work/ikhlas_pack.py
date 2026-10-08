"""Surah Al-Ikhlas labelled recitations (MuazAhmad7/Surah_Ikhlas-Labeled_Dataset,
CC BY 4.0; 384 learners, one ayah per clip, each judged correct or with its
mistakes named: mostly a missing qalqala on the د, some vowels) -> a test pack in
the bench format: artifacts/ikhlas_cases.json + ikhlas_audio.npz.

A correct clip is a 'clean' case; a clip with mistakes is a 'mistake' case whose
targetWords are the words named in error_location. Its category says which kind
of mistake: ikhlas_correct, ikhlas_qalqala (a qalqala only), ikhlas_vowel (vowels,
possibly with qalqala), ikhlas_other. Laptop-only test data
(docs/THIRD_PARTY_RESOURCES.md); the audio is downloaded to artifacts/external/ikhlas.

  python ikhlas_pack.py
"""
import csv, json, os, re, subprocess, unicodedata
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
SRC = os.path.join(ART, 'external', 'ikhlas')
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))


def skeleton(s):
    """Letters only, alif / hamza seats unified (as retasy_data.py)."""
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.translate(str.maketrans({'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه'}))
    return re.sub(r'[^ء-ي]', '', s)


def load(path):
    pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-ar', '16000', '-ac', '1',
                          '-f', 's16le', '-'], check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2').astype(np.float32) / 32767


words = json.load(open(os.path.join(ROOT, 'assets/quran/quran_dataset.json')))['ayahWords']
ayah_words = {}
for w in words:
    if w['ayahId'] // 1000 == 112:
        ayah_words.setdefault(w['ayahId'], {})[w['wordIndex']] = skeleton(w['text'])

cases, blobs, seen, unplaced = [], {}, set(), 0
for r in csv.DictReader(open(os.path.join(SRC, 'metadata.csv'), encoding='utf-8')):
    f = r['file_name']
    if f in seen:
        continue
    seen.add(f)
    aid = 112000 + int(r['verse_number'])
    correct = r['label_name'].strip() == 'correct'
    targets = []
    if not correct:
        # error_location names the word(s), comma-separated, in Uthmani text
        for loc in re.split(r'[,،]', r['error_location']):
            sk = skeleton(loc)
            hit = [i for i, w in ayah_words[aid].items() if sk and (w == sk or sk in w or w in sk)]
            targets += [i for i in hit if i not in targets]
        if not targets:
            unplaced += 1
            continue
    why = r['error_explanation']
    vowel = re.search(r'ضمة|كسرة|فتحة|الحركة|حركات|السكون|التنوين', why) is not None
    qalqala = 'قلقلة' in why
    category = ('ikhlas_correct' if correct else 'ikhlas_vowel' if vowel
                else 'ikhlas_qalqala' if qalqala else 'ikhlas_other')
    blobs[f'c{len(cases)}'] = load(os.path.join(SRC, f))
    cases.append(dict(set='clean' if correct else 'mistake', kind='clean' if correct else 'mistake',
                      name='ikhlas_' + os.path.basename(f)[:-4], category=category,
                      ayahId=aid, firstWord=0, lastWord=max(ayah_words[aid]), targetWords=sorted(targets),
                      openStart=False, openEnd=False, screen=True,
                      reciter=re.match(r'ID(\d+)', os.path.basename(f)).group(1), explanation=why.strip()))
json.dump(cases, open(os.path.join(ART, 'ikhlas_cases.json'), 'w'), ensure_ascii=False)
np.savez(os.path.join(ART, 'ikhlas_audio.npz'), **blobs)
from collections import Counter
print(len(cases), 'clips;', dict(Counter(c['category'] for c in cases)), f'; {unplaced} errors not placed;',
      len({c['reciter'] for c in cases}), 'reciters')
