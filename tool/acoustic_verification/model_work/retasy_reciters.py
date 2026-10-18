"""Which reciter recited each RetaSy test case (retasy_data.py kept none): the same
selection as retasy_data.py, over the same parquet files, checked case by case against
artifacts/retasy_cases.json (ayah, words, category), for bootstrap.dart's
reciter-level resampling.

  python retasy_reciters.py <parquet dir>   # -> artifacts/retasy_case_reciters.json
"""
import glob, io, json, os, sys

import pandas as pd
import soundfile as sf
import numpy as np

import retasy_data as rd

ART = rd.ART


def main():
    match, _ = rd.matcher()
    cols = ['audio', 'Surah', 'Aya', 'final_label', 'reciter_id', 'reciter_gender']
    df = pd.concat([pd.read_parquet(f, columns=cols)
                    for f in sorted(glob.glob(os.path.join(sys.argv[1], '*.parquet')))])
    test = set(json.load(open(os.path.join(ART, 'retasy_split.json'))))
    cases = json.load(open(os.path.join(ART, 'retasy_cases.json')))
    out = []
    for r in df.itertuples(index=False):
        if r.final_label in rd.DROP or r.reciter_id not in test:
            continue
        m = match(r.Surah, r.Aya)
        if m is None:
            continue
        x, sr = sf.read(io.BytesIO(r.audio['bytes']), dtype='float32')
        if x.ndim > 1:
            x = x.mean(1)
        if sr != 16000 or len(x) < 8000 or not np.isfinite(x).all() or np.abs(x).max() < 1e-3:
            continue
        c = cases[len(out)]
        label = {'correct': 'correct', 'in_correct': 'incorrect'}.get(r.final_label, 'unlabelled')
        aid, w0, w1 = m
        assert (c['ayahId'], c['firstWord'], c['lastWord'], c['category']) == \
            (aid, w0, w1, f'retasy_{label}'), (len(out), c, m, label)
        out.append(str(r.reciter_id))
    assert len(out) == len(cases), (len(out), len(cases))
    json.dump(out, open(os.path.join(ART, 'retasy_case_reciters.json'), 'w'))
    print(len(out), 'cases,', len(set(out)), 'reciters')


if __name__ == '__main__':
    main()
