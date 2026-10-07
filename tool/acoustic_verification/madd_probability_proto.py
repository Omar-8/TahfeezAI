# Prototype (v3 phase 2): a madd's length from how long its sound keeps coming back
# (probability >= floor, gaps <= gap frames), not from its last full CTC spike. A
# streaming model fires fewer spikes in a long madd but still hears it.
#   .venv/bin/python3 madd_probability_proto.py <tag>...   (QDAT «لَنَآ» separate madd)
import json, sys, numpy as np, collections
sys.path.insert(0, '.')
import acoustic as A
R = 'model_work/artifacts/results'
words = json.load(open('../../assets/quran/quran_dataset.json'))['ayahWords']
w5109 = {w['wordIndex']: w['text'] for w in words if w['ayahId'] == 5109}
labels = json.load(open('model_work/artifacts/qdat_labels.json'))
cache = {}
def toks(a, b):
    if (a, b) not in cache:
        t = A.reference(' '.join(w5109[i] for i in range(a, b + 1)))
        for x in t: x.word += a
        cache[(a, b)] = t
    return cache[(a, b)]

def held(lp, tk, spans, k, floor, gap_max):
    """A long sound's frames: its span, extended while the sound keeps coming back
    (probability >= floor) with no more than gap_max frames between, up to the next
    sound's span."""
    s, e = spans[k]
    nxt = next((spans[i][0] for i in range(k + 1, len(tk)) if spans[i]), len(lp))
    lab, last, gap = tk[k].label, e, 0
    for f in range(e + 1, nxt):
        if np.exp(lp[f, lab]) >= floor:
            last, gap = f, 0
        else:
            gap += 1
            if gap > gap_max: break
    return last - s + 1

def beat(lp, tk, spans, floor, gap_max):
    def before_vowel(k):
        return any(u.kind == 'vowel' for u in tk[k + 1:] if u.unit == tk[k].unit) if True else False
    halves = sorted(held(lp, tk, spans, k, floor, gap_max) / 2 for k, t in enumerate(tk)
                    if t.kind == 'long' and t.count == 2 and spans[k] and A._plain_of_hidden(t) is None
                    and any(u.kind == 'vowel' for u in tk[k + 1:] if u.unit == t.unit))
    if len(halves) < 2: return None
    m = len(halves) // 2
    return halves[m] if len(halves) % 2 else (halves[m - 1] + halves[m]) / 2

for tag in sys.argv[1:]:
    cases = json.load(open(f'{R}/qdat_{tag}.json')); f32 = np.fromfile(f'{R}/qdat_{tag}.f32', dtype=np.float32)
    data = []
    for c in cases:
        lab = labels.get(c['name'], {}).get('separate_tide')
        if lab is None: continue
        m = c['main']; lp = f32[m['offset']:m['offset'] + m['frames'] * 43].reshape(-1, 43)
        tk = toks(c['firstWord'], c['lastWord']); spans = A.align(lp, tk)[0]
        k = next(i for i, t in enumerate(tk) if t.word == 10 and t.kind == 'long' and t.count >= 4)
        if spans[k]: data.append((lab, lp, tk, spans, k))
    for floor, gap, share in ((0.15, 3, 0.65), (0.15, 3, 0.7), (0.15, 3, 0.75), (0.15, 3, 0.8)):
        res = collections.Counter(); n = collections.Counter()
        for lab, lp, tk, spans, k in data:
            if floor is None:
                b = A._beat(tk, spans); fr = spans[k][1] - spans[k][0] + 1
            else:
                b = beat(lp, tk, spans, floor, gap); fr = held(lp, tk, spans, k, floor, gap)
            if not b: continue
            key = 'applied' if lab == 1 else 'missed'
            n[key] += 1; res[key] += fr / b < share * tk[k].count
        print(f'{tag} share {share} correct madd flagged {res["applied"]/n["applied"]*100:4.1f}%   short madd caught {res["missed"]/n["missed"]*100:4.1f}%')
