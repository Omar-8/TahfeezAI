#!/usr/bin/env python3
"""Builds an interface translation (lib/core/localization/l10n/app_<code>.arb)
from tool/l10n/src/<code>.txt: one line per string, `key = text`, in any order
(`\\n` in the text is a line break). Checked against the English template:
every key present, no unknown key, each string's {placeholders} and plural /
select forms the same as the English one's.

  python3 tool/l10n/build_arb.py <code> [<code> ...]
"""
import json, re, sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
L10N = ROOT / 'lib/core/localization/l10n'
SRC = Path(__file__).resolve().parent / 'src'

en = json.load(open(L10N / 'app_en.arb'), object_pairs_hook=OrderedDict)
keys = [k for k in en if not k.startswith('@')]


def shape(text):
    """Its placeholders, and the ICU forms (plural / select) and their cases."""
    names = set(re.findall(r'\{(\w+)\}', text))
    icu = re.findall(r'\{(\w+), (plural|select),', text)
    cases = sorted(re.findall(r'(=\d+|zero|one|two|few|many|other)\{', text))
    names |= {n for n, _ in icu}
    return names, sorted(icu), cases


for code in sys.argv[1:]:
    lines = (SRC / f'{code}.txt').read_text(encoding='utf-8').splitlines()
    got = {}
    for n, line in enumerate(lines, 1):
        if not line.strip() or line.startswith('#'):
            continue
        key, sep, text = line.partition(' = ')
        if not sep:
            sys.exit(f'{code}.txt:{n}: no " = "')
        if key in got:
            sys.exit(f'{code}.txt:{n}: {key} twice')
        got[key] = text.replace('\\n', '\n')
    errors = [f'missing {k}' for k in keys if k not in got]
    errors += [f'unknown {k}' for k in got if k not in en]
    for k in keys:
        if k not in got:
            continue
        e_names, e_icu, e_cases = shape(en[k])
        names, icu, cases = shape(got[k])
        if e_names != names or e_icu != icu:
            errors.append(f'{k}: placeholders {sorted(names)} / {icu}, English {sorted(e_names)} / {e_icu}')
        # A language may need more plural cases than English, never fewer.
        if e_icu and not set(e_cases) >= {'other'} & set(cases) | {'other'}:
            errors.append(f'{k}: plural cases {cases}')
    if errors:
        sys.exit(f'{code}: ' + '\n  '.join(errors))
    out = OrderedDict([('@@locale', code)])
    for k in keys:
        out[k] = got[k]
    (L10N / f'app_{code}.arb').write_text(
        json.dumps(out, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{code}: {len(keys)} strings')
