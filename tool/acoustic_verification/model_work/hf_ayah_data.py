"""More reciters and readers for distillation (v2.7): ayah-level Hugging Face datasets
written as training shards in distill_student.py's format, with EMPTY transcripts (the
teacher's probabilities are the target, as for diverse_data.py).

  python hf_ayah_data.py <out dir> --source qud|tadabur|iqra|tlog [--hours-per-reciter 0.6]
                         [--hours 40] [--part K --parts N] [--max-cost 0.6]

Sources (credited in docs/THIRD_PARTY_RESOURCES.md and the app's About page):
- qud: QUD-Technologies/quranic-universal-ayahs (CC BY 4.0), one config per recitation;
  Hafs only (hafs_an_asim/), one file per recitation, mujawwad and murattal.
- tadabur: FaisaI/tadabur (CC BY-NC 4.0), 600+ reciters, verse-level clips; a few files
  spread over the dataset, up to --hours-per-reciter each.
- iqra: IqraEval/Iqra_train (train split): read speech; only the rows whose text is a
  Quran ayah or part of one (matched by consonant skeleton) are kept.
- tlog: tarteel-ai/tlog (CC BY 4.0, gated: HF_TOKEN of an account that accepted its
  terms), the `clean` split: Tarteel app users reciting single ayahs on their own phones —
  the audio the students fail on (2026-10-20). The ayah from the file name
  (<surah>_<ayah>_<id>), else the label's skeleton; a share (--keep) of the rows of
  --files random files. Never the 200 clips of the `tlog` test pack (Quran-Lab's
  tlog_holdout, artifacts/tlog_cases.json).

Never used: the calibration and test reciters (Shuraym, Ghamdi (Saad), Shaatree, Maher,
Alafasy, Husary), any ayah in blocked_ayahs.json, clips outside 1-20 s, and clips the
teacher cannot align to the expected Hafs pronunciation (mean per-frame cost >
MAX_COST: another riwayah, wrong ayah, noise).
"""
import argparse, collections, glob, io, json, os, random, re, shutil, subprocess, unicodedata
import numpy as np
import torch
import torchaudio
from huggingface_hub import HfApi
import pyarrow.parquet as pq

import distill_student as ds
from diverse_data import teacher_frames

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_COST = 0.6
BASE = {'qud': 8000, 'tadabur': 8400, 'iqra': 8800, 'tlog': 7000}
REPO = {'qud': 'QUD-Technologies/quranic-universal-ayahs', 'tadabur': 'FaisaI/tadabur',
        'iqra': 'IqraEval/Iqra_train', 'tlog': 'tarteel-ai/tlog'}
QUD_EXCLUDED = ('maher_al_muaiqly', 'mahmoud_khalil_al_husary', 'mishary_rashid_al_afasy',
                'saad_al_ghamdi', 'saud_al_shuraim', 'abu_bakr_al_shatri')
TADABUR_EXCLUDED = {8, 9, 33, 63, 71, 179}   # sheikh_dict.json ids of the same reciters


def find(*names):
    for n in names:
        for d in (HERE, os.path.join(HERE, '..', '..', '..')):
            p = os.path.join(d, n)
            if os.path.exists(p):
                return p
    raise FileNotFoundError(names)


def download(repo, f, cache):
    """A dataset file via aria2c (8 connections; resumed and retried), else curl: the hub
    client's single-connection downloads stall or crawl on some machines."""
    path = os.path.join(cache, repo.replace('/', '--'), f)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        return path
    url = f'https://huggingface.co/datasets/{repo}/resolve/main/{f}'
    auth = ['-H', f'Authorization: Bearer {os.environ["HF_TOKEN"]}'] if os.environ.get('HF_TOKEN') else []
    for _ in range(30):
        if shutil.which('aria2c'):
            r = subprocess.run(['aria2c', '-q', '-x', '8', '-s', '8', '-c', '--max-tries=5',
                                '--lowest-speed-limit=50K', '--allow-overwrite=true', '--auto-file-renaming=false',
                                *[f'--header={h}' for h in auth[1::2]],
                                '-d', os.path.dirname(path), '-o', os.path.basename(path) + '.part', url])
        else:
            r = subprocess.run(['curl', '-sfL', '-C', '-', '--speed-limit', '200000', '--speed-time', '30',
                                *auth, '-o', path + '.part', url])
        if r.returncode == 0:
            os.rename(path + '.part', path)
            return path
    raise RuntimeError(f'download failed: {f}')


