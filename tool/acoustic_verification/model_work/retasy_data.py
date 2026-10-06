"""Non-professional recitation (RetaSy Quranic Audio Dataset) -> an amateur test pack and
training shards.

  python retasy_data.py <parquet dir> [--test-share 0.3]

RetaSy (huggingface.co/datasets/RetaSy/quranic_audio_dataset): ~6,800 crowd-sourced
recitations by ~1,300 non-Arabic-speaking amateurs, recorded on their own devices; 911
labelled "correct" / "in_correct" (vowel marks, regardless of tajweed) by annotators.
Licence: not stated by the dataset (paper CC BY 4.0) — experimental use only, see
docs/THIRD_PARTY_RESOURCES.md.

Each clip's text is matched to its ayah (or part of one) by consonant skeleton within the
named surah; non-Quran clips (adhan, tashahhud, du'a), the isti'adha and clips the
annotators marked unrelated / another ayah / several ayahs / incomplete are dropped.
Reciters are split: [--test-share] of those with a labelled clip are held out entirely.

Writes
- artifacts/retasy_cases.json + retasy_audio.npz: the amateur test pack (evaluate.dart /
  bench_run.py --pack retasy), categories retasy_correct / retasy_incorrect /
  retasy_unlabelled, all "clean" (words flagged = the measure);
- artifacts/retasy_split.json: the held-out reciter ids;
- data_retasy/shard_95NN.npz: the other reciters' clips as training shards. A clip
  annotated "correct" reciting a whole ayah carries the expected Hafs pronunciation as
  its CTC target (so the student learns that an amateur's correct recitation is
  correct, beyond the teacher); every other clip is teacher-only (empty target).
"""
import argparse, collections, glob, io, json, os, random, re, unicodedata

import numpy as np
import pandas as pd
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
from build_calibration import ID, ref  # noqa: E402

SURAH = {'Al-Faatihah': 1, 'Al-Ikhlas': 112, 'An-Nas': 114, 'Ayat al-Kursi': 2,
         'Al-Kafiroon': 109, 'Al-Falaq': 113, 'Al-Kauthar': 108, 'Al-Asr': 103,
         'Al-Masad': 111, 'Al-Humazah': 104, 'An-Nasr': 110, 'Al-Qadr': 97, 'Al-Fil': 105,
         'Al-Maaoon': 107, 'Quraish': 106, 'Al-NABAA': 78, 'Ayat Ramadan': 2}
DROP = {'not_related_quran', 'multiple_aya', 'not_match_aya', 'in_complete'}


def skeleton(s):
    """Consonants only: spelling differences (alif, hamza seats, long vowels) vanish."""
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c))
    s = s.translate(str.maketrans({'ٱ': 'ا', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ی': 'ي',
                                   'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي', 'ٰ': 'ا'}))
    s = re.sub(r'[^ء-غف-ي]', '', s)
    return re.sub('[اويء]', '', s)


