"""Crowd-sourced Juz 30 recitation (Kaggle afsahurrehman11/quran-juz-30-recitation-audio-dataset,
Apache 2.0; its local_dataset: ~25 non-professional reciters recording ayahs in a memorization
app, 6,159 clips, 37 marked verified) -> distillation shards without transcripts, for v3.5 to
judge as a second teacher (distill_student.py --guide): amateurs' audio where the teachers are
too strict. Unverified, so it may hold mistakes: no transcript is trusted, none written.

The dataset's professional part (everyayah reciters, some in the test sets) is not used, and
no ayah in blocked_ayahs.json is written, as for every source.

EXPERIMENTAL / NOT YET CLEARED FOR DISTRIBUTION (docs/THIRD_PARTY_RESOURCES.md).

  python juz30_data.py <out dir> [--src artifacts/external/juz30/quran_juz30/local_dataset]
      [--hold N]   # the N reciters with the fewest clips kept out (a later test)
"""
import argparse, collections, csv, json, os, subprocess

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
MAX_S, MIN_S = 18.0, 0.8


def verses():
    """Global ayah number (1-based, as the dataset's Ayat_Number) -> (surah, ayah)."""
    data = json.load(open(os.path.join(ROOT, 'assets/quran/quran_dataset.json'), encoding='utf-8'))
    out, n = {}, 0
    for s in data['surahs']:
        for a in range(1, s['ayahCount'] + 1):
            n += 1
            out[n] = (s['surahNo'], a)
    return out


def decode(path):
    raw = subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-i', path, '-ac', '1',
                          '-ar', '16000', '-f', 's16le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, '<i2').astype(np.float32) / 32767


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--src', default=os.path.join(HERE, 'artifacts/external/juz30/quran_juz30/local_dataset'))
    p.add_argument('--hold', type=int, default=0)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    blocked = {tuple(x) for x in json.load(open(os.path.join(HERE, 'blocked_ayahs.json')))}
    where = verses()
    rows = list(csv.DictReader(open(os.path.join(a.src, 'para30_complete_recordings_uthmani.csv'),
                                    encoding='utf-8')))
    per = collections.Counter(r['Recorder_Name'] for r in rows)
    held = {name for name, _ in sorted(per.items(), key=lambda x: x[1])[:a.hold]}
    clips, skipped = [], collections.Counter()
    for r in rows:
        ayah = where[int(r['Ayat_Number'])]
        if ayah in blocked:
            skipped['blocked'] += 1; continue
        if r['Recorder_Name'] in held:
            skipped['held'] += 1; continue
        path = os.path.join(a.src, 'audios', os.path.basename(r['Recording_Path']))
        try:
            x = decode(path)
        except (subprocess.CalledProcessError, FileNotFoundError):
            skipped['undecodable'] += 1; continue
        if not MIN_S * 16000 <= len(x) <= MAX_S * 16000:
            skipped['length'] += 1; continue
        clips.append(x)
    for k in range(0, len(clips), 400):
        part = clips[k:k + 400]
        np.savez(os.path.join(a.out, f'shard_{9400 + k // 400:04d}.npz'),
                 audio=np.concatenate([np.clip(x, -1, 1) * 32767 for x in part]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x in part]),
                 targets=np.array([[] for _ in part] + [None], dtype=object)[:-1])
    json.dump(sorted(held), open(os.path.join(a.out, 'held_reciters.json'), 'w'), ensure_ascii=False)
    print(dict(clips=len(clips), hours=round(sum(map(len, clips)) / 16000 / 3600, 2),
               shards=(len(clips) + 399) // 400, skipped=dict(skipped), held=sorted(held)))


if __name__ == '__main__':
    main()
