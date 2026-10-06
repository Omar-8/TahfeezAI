"""QDAT (obadx/qdat, MIT; amateur recitations of 5:109 «قالوا لا علم لنا إنك
أنت علام الغيوب», words 8-15) -> a test pack in the bench format:
artifacts/qdat_cases.json + qdat_audio.npz. Every clip is a 'clean' case (the
letters and vowels are expected right); its category says whether the experts
heard all three rules applied (separate madd, shaddah on the nun, ikhfa):
qdat_rules_ok / qdat_rule_missed (qdat_unlabelled: no labels). Laptop-only test data (docs/THIRD_PARTY_RESOURCES.md).

  python qdat_pack.py
"""
import glob, io, json, os
import numpy as np, pyarrow.parquet as pq, soundfile as sf

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'artifacts')
cases, blobs, seen = [], {}, set()
for f in sorted(glob.glob(os.path.join(ART, 'external', 'obadx_qdat__data_train-*.parquet'))):
    for r in pq.read_table(f).to_pylist():
        key = r['original_id']
        if key in seen:  # the dataset's duplicated files
            continue
        seen.add(key)
        w, sr = sf.read(io.BytesIO(r['audio']['bytes']), dtype='float32')
        if w.ndim > 1:
            w = w.mean(1)
        assert sr == 16000, sr
        labels = [r[k] for k in ('separate_tide', 'the_tight_noon', 'concealment')]
        ok = None if None in labels else all(int(float(v)) == 1 for v in labels)
        blobs[f'c{len(cases)}'] = w.astype(np.float32)
        cases.append(dict(set='clean', kind='clean', name=f'qdat_{key}',
                          category={True: 'qdat_rules_ok', False: 'qdat_rule_missed',
                                    None: 'qdat_unlabelled'}[ok],
                          ayahId=5109, firstWord=7, lastWord=14, targetWords=[],
                          openStart=False, openEnd=False, screen=True,
                          reciter=key.split('_')[0], gender=r['gender'], age=r['age']))
json.dump(cases, open(os.path.join(ART, 'qdat_cases.json'), 'w'))
np.savez(os.path.join(ART, 'qdat_audio.npz'), **blobs)
ok = sum(c['category'] == 'qdat_rules_ok' for c in cases)
print(f'{len(cases)} clips ({ok} with all three rules applied), '
      f'{len({c["reciter"] for c in cases})} reciters')