def decode(cell):
    """Audio cell ({bytes, path} or bytes) -> float32 16 kHz mono."""
    b = cell['bytes'] if isinstance(cell, dict) else cell
    pcm = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', '-', '-ar', '16000', '-ac', '1',
                          '-f', 's16le', '-'], input=b, check=True, capture_output=True).stdout
    return np.frombuffer(pcm, dtype='<i2').astype(np.float32) / 32767


def skeleton(s):
    """Consonants only (as retasy_data.py): spelling differences vanish."""
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.translate(str.maketrans({'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ی': 'ي',
                                   'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي', 'ٰ': 'ا'}))
    s = re.sub(r'[^ء-غف-ي]', '', s)
    return re.sub('[اويء]', '', s)


def span_index(max_words=40):
    """Skeleton of every run of up to [max_words] words of an ayah -> (aid, lo, hi)."""
    words = json.load(open(find('assets/quran/quran_dataset.json')))['ayahWords']
    ay = collections.defaultdict(list)
    for w in words:
        ay[w['ayahId']].append((w['wordIndex'], w['text']))
    out = {}
    for aid, ws in ay.items():
        sk = [skeleton(t) for _, t in sorted(ws)]
        for i in range(len(sk)):
            k = ''
            for j in range(i, min(len(sk), i + max_words)):
                k += sk[j]
                if len(k) >= 6:
                    out.setdefault(k, (aid, i, j))
    return out


class Fit:
    """The teacher's alignment cost of a clip against the expected pronunciation."""

    def __init__(self):
        self.ref = json.load(open(find('phonetic_reference_hafs.json')))['ayahs']
        self.t = ds.load_teacher()
        self.fe = getattr(self.t.processor, 'feature_extractor', self.t.processor)

    def tokens(self, aid, lo=None, hi=None):
        r = self.ref[str(aid)]
        n_words = ord(r['w'][-1]) - 47
        lo = 0 if lo is None else lo
        hi = n_words - 1 if hi is None else hi
        return [ds.ID[c] for c, w, f in zip(r['t'], r['w'], r['f'])
                if not (ord(f) - 64) & 8 and lo <= ord(w) - 48 <= hi]

    def cost(self, w, toks):
        lp = teacher_frames(self.t, self.fe, w)
        best = None
        for seq in (toks, toks[:-1]):          # with or without the final vowel (the stop)
            if not seq or len(seq) * 2 >= lp.shape[0]:
                continue
            try:
                labels, _ = torchaudio.functional.forced_align(
                    lp[None], torch.tensor([seq], device=lp.device), blank=0)
            except Exception:
                continue
            path = labels[0]
            on = path != 0
            if not on.any():
                continue
            c = float((lp.max(-1).values - lp.gather(1, path[:, None])[:, 0])[on].mean())
            best = c if best is None else min(best, c)
        return best


def qud_rows(a, rng):
    api = HfApi()
    files = [f for f in api.list_repo_files(REPO['qud'], repo_type='dataset')
             if f.startswith('hafs_an_asim/') and f.endswith('.parquet')]
    by = collections.defaultdict(list)
    for f in files:
        by[os.path.basename(f).rsplit('-', 3)[0]].append(f)
    names = sorted(n for n in by if not n.startswith(QUD_EXCLUDED))[a.part::a.parts]
    for name in names:
        f = rng.choice(sorted(by[name]))
        path = download(REPO['qud'], f, a.cache)
        for batch in pq.ParquetFile(path).iter_batches(batch_size=64, columns=['audio', 'surah', 'ayah']):
            for row in batch.to_pylist():
                if rng.random() > a.keep:
                    continue
                yield name, row['surah'] * 1000 + row['ayah'], None, None, row['audio']
        os.remove(path)


