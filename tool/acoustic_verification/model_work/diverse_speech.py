"""G22 (2026-10-21): ordinary Arabic speech from many people, devices and rooms, for acoustic
robustness only -> training shards with EMPTY transcripts (the teacher's frames are the target;
no Quran CTC on speech that is not Quran).

  python diverse_speech.py fleurs <out dir> [--splits train,dev]
  python diverse_speech.py cv <out dir> --src <Common Voice dir: validated.tsv, clips/>
         [--minutes-per-speaker 3] [--hours 40]
  python diverse_speech.py cv18 <out dir> [--minutes-per-speaker 3] [--hours 40]

Sources (docs/THIRD_PARTY_RESOURCES.md):
- fleurs: google/fleurs, config ar_eg (CC BY 4.0): read sentences by volunteers, kept as
  recorded ("quiet or noisy"). Its test split is never used. -> shard_63NN
- cv: Mozilla Common Voice Arabic (CC0), validated.tsv: up to --minutes-per-speaker per
  client_id (random clips), speakers in random order until --hours: many voices, phones and
  rooms rather than many hours of a few. -> shard_64NN
- cv18: the same, Common Voice 18 Arabic as Hugging Face parquet
  (MohamedRashad/common-voice-18-arabic; CC0 at its source, Mozilla): its train, validation,
  test and other splits (never invalidated), each row's client_id the speaker. -> shard_64NN

Clips of 1.5-20 s, 16 kHz mono; never augmented in training (--real-phone shard_63+shard_64).
"""
import argparse, collections, csv, io, os, random, subprocess, sys, tarfile
import numpy as np

SR = 16000
csv.field_size_limit(sys.maxsize)


def pcm(data):
    """Any audio file's bytes -> float32 16 kHz mono (ffmpeg)."""
    out = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', '-', '-ar', str(SR), '-ac', '1',
                          '-f', 's16le', '-'], input=data, check=True, capture_output=True).stdout
    return np.frombuffer(out, '<i2').astype(np.float32) / 32767


class Shards:
    def __init__(self, out, base, clips=1000):
        self.out, self.base, self.clips, self.n, self.cur = out, base, clips, 0, []
        self.hours = 0.0
        os.makedirs(out, exist_ok=True)

    def add(self, x):
        self.cur.append((np.clip(x, -1, 1) * 32767).astype(np.int16))
        self.hours += len(x) / SR / 3600
        if len(self.cur) == self.clips:
            self.flush()

    def flush(self):
        if not self.cur:
            return
        np.savez(os.path.join(self.out, f'shard_{self.base}{self.n:02d}.npz'),
                 audio=np.concatenate(self.cur), offsets=np.cumsum([0] + [len(x) for x in self.cur]),
                 targets=np.array([[] for _ in self.cur] + [None], dtype=object)[:-1])
        self.n += 1; self.cur = []


def usable(x):
    return 1.5 * SR <= len(x) <= 20 * SR and np.abs(x).max() > 1e-3


def fleurs(a):
    sh, kept, skipped = Shards(a.out, 63), 0, 0
    for split in a.splits.split(','):
        assert split != 'test', 'the FLEURS test split is never used'
        url = f'https://huggingface.co/datasets/google/fleurs/resolve/main/data/ar_eg/audio/{split}.tar.gz'
        path = os.path.join(a.cache, f'fleurs_ar_eg_{split}.tar.gz')
        if not os.path.exists(path):
            subprocess.run(['curl', '-sfL', '--retry', '5', '-o', path + '.part', url], check=True)
            os.rename(path + '.part', path)
        with tarfile.open(path) as tf:
            for m in tf:
                if not m.isfile() or not m.name.endswith('.wav'):
                    continue
                x = pcm(tf.extractfile(m).read())
                if usable(x):
                    sh.add(x); kept += 1
                else:
                    skipped += 1
    sh.flush()
    print(f'fleurs: {kept} clips, {sh.hours:.1f} h, {sh.n} shards (skipped {skipped})')


