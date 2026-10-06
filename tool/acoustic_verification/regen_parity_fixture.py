"""Recomputes the Python prototype's verdicts in the parity fixture
(test/fixtures/acoustic/alafasy_minimal_pairs.json), on its stored frames,
after a change to the shared algorithm (the Dart verifier must match them —
test/ai/acoustic/real_audio_parity_test.dart).

  python regen_parity_fixture.py [--check]   # --check: compare, don't write
"""
import base64, json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from acoustic import Aya, Thresholds, reference, unit_splits, unit_variants, verify_ayah  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
PATH = os.path.join(ROOT, 'test/fixtures/acoustic/alafasy_minimal_pairs.json')
data = json.load(open(PATH))
th = Thresholds()
worst = 0.0
for c in data['cases']:
    a = int(c['ayahId'])
    uth = Aya(a // 1000, a % 1000).get().uthmani
    toks = reference(uth)
    units = {t.unit for t in toks if int(c['firstWord']) <= t.word <= int(c['lastWord'])}
    sel = [t for t in toks if t.unit in units]
    var = {u: v for u, v in unit_variants(uth, toks).items() if u in units}
    lp = np.frombuffer(base64.b64decode(c['logProbs']), dtype=np.float32).reshape(-1, 43)
    spl = {u: v for u, v in unit_splits(uth, toks).items() if u in units}
    used, spans, verdicts = verify_ayah(lp, sel, var, th, open_start=bool(c['openStart']),
                                        open_end=bool(c['openEnd']), splits=spl)
    kinds = [v.kind for v in verdicts]
    llr = [round(float(v.llr), 4) for v in verdicts]
    if '--check' in sys.argv:
        same = kinds == c['verdicts']
        d = max((abs(x - y) for x, y in zip(llr, c['llr'])), default=0)
        worst = max(worst, d)
        print(c['name'], 'kinds same' if same else 'KINDS DIFFER', f'max llr diff {d:.4f}')
    c['verdicts'], c['llr'] = kinds, llr
    c['symbols'] = [v.token.sym for v in verdicts]
if '--check' not in sys.argv:
    json.dump(data, open(PATH, 'w'), ensure_ascii=False)
    print('written', len(data['cases']), 'cases')
else:
    print('worst llr diff', worst)
