#!/usr/bin/env python3
"""Builds the Qibla finder's city list (assets/qibla/cities.json.gz) from
GeoNames' cities15000 (https://download.geonames.org/export/dump/, CC BY 4.0
— credited in About and docs/THIRD_PARTY_RESOURCES.md): every city of
50,000 people or more, for choosing a place by hand instead of sharing the
phone's location.

Kept per city: its name, its country (ISO code, shown as a flag), its
coordinates (4 decimals, ~10 m), and the other names GeoNames lists for it
in the scripts of the app's languages (Arabic, Devanagari, Tamil, Malayalam,
Bengali, Cyrillic, Greek, Chinese, Japanese, Korean) plus its plain ASCII
name, so it can be found in the user's own script. Nothing else (no
populations, no codes beyond the country).

  python3 tool/quran_data/build_cities.py

Input: tool/quran_data/.cache/geonames/cities15000.txt (SHA-256 of the zip
checked below). Output: {"version": 1, "source": ..., "cities": [[name,
country, lat, lon, "other|names"], ...]}, the largest cities first.
"""
import gzip
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / 'tool/quran_data/.cache/geonames'
ZIP_SHA256 = '4284a894b649ab01147957aa22aa9df4a63b4e5c20e7a75b63ad95649a095b56'
OUT = ROOT / 'assets/qibla/cities.json.gz'
MIN_POPULATION = 50000

# The scripts a city's other names are kept in — one name each (the first
# GeoNames lists), besides its own name and its plain ASCII one.
SCRIPTS = [
    re.compile('[\u0600-\u06FF]'),  # Arabic (Urdu, Persian, Pashto, Kurdish)
    re.compile('[\u0900-\u097F]'),  # Devanagari (Hindi)
    re.compile('[\u0B80-\u0BFF]'),  # Tamil
    re.compile('[\u0D00-\u0D7F]'),  # Malayalam
    re.compile('[\u0980-\u09FF]'),  # Bengali
    re.compile('[\u0400-\u04FF]'),  # Cyrillic (Russian, Kazakh)
    re.compile('[\u0370-\u03FF]'),  # Greek
    re.compile('[\u4E00-\u9FFF]'),  # Chinese
    re.compile('[\u3040-\u30FF]'),  # Japanese kana
    re.compile('[\uAC00-\uD7AF]'),  # Korean
]


def main() -> None:
    digest = hashlib.sha256((CACHE / 'cities15000.zip').read_bytes()).hexdigest()
    if digest != ZIP_SHA256:
        sys.exit(f'cities15000.zip: SHA-256 {digest}, expected {ZIP_SHA256}')
    rows = []
    for line in (CACHE / 'cities15000.txt').read_text(encoding='utf-8').splitlines():
        f = line.split('\t')
        if len(f) < 15:
            continue
        population = int(f[14] or 0)
        if population < MIN_POPULATION:
            continue
        name, ascii_name, alternates = f[1], f[2], f[3]
        lat, lon, country = float(f[4]), float(f[5]), f[8]
        if not (-90 <= lat <= 90 and -180 <= lon <= 180) or len(country) != 2:
            sys.exit(f'bad row: {line[:80]}')
        others = [ascii_name] if ascii_name != name else []
        alts = [a.strip() for a in alternates.split(',') if a.strip()]
        for script in SCRIPTS:
            found = next((a for a in alts if script.search(a)), None)
            if found and found not in others:
                others.append(found)
        rows.append((population, [name, country, round(lat, 4), round(lon, 4),
                                  '|'.join(others)]))
    rows.sort(key=lambda r: -r[0])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    raw = json.dumps({
        'version': 1,
        'source': 'GeoNames cities15000 (CC BY 4.0), 50,000+ people',
        'sha256': ZIP_SHA256,
        'cities': [r[1] for r in rows],
    }, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    # Gzipped (no name, no time: the same bytes each build); the app
    # unzips it as it reads it (city_asset_*.dart).
    OUT.write_bytes(gzip.compress(raw, compresslevel=9, mtime=0))
    print(f'{OUT.relative_to(ROOT)}: {len(rows)} cities, {len(raw)} bytes, {OUT.stat().st_size} gzipped')


if __name__ == '__main__':
    main()
