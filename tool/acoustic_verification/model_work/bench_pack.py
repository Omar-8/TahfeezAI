"""Pack the fixed benchmark audio (the same 744 clips every candidate is
scored on) into artifacts/bench_audio.npz, in the order of the case index
artifacts/bench_cases.json.

  cases: 240 spliced minimal-pair mistakes + their 240 unspliced controls
         (Alafasy), 264 clean ayahs (Alafasy, Husary, Karim Mansoori,
         Parhizgar). Built from the evaluation workspace given as argv[1].
  screen: a fixed subset (every third pair per category, the first 33
          ayahs of each reciter) for fast screening.
"""
import json, os, pickle, sys
import numpy as np
import soundfile as sf

WS = sys.argv[1]
sys.path.insert(0, WS)
os.chdir(WS)
import logp as L  # noqa: E402
from acoustic import Aya, align_with_waqf, reference  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'artifacts')
os.makedirs(OUT, exist_ok=True)
cases = json.load(open('eval_data.json'))
rows = {r['tag']: r for r in pickle.load(open('pair_results.pkl', 'rb'))}
_ref, _wav = {}, {}


def ref(s, a):
    if (s, a) not in _ref:
        _ref[(s, a)] = reference(Aya(s, a).get().uthmani)
    return _ref[(s, a)]


def wav(s, a):
    if (s, a) not in _wav:
        _wav[(s, a)] = L.load(f'alafasy/{s:03d}{a:03d}.mp3')
    return _wav[(s, a)]


def unit_bounds(s, a, lo, hi):
    toks = ref(s, a)
    lp = L.cached('mini', f'alafasy/{s:03d}{a:03d}.mp3')
    sp = align_with_waqf(lp, toks)
    fr = [sp[k] for k, t in enumerate(toks) if lo <= t.unit <= hi and sp[k]]
    bef = [sp[k][1] for k, t in enumerate(toks) if t.unit < lo and sp[k]]
    aft = [sp[k][0] for k, t in enumerate(toks) if t.unit > hi and sp[k]]
    b = bef[-1] + 1 if bef else 0
    e = aft[0] if aft else len(lp)
    return int((b + fr[0][0]) / 2 * 640), int((fr[-1][1] + 1 + e) / 2 * 640)


audio = {}
per_cat = {}
for i, c in enumerate(cases):
    if c['set'] == 'pairs':
        r = rows[c['name']]
        if c['kind'] == 'spliced':
            x, _ = sf.read(f'spliced/{c["name"]}.wav', dtype='float32')
        else:
            w0, w1 = unit_bounds(r['s'], r['a'], *r['units'])
            x = wav(r['s'], r['a'])[w0:w1]
        n = per_cat.setdefault(c['category'], {}).setdefault(c['name'], len(per_cat[c['category']]))
        c['screen'] = n % 3 == 0
    else:
        x = L.load(f'{c["category"]}/{c["name"]}.mp3')
        n = per_cat.setdefault(c['category'], {}).setdefault(c['name'], len(per_cat[c['category']]))
        c['screen'] = n < 33
    audio[f'c{i}'] = x.astype(np.float32)
    for k in ('main', 'shifted'):
        c.pop(k, None)
np.savez(os.path.join(OUT, 'bench_audio.npz'), **audio)
json.dump(cases, open(os.path.join(OUT, 'bench_cases.json'), 'w'))
secs = sum(len(v) for v in audio.values()) / 16000
print(f'{len(cases)} cases, {secs / 60:.1f} min audio; screening subset {sum(c["screen"] for c in cases)} cases')