def tadabur_rows(a, rng):
    api = HfApi()
    files = sorted(f for f in api.list_repo_files(REPO['tadabur'], repo_type='dataset')
                   if f.startswith('data/train-') and f.endswith('.parquet'))
    pick = sorted(rng.sample(files, a.files))[a.part::a.parts]
    for f in pick:
        path = download(REPO['tadabur'], f, a.cache)
        pf = pq.ParquetFile(path)
        cols = [c for c in ('audio', 'reciter_id', 'surah_id', 'ayah_id') if c in pf.schema_arrow.names]
        for batch in pf.iter_batches(batch_size=64, columns=cols):
            for row in batch.to_pylist():
                if row['reciter_id'] in TADABUR_EXCLUDED:
                    continue
                # surah_id counts from 0 ("وَٱلْفَجْرِ" is surah_id 88)
                yield f'tadabur_{row["reciter_id"]}', (row['surah_id'] + 1) * 1000 + row['ayah_id'], None, None, row['audio']
        os.remove(path)


def iqra_rows(a, rng):
    spans = span_index()
    api = HfApi()
    files = sorted(f for f in api.list_repo_files(REPO['iqra'], repo_type='dataset')
                   if f.startswith('data/train-') and f.endswith('.parquet'))[a.part::a.parts]
    for f in files:
        path = download(REPO['iqra'], f, a.cache)
        for batch in pq.ParquetFile(path).iter_batches(batch_size=64, columns=['audio', 'tashkeel_sentence', 'sentence']):
            for row in batch.to_pylist():
                hit = spans.get(skeleton(row['tashkeel_sentence'] or row['sentence'] or ''))
                if hit:
                    aid, lo, hi = hit
                    yield 'iqra', aid, lo, hi, row['audio']
        os.remove(path)


def tlog_held_out():
    """The `tlog` test pack's clips (<surah>_<ayah>_<id>): never trained on."""
    try:
        cases = json.load(open(find('artifacts/tlog_cases.json',
                                    'tool/acoustic_verification/model_work/artifacts/tlog_cases.json')))
    except FileNotFoundError:
        return set(json.load(open(find('tlog_held_out.json'))))
    return {re.search(r'\d+_\d+_\d+', c.get('reciter') or c['name']).group(0) for c in cases}


