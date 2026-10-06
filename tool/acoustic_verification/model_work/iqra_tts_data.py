"""Synthetic recitation with injected mistakes (Iqra'Eval `IqraEval/Iqra_TTS`) -> training
shards, teacher-labelled at training time (no transcript).

  python iqra_tts_data.py <out dir> [--hours 12] [--mistake-share 0.7]

Iqra_TTS: TTS voices reading Quran sentences, many with deliberate mispronunciations
(label "augmented": wrong vowels, letters, dropped shadda). The professional and amateur
recordings hold few real mistakes; here the student hears many, labelled by the teacher's
view of what was said. Synthetic voices, so whether it helps on human ones is measured.
Licence: not stated by the dataset — experimental use only (docs/THIRD_PARTY_RESOURCES.md).

Sentences on the test / calibration ayahs (blocked_ayahs.json, matched by consonant
skeleton) are left out.
"""
import argparse, collections, json, os, random, re, unicodedata

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))


def skeleton(s):
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.translate(str.maketrans({'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ی': 'ي',
                                   'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي', 'ٰ': 'ا'}))
    s = re.sub(r'[^ء-غف-ي]', '', s)
    return re.sub('[اويء]', '', s)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--hours', type=float, default=12)
    p.add_argument('--mistake-share', type=float, default=0.7)
    p.add_argument('--seed', type=int, default=0)
    a = p.parse_args()
    from datasets import Audio, load_dataset
    import librosa
    os.makedirs(a.out, exist_ok=True)
    words = json.load(open(os.path.join(HERE, 'quran_dataset.json')))['ayahWords']
    text = collections.defaultdict(list)
    for w in words:
        text[w['ayahId']].append((w['wordIndex'], w['text']))
    blocked = {s * 1000 + v for s, v in json.load(open(os.path.join(HERE, 'blocked_ayahs.json')))}
    blocked_sk = [skeleton(' '.join(t for _, t in sorted(text[b]))) for b in blocked if b in text]
    blocked_sk = [b for b in blocked_sk if len(b) >= 6]

    def on_blocked(sentence):
        k = skeleton(sentence)
        return any(k in b or (len(k) >= 6 and b in k) for b in blocked_sk)

    ds = load_dataset('IqraEval/Iqra_TTS', split='train', streaming=True)
    ds = ds.cast_column('audio', Audio(decode=False))
    rng = random.Random(a.seed)
    budget = {'augmented': a.hours * 3600 * a.mistake_share,
              'other': a.hours * 3600 * (1 - a.mistake_share)}
    shard, n, stats = [], 0, collections.Counter()

    def flush():
        nonlocal shard, n
        if not shard:
            return
        np.savez(os.path.join(a.out, f'shard_{9600 + n:04d}.npz'),
                 audio=np.concatenate(shard).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x in shard]),
                 targets=np.array([[] for _ in shard] + [None], dtype=object)[:-1],
                 ayahs=np.zeros(len(shard), np.int32))
        n += 1
        shard = []

    import io, soundfile as sf
    for row in ds:
        kind = 'augmented' if row['label'] == 'augmented' else 'other'
        if budget[kind] <= 0:
            if all(v <= 0 for v in budget.values()):
                break
            continue
        if on_blocked(row['sentence_ref']):
            stats['blocked'] += 1
            continue
        x, sr = sf.read(io.BytesIO(row['audio']['bytes']), dtype='float32')
        if x.ndim > 1:
            x = x.mean(1)
        if sr != 16000:
            x = librosa.resample(x, orig_sr=sr, target_sr=16000)
        if len(x) < 8000 or len(x) > 20 * 16000:
            stats['length'] += 1
            continue
        budget[kind] -= len(x) / 16000
        stats[kind] += 1
        shard.append((np.clip(x, -1, 1) * 32767).astype(np.int16))
        if len(shard) >= 1000:
            flush()
    flush()
    print(f'{n} shards', dict(stats), flush=True)


if __name__ == '__main__':
    main()
