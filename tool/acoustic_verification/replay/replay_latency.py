"""How soon replayed sessions get their verdicts, and how often early marks
are withdrawn — before and after a change (session_replay_test.dart writes
<name>.latency.json, <name>.early.json and <name>.json per session):

  python3 tool/acoustic_verification/replay/replay_latency.py <before dir> <after dir>

Latency: from a word's end in the audio to its first verdict. "Sure": the
early marks that vibrate at once (wrong vowel llr >= 6, wrong letter >= 8).
Final verdicts that differ should be 0 for a pure timing change.
"""
import glob, json, statistics as st, sys


def load(d):
    lat, fin, early = [], {}, []
    for f in glob.glob(d + '/*.latency.json'):
        for w in json.load(open(f)):
            if w.get('judgedS') is not None:
                lat.append(w['judgedS'] - w['endS'])
    for f in glob.glob(d + '/*.json'):
        if f.endswith(('.latency.json', '.early.json')):
            continue
        j = json.load(open(f))
        fin[j['session']] = {w['word']: (w['type'], w['provisional']) for w in j['words']}
    for f in glob.glob(d + '/*.early.json'):
        early += json.load(open(f))
    return lat, fin, early


def q(a):
    a = sorted(a)
    return (f'median {st.median(a):.2f}s  p75 {a[3 * len(a) // 4]:.2f}  '
            f'p90 {a[9 * len(a) // 10]:.2f}  max {a[-1]:.1f}  n={len(a)}')


def sure(e):
    return any((x['type'] == 'wrongVowel' and x['llr'] >= 6) or
               (x['type'] == 'wrongLetter' and x['llr'] >= 8) for x in e['errors'])


runs = [load(d) for d in sys.argv[1:3]]
for name, (lat, _, early) in zip(('before', 'after'), runs):
    withdrawn = [e for e in early if e.get('confirmed') is False]
    print(f'{name}: word end -> verdict {q(lat)}')
    print(f'   early marks {len(early)}: confirmed {len(early) - len(withdrawn)}, '
          f'withdrawn {len(withdrawn)}; vibrating at once '
          f'{sum(1 for e in early if sure(e))}, withdrawn '
          f'{sum(1 for e in withdrawn if sure(e))}')
b, a = runs[0][1], runs[1][1]
finals = [(s, k, v) for s in a for k, v in a[s].items() if not v[1]]
diff = sum(1 for s, k, v in finals if b.get(s, {}).get(k, (None, False))[0] != v[0])
print(f'final verdicts that differ: {diff} of {len(finals)}')
