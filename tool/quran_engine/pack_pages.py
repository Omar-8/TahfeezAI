#!/usr/bin/env python3
"""Packs the Mushaf pages for the phones: every 4 pages (001-004, 005-008,
…: a two-page spread never split) as one xz file, in
assets/quran/quran_engine/page_groups/, with an index
(assets/quran/quran_engine/page_groups.json: each group's SHA-256 and its
pages' sizes).

Lossless: unpacked, each page is byte for byte its .qvp
(test/features/mushaf/data/quran_engine_page_groups_test.dart). The
phones carry these instead of the 604 .qvp files (~10 MB less download;
~49 MB less installed on the iPhone, which keeps app files uncompressed);
the web still serves the .qvp files. The app unpacks a group when it needs
one of its pages, and the next one ahead of time (QuranEnginePageGroups).

Run it whenever the pages change (tool/quran_engine/fetch_page_data.sh):
    python3 tool/quran_engine/pack_pages.py
"""
import hashlib
import json
import os
import shutil
import lzma

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
PAGES = os.path.join(ROOT, 'assets/quran/quran_engine/pages')
OUT = os.path.join(ROOT, 'assets/quran/quran_engine/page_groups')
INDEX = os.path.join(ROOT, 'assets/quran/quran_engine/page_groups.json')
GROUP = 4
COUNT = 604

if os.path.isdir(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT)
groups = []
for first in range(1, COUNT + 1, GROUP):
    numbers = range(first, min(first + GROUP, COUNT + 1))
    pages = [open(f'{PAGES}/{n:03d}.qvp', 'rb').read() for n in numbers]
    data = b''.join(pages)
    name = f'{first:03d}.xz'
    # The strongest preset, its dictionary no bigger than a group (what
    # unpacking needs in memory): ~1 MB.
    packed = lzma.compress(data, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC64,
                           filters=[{'id': lzma.FILTER_LZMA2,
                                     'preset': 9 | lzma.PRESET_EXTREME,
                                     'dict_size': 1 << 20}])
    open(f'{OUT}/{name}', 'wb').write(packed)
    groups.append({
        'asset': f'page_groups/{name}',
        'sha256': hashlib.sha256(data).hexdigest(),
        'pages': [len(p) for p in pages],
    })

json.dump({'groupSize': GROUP, 'pageCount': COUNT, 'groups': groups},
          open(INDEX, 'w'), indent=1)
open(INDEX, 'a').write('\n')
total = sum(os.path.getsize(f'{OUT}/{g["asset"].split("/")[-1]}') for g in groups)
print(f'{len(groups)} groups, {total / 1e6:.1f} MB')