def tlog_rows(a, rng):
    held = tlog_held_out()
    assert len(held) >= 200, 'the tlog test clips must be known before sampling TLOG'
    spans = span_index()
    api = HfApi()
    files = sorted(f for f in api.list_repo_files(REPO['tlog'], repo_type='dataset')
                   if f.endswith('.parquet') and 'unclean' not in f)
    pick = sorted(rng.sample(files, min(a.files, len(files))))[a.part::a.parts]
    for f in pick:
        path = download(REPO['tlog'], f, a.cache)
        pf = pq.ParquetFile(path)
        cols = [c for c in ('audio', 'label', 'sentence') if c in pf.schema_arrow.names]
        for batch in pf.iter_batches(batch_size=64, columns=cols):
            for row in batch.to_pylist():
                if rng.random() > a.keep:
                    continue
                cell = row['audio']
                name = os.path.basename((cell.get('path') if isinstance(cell, dict) else '') or '')
                m = re.search(r'(\d+)_(\d+)_(\d+)', name)
                if m and m.group(0) in held:
                    continue
                if m and 1 <= int(m.group(1)) <= 114:
                    yield 'tlog', int(m.group(1)) * 1000 + int(m.group(2)), None, None, cell
                    continue
                hit = spans.get(skeleton(str(row.get('label') or row.get('sentence') or '')))
                if hit:
                    aid, lo, hi = hit
                    yield 'tlog', aid, lo, hi, cell
        os.remove(path)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('out')
    p.add_argument('--source', choices=sorted(BASE), required=True)
    p.add_argument('--hours', type=float, default=40, help='total for this part')
    p.add_argument('--hours-per-reciter', type=float, default=0.6)
    p.add_argument('--files', type=int, default=24, help='tadabur / tlog: files sampled')
    p.add_argument('--max-cost', type=float, default=MAX_COST,
                   help='teacher fit: clips costing more per frame are dropped (tlog: phone '
                        'audio of learners fits less tidily than a reciter\'s)')
    p.add_argument('--keep', type=float, default=0.4,
                   help='qud / tlog: share of a file\'s rows considered (spreads the clips over the file)')
    p.add_argument('--part', type=int, default=0)
    p.add_argument('--parts', type=int, default=1)
    p.add_argument('--shard-clips', type=int, default=2000)
    p.add_argument('--cache', default='/workspace/.hf_parquet')
    a = p.parse_args()
    assert a.parts <= 4
    os.makedirs(a.out, exist_ok=True)
    blocked = {s * 1000 + o for s, o in json.load(open(find('blocked_ayahs.json')))}
    fit = Fit()
    rng = random.Random(a.part)
    rows = {'qud': qud_rows, 'tadabur': tadabur_rows, 'iqra': iqra_rows,
            'tlog': tlog_rows}[a.source](a, rng)
    shard, n_shard = [], 0
    stats = collections.defaultdict(lambda: collections.Counter())
    hours = collections.Counter()
    log = open(os.path.join(a.out, f'{a.source}_{a.part}.log'), 'a')

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        np.savez(os.path.join(a.out, f'shard_{BASE[a.source] + 100 * a.part + n_shard:04d}.npz'),
                 audio=np.concatenate([x for x, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _ in shard]),
                 targets=np.array([[] for _ in shard] + [None], dtype=object)[:-1],
                 ayahs=np.array([aid for _, aid in shard], np.int32))
        n_shard += 1; shard = []

    total, last = 0.0, None
    for who, aid, lo, hi, cell in rows:
        if total >= a.hours * 3600:
            break
        if who != last and last is not None and a.source == 'qud':     # tadabur is shuffled
            print(last, dict(stats[last]), round(hours[last] / 3600, 2), 'h', flush=True)
            log.write(f'{last} {dict(stats[last])} {hours[last] / 3600:.2f} h\n'); log.flush()
        last = who
        st = stats[who]
        if hours[who] >= a.hours_per_reciter * 3600:
            st['cap'] += 1; continue
        if aid in blocked:
            st['blocked'] += 1; continue
        if str(aid) not in fit.ref:
            st['unknown'] += 1; continue
        try:
            w = decode(cell)
        except Exception:
            st['decode'] += 1; continue
        if not 1 <= len(w) / 16000 <= 20:
            st['length'] += 1; continue
        c = fit.cost(w, fit.tokens(aid, lo, hi))
        if c is None or c > a.max_cost:
            st['poor fit'] += 1; continue
        st['kept'] += 1
        shard.append(((np.clip(w, -1, 1) * 32767).astype(np.int16), aid))
        hours[who] += len(w) / 16000; total += len(w) / 16000
        if len(shard) == a.shard_clips:
            flush()
    if last is not None and a.source == 'qud':
        log.write(f'{last} {dict(stats[last])} {hours[last] / 3600:.2f} h\n')
    flush()
    log.write(f'{a.source} {sum(stats.values(), collections.Counter())} {total / 3600:.2f} h, {len(hours)} speakers\n')
    json.dump({k: dict(v, hours=round(hours[k] / 3600, 2)) for k, v in stats.items()},
              open(os.path.join(a.out, f'{a.source}_stats_{a.part}.json'), 'w'), indent=1)
    print('done', a.source, a.part, round(total / 3600, 2), 'h', n_shard, 'shards')


if __name__ == '__main__':
    main()
