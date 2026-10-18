"""Ghunnah length from the Quran-Lab MFA aligner (mfa-quran-hafs, Apache 2.0): per
recording, the target word's ghunnah phone (a doubled «ن+» / «م+», or a hidden «ں» /
«۾») and its duration in the reciter's own short vowels (median «َ ُ ِ» of the ayah:
one count each), against the owner's labels:

  python mfa_ghunnah.py   # artifacts/external/mfa_out (TextGrids), ghown + listening labels
"""
import collections, json, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, 'artifacts')
OUT = os.path.join(ART, 'external', 'mfa_out')


def tiers(path):
    """{'words': [(xmin, xmax, text)], 'phones': [...]} from a long-format TextGrid."""
    out, cur = {}, None
    xmin = xmax = None
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        m = re.match(r'name = "(.*)"', line)
        if m:
            cur = out.setdefault(m.group(1), [])
            continue
        m = re.match(r'xmin = ([\d.]+)', line)
        if m:
            xmin = float(m.group(1)); continue
        m = re.match(r'xmax = ([\d.]+)', line)
        if m:
            xmax = float(m.group(1)); continue
        m = re.match(r'text = "(.*)"', line)
        if m and cur is not None:
            cur.append((xmin, xmax, m.group(1)))
    return out


NASAL = {'ن+', 'م+', 'ں', '۾', 'ں+', '۾+'}
VOWELS = {'َ', 'ُ', 'ِ'}


def measure(name, word):
    t = tiers(os.path.join(OUT, f'{name}.TextGrid'))
    words = [w for w in t['words'] if w[2]]
    if word >= len(words):
        return None
    w0, w1, _ = words[word]
    phones = [p for p in t['phones'] if p[2]]
    vow = [b - a for a, b, s in phones if s in VOWELS]
    beat = statistics.median(vow) if vow else None
    nas = [(b - a, s) for a, b, s in phones if s in NASAL and a >= w0 - 0.02 and b <= w1 + 0.02]
    if not nas or not beat:
        return None
    d, s = max(nas)
    return {'dur': round(d, 3), 'phone': s, 'beat': round(beat, 3), 'counts': round(d / beat, 2)}


def main():
    rows = []
    for c in json.load(open(os.path.join(ART, 'ghown_cases.json'))):
        m = measure(f"own_{c['name']}", c['ghunnahWords'][0])
        rows.append(('owner session', 'held' if c['take'] == 'correct' else 'cut', c['name'], m))
    for x in json.load(open(os.path.join(ART, 'ghunnah_listen_labelled.json'))):
        m = measure(f"day_{x['pack']}_{x['clip']}", x['word'])
        rows.append(('everyday', {'correct': 'held', 'mistake': 'cut', 'unsure': 'unsure'}[x['label']], x['id'], m))
    for group in ('owner session', 'everyday'):
        print('==', group)
        by = collections.defaultdict(list)
        for g, lab, _, m in rows:
            if g == group and m:
                by[lab].append(m['counts'])
        for lab, v in by.items():
            v.sort()
            print(f'  {lab:6} n={len(v):2} counts: {v}')
        held, cut = by.get('held', []), by.get('cut', [])
        for t in (1.0, 1.2, 1.5, 2.0):
            if held and cut:
                print(f'  under {t}: cut caught {sum(x < t for x in cut)}/{len(cut)}, held flagged {sum(x < t for x in held)}/{len(held)}')
    json.dump(rows, open(os.path.join(ART, 'mfa_ghunnah_rows.json'), 'w'), ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