def cv(a):
    rows = list(csv.DictReader(open(os.path.join(a.src, 'validated.tsv'), encoding='utf-8'),
                               delimiter='\t', quoting=csv.QUOTE_NONE))
    by = collections.defaultdict(list)
    for r in rows:
        by[r['client_id']].append(r['path'])
    rng = random.Random(22)
    speakers = sorted(by)
    rng.shuffle(speakers)
    sh, n_spk, kept = Shards(a.out, 64), 0, 0
    for spk in speakers:
        if sh.hours >= a.hours:
            break
        clips = by[spk][:]
        rng.shuffle(clips)
        got = 0.0
        for c in clips:
            if got >= a.minutes_per_speaker * 60:
                break
            try:
                x = pcm(open(os.path.join(a.src, 'clips', c), 'rb').read())
            except Exception:
                continue
            if not usable(x):
                continue
            sh.add(x); kept += 1; got += len(x) / SR
        n_spk += got > 0
    sh.flush()
    print(f'cv: {kept} clips from {n_spk} speakers (of {len(by)}), {sh.hours:.1f} h, {sh.n} shards')


def cv18(a):
    import pyarrow.parquet as pq
    from huggingface_hub import HfApi
    repo = 'MohamedRashad/common-voice-18-arabic'
    files = sorted(f for f in HfApi().list_repo_files(repo, repo_type='dataset')
                   if f.endswith('.parquet') and '/invalidated' not in f)
    paths = []
    for f in files:
        path = os.path.join(a.cache, os.path.basename(f))
        if not os.path.exists(path):
            subprocess.run(['curl', '-sfL', '--retry', '5', '-o', path + '.part',
                            f'https://huggingface.co/datasets/{repo}/resolve/main/{f}'], check=True)
            os.rename(path + '.part', path)
        paths.append(path)
    # Plan: every speaker's clips (file, row), speakers and clips in random order.
    by = collections.defaultdict(list)
    for fi, path in enumerate(paths):
        ids = pq.read_table(path, columns=['client_id']).column('client_id').to_pylist()
        for ri, spk in enumerate(ids):
            by[spk].append((fi, ri))
    rng = random.Random(22)
    speakers = sorted(by)
    rng.shuffle(speakers)
    # Up to ~2x the minutes per speaker planned (some clips are dropped), then cut when read.
    want = {}
    for spk in speakers:
        cl = by[spk][:]
        rng.shuffle(cl)
        for k, (fi, ri) in enumerate(cl[:max(1, int(a.minutes_per_speaker * 60 / 4.5 * 2))]):
            want[(fi, ri)] = spk
    order = {spk: i for i, spk in enumerate(speakers)}
    got = collections.Counter()
    picked = collections.defaultdict(list)          # speaker -> clips, read file by file
    for fi, path in enumerate(paths):
        pf = pq.ParquetFile(path)
        ri = 0
        for batch in pf.iter_batches(batch_size=256, columns=['audio']):
            for cell in batch.column('audio').to_pylist():
                spk = want.get((fi, ri))
                ri += 1
                if spk is None or got[spk] >= a.minutes_per_speaker * 60:
                    continue
                try:
                    x = pcm(cell['bytes'] if isinstance(cell, dict) else cell)
                except Exception:
                    continue
                if usable(x):
                    picked[spk].append(x); got[spk] += len(x) / SR
    sh, n_spk = Shards(a.out, 64), 0
    for spk in sorted(picked, key=order.get):        # random speaker order, until --hours
        if sh.hours >= a.hours:
            break
        n_spk += 1
        for x in picked[spk]:
            sh.add(x)
    sh.flush()
    print(f'cv18: {n_spk} speakers (of {len(by)}), {sh.hours:.1f} h, {sh.n} shards')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('source', choices=['fleurs', 'cv', 'cv18'])
    p.add_argument('out')
    p.add_argument('--splits', default='train,dev')
    p.add_argument('--src')
    p.add_argument('--minutes-per-speaker', type=float, default=3)
    p.add_argument('--hours', type=float, default=40)
    p.add_argument('--cache', default='/workspace/.cache_speech')
    a = p.parse_args()
    os.makedirs(a.cache, exist_ok=True)
    {'fleurs': fleurs, 'cv': cv, 'cv18': cv18}[a.source](a)


if __name__ == '__main__':
    main()
