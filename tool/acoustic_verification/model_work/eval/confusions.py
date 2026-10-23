"""confusions.py <tag> [<tag>...]: G-round letter confusion table — the owner's six phone sets,
Tarteel-200 and the unseen Juz 30 reciters together, false letter flags per pair at the app's
settings (threshold 3, similar letters +4, phone-weak pairs +2); the teacher (ft5: fp32 on the
owner's sets, 4-bit elsewhere) and v3.7 (g19a) first. Run from the repository root.
"""
import collections, re, subprocess, sys

OWNER = 'phone phone2 phone3 phone4 phone6 phone7'.split()
PAIRS = ['حه', 'ضد', 'قك', 'كق', 'ءي', 'ني', 'خف', 'ثت']


def counts(tag, packs):
    out = subprocess.run(['dart', 'run', 'tool/acoustic_verification/letter_confusions.dart', tag,
                          'v36+s4+w2', *packs, '--all'], capture_output=True, text=True).stdout
    c, total = collections.Counter(), 0
    for line in out.splitlines():
        m = re.match(r'^(\S) → (\S)\s+(\d+)x', line.strip())
        if m:
            c[m[1] + m[2]] += int(m[3])
        m = re.search(r'(\d+) heard as another letter', line)
        if m:
            total += int(m[1])
    return c, total


models = {'Teacher': [('tft5', OWNER), ('ft5q', ['tlog', 'juz30h'])],
          'v3.7': [('g19a', OWNER + ['tlog', 'juz30h'])]}
for t in sys.argv[1:]:
    models[t] = [(t, OWNER + ['tlog', 'juz30h'])]
table = {}
for label, parts in models.items():
    c, total = collections.Counter(), 0
    for tag, packs in parts:
        x, n = counts(tag, packs)
        c += x; total += n
    table[label] = (c, total)
print('| Confusion | ' + ' | '.join(table) + ' |')
print('|---|' + '---:|' * len(table))
for p in PAIRS:
    print(f'| {p[0]}→{p[1]} | ' + ' | '.join(str(table[l][0][p]) for l in table) + ' |')
print('| **All letters** | ' + ' | '.join(str(table[l][1]) for l in table) + ' |')