def matcher():
    words = json.load(open(os.path.join(ROOT, 'assets/quran/quran_dataset.json')))['ayahWords']
    ay = collections.defaultdict(list)
    for w in words:
        ay[w['ayahId']].append((w['wordIndex'], w['text']))
    sk = {a: [skeleton(t) for _, t in sorted(ws)] for a, ws in ay.items()}

    def match(surah, text):
        s, k = SURAH.get(surah), skeleton(text)
        if s is None or len(k) < 3:
            return None
        cands = [a for a in sk if a // 1000 == s]
        for a in cands:
            if ''.join(sk[a]) == k:
                return a, 0, len(sk[a]) - 1
        for a in cands:
            ws = sk[a]
            for i in range(len(ws)):
                for j in range(i, len(ws)):
                    if ''.join(ws[i:j + 1]) == k:
                        return a, i, j
        return None
    return match, sk


def target(aid):
    """The ayah's expected pronunciation, recited alone (stopping at its end)."""
    r = ref[str(aid)]
    toks = [ID[c] for c, f in zip(r['t'], r['f']) if not (ord(f) - 64) & 8]
    if (ord(r['f'][-1]) - 64) & 32:
        toks = toks[:-1]
    return toks


def main():
    p = argparse.ArgumentParser()
    p.add_argument('parquet_dir')
    p.add_argument('--test-share', type=float, default=0.3)
    p.add_argument('--seed', type=int, default=0)
    a = p.parse_args()
    match, sk = matcher()
    cols = ['audio', 'Surah', 'Aya', 'final_label', 'reciter_id', 'reciter_gender']
    df = pd.concat([pd.read_parquet(f, columns=cols)
                    for f in sorted(glob.glob(os.path.join(a.parquet_dir, '*.parquet')))])
    rows = []
    for r in df.itertuples(index=False):
        if r.final_label in DROP:
            continue
        m = match(r.Surah, r.Aya)
        if m is None:
            continue
        rows.append((r, m))
    labelled = sorted({r.reciter_id for r, _ in rows if r.final_label in ('correct', 'in_correct')})
    rng = random.Random(a.seed)
    rng.shuffle(labelled)
    test = set(labelled[:int(len(labelled) * a.test_share)])
    json.dump(sorted(test), open(os.path.join(ART, 'retasy_split.json'), 'w'))

    cases, blobs, shard, n_shard, stats = [], [], [], 0, collections.Counter()
    out_dir = os.path.join(HERE, 'data_retasy')
    os.makedirs(out_dir, exist_ok=True)

    def flush():
        nonlocal shard, n_shard
        if not shard:
            return
        np.savez(os.path.join(out_dir, f'shard_{9500 + n_shard:04d}.npz'),
                 audio=np.concatenate([x for x, _, _ in shard]).astype(np.int16),
                 offsets=np.cumsum([0] + [len(x) for x, _, _ in shard]),
                 targets=np.array([t for _, t, _ in shard] + [None], dtype=object)[:-1],
                 ayahs=np.array([aid for _, _, aid in shard], np.int32))
        n_shard += 1
        shard = []

    for r, (aid, w0, w1) in rows:
        x, sr = sf.read(io.BytesIO(r.audio['bytes']), dtype='float32')
        if x.ndim > 1:
            x = x.mean(1)
        if sr != 16000 or len(x) < 8000 or not np.isfinite(x).all() or np.abs(x).max() < 1e-3:
            stats['skipped audio'] += 1
            continue
        label = {'correct': 'correct', 'in_correct': 'incorrect'}.get(r.final_label, 'unlabelled')
        if r.reciter_id in test:
            cases.append(dict(set='clean', category=f'retasy_{label}', kind='clean',
                              name=f'retasy_{len(cases)}', ayahId=aid, firstWord=w0, lastWord=w1,
                              targetWords=[], openStart=False, openEnd=False, screen=True,
                              gender=r.reciter_gender))
            blobs.append(x)
            stats[f'test {label}'] += 1
        else:
            whole = w0 == 0 and w1 == len(sk[aid]) - 1
            t = target(aid) if label == 'correct' and whole else []
            shard.append(((np.clip(x, -1, 1) * 32767).astype(np.int16), t, aid))
            stats[f'train {label}{" +text" if t else ""}'] += 1
            stats['train seconds'] += len(x) / 16000
            if len(shard) >= 400:
                flush()
    flush()
    json.dump(cases, open(os.path.join(ART, 'retasy_cases.json'), 'w'))
    np.savez(os.path.join(ART, 'retasy_audio.npz'), **{f'c{i}': b for i, b in enumerate(blobs)})
    stats['train hours'] = round(stats.pop('train seconds') / 3600, 2)
    print(f'{len(test)} held-out reciters; {n_shard} training shards')
    for k, v in sorted(stats.items()):
        print(f'  {k}: {v}')


if __name__ == '__main__':
    main()
