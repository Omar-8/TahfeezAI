"""Country names in each of Tahfeez's languages, for the place shown with
prayer times ("Cairo, Egypt"): CLDR's territory names (Unicode License v3),
read through the Babel package installed locally — only the countries the
bundled city list has.

    python3 tool/quran_data/build_country_names.py

Writes assets/qibla/country_names.json.gz: {"v": 1, "babel": "...",
"names": {"<language>": {"EG": "Egypt", ...}}}.
"""
import gzip
import json
from pathlib import Path

import babel
from babel import Locale

ROOT = Path(__file__).resolve().parents[2]
L10N = ROOT / 'lib/core/localization/l10n'
CITIES = ROOT / 'assets/qibla/cities.json.gz'
OUT = ROOT / 'assets/qibla/country_names.json.gz'
# Tahfeez's language codes where CLDR's differ.
CLDR = {'zh': 'zh_Hans', 'uz': 'uz_Latn'}

cities = json.loads(gzip.decompress(CITIES.read_bytes()))['cities']
codes = sorted({row[1] for row in cities})
names = {}
for arb in sorted(L10N.glob('app_*.arb')):
    lang = arb.stem.removeprefix('app_')
    loc = Locale.parse(CLDR.get(lang, lang))
    t = loc.territories
    missing = [c for c in codes if c not in t]
    names[lang] = {c: t[c] for c in codes if c in t}
    if missing:
        print(lang, 'missing', missing)
data = {
    'v': 1,
    'babel': babel.__version__,
    'names': names,
}
raw = json.dumps(data, ensure_ascii=False, separators=(',', ':'), sort_keys=True)
OUT.write_bytes(gzip.compress(raw.encode('utf-8'), mtime=0))
print(len(codes), 'countries,', len(names), 'languages,', OUT.stat().st_size, 'bytes')
