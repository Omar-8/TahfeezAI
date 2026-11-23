#!/usr/bin/env python3
"""Builds assets/duas/hadith_duas.json.gz: the duas Tahfeez shows from Sahih
al-Bukhari and Sahih Muslim (owner, 2026-11-23), each in its Duas section —
the hadith's Arabic and its translations as fawazahmed0/hadith-api publishes
them (The Unlicense), pinned to one commit. Only the chosen hadiths are kept;
their text is not changed (ends trimmed).

  python3 tool/duas/build_hadith_duas.py [--cache DIR]

Downloads each book section the choice needs, in every language, from
jsDelivr (into --cache, default a temporary folder), and checks: every
chosen hadith found in Arabic and English, numbered as chosen.
"""
import argparse, gzip, hashlib, json, sys, tempfile, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/duas/hadith_duas.json.gz'
COMMIT = 'df57907be35291c91ad6a6691180e22ca9920784'
BASE = f'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@{COMMIT}/editions'

# The edition's language → the app's.
LANGS = {'eng': 'en', 'ben': 'bn', 'fra': 'fr', 'ind': 'id', 'rus': 'ru',
         'tam': 'ta', 'tur': 'tr', 'urd': 'ur'}

# (book, its section in the edition, the hadith's number — Bukhari's own,
# Muslim's ʿAbd al-Baqi numbering with its narration, as sunnah.com — and
# the Duas section it is shown in, and Tahfeez's own short title for its
# tile in English and Arabic — as Hisn al-Muslim's chapters have).
CHOSEN = [
    ('bukhari', 76, '5743', 'health',
     'Lord of mankind, remove the harm', 'اللهم رب الناس أذهب البأس'),
    ('bukhari', 76, '5742', 'health',
     "The Prophet's ruqyah", 'رقية رسول الله ﷺ'),
    ('bukhari', 75, '5671', 'health',
     'When harm comes down', 'عند نزول الضر'),
    ('muslim', 48, '2721.01', 'provision',
     'Guidance, piety, chastity and sufficiency', 'الهدى والتقى والعفاف والغنى'),
    ('muslim', 48, '2697.02', 'provision',
     'Forgive me, guide me, provide for me', 'اغفر لي وارحمني واهدني وارزقني'),
    ('muslim', 48, '2696', 'provision',
     'Taught to a Bedouin', 'كلمات علّمها النبي ﷺ أعرابيًا'),
    ('bukhari', 80, '6344', 'provision',
     'Blessing in wealth and children', 'البركة في المال والولد'),
    ('bukhari', 80, '6369', 'distress',
     'Refuge from worry and debt', 'الاستعاذة من الهم والدَّين'),
    ('bukhari', 80, '6346', 'distress',
     'In distress', 'دعاء الكرب'),
    ('bukhari', 80, '6347', 'distress',
     'Refuge from calamity and an evil end', 'الاستعاذة من جهد البلاء وسوء القضاء'),
    ('bukhari', 80, '6306', 'forgiveness',
     'Sayyid al-Istighfar', 'سيد الاستغفار'),
    ('bukhari', 80, '6326', 'forgiveness',
     "Abu Bakr's dua in prayer", 'دعاء أبي بكر في الصلاة'),
    ('bukhari', 80, '6398', 'forgiveness',
     'Forgive me all my faults', 'اغفر لي خطيئتي وجهلي'),
    ('muslim', 48, '2716.02', 'forgiveness',
     "Refuge from the evil of one's deeds", 'الاستعاذة من شر ما عملت'),
    ('muslim', 48, '2720', 'guidance',
     'Set right my religion and my world', 'أصلح لي ديني ودنياي'),
    ('muslim', 48, '2725.01', 'guidance',
     'Guide me and keep me straight', 'اللهم اهدني وسددني'),
    ('muslim', 48, '2722', 'guidance',
     'Grant my soul its piety', 'آتِ نفسي تقواها'),
    ('bukhari', 80, '6368', 'protection',
     'Refuge from sin, debt and trials', 'الاستعاذة من المأثم والمغرم والفتن'),
    ('muslim', 48, '2718', 'travel',
     'Setting out on a journey', 'دعاء الخروج في السفر'),
]


def fetch(cache, lang, book, section):
    path = cache / f'{lang}-{book}-{section}.json'
    if not path.exists():
        url = f'{BASE}/{lang}-{book}/sections/{section}.min.json'
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                path.write_bytes(r.read())
        except Exception as e:  # noqa: BLE001 — a language without the book
            print(f'  ({lang}-{book}-{section}: {e})')
            return {}
    return {str(h['arabicnumber']): h
            for h in json.loads(path.read_text())['hadiths']}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache')
    args = ap.parse_args()
    cache = Path(args.cache or tempfile.mkdtemp())
    cache.mkdir(parents=True, exist_ok=True)
    out = []
    for book, section, number, group, title_en, title_ar in CHOSEN:
        ar = fetch(cache, 'ara', book, section).get(number)
        en = fetch(cache, 'eng', book, section).get(number)
        if not ar or not en or not ar['text'].strip() or not en['text'].strip():
            sys.exit(f'{book} {number}: not found in Arabic and English')
        tr = {}
        for lang, code in LANGS.items():
            h = fetch(cache, lang, book, section).get(number)
            if h and h['text'].strip():
                tr[code] = h['text'].strip()
        out.append({'book': book, 'number': number, 'group': group,
                    'titleEn': title_en, 'titleAr': title_ar,
                    'ar': ar['text'].strip(), 'tr': tr})
    data = {
        'source': {
            'name': 'fawazahmed0/hadith-api',
            'url': 'https://github.com/fawazahmed0/hadith-api',
            'commit': COMMIT,
            'licence': 'The Unlicense',
        },
        'hadiths': out,
    }
    raw = json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    # mtime 0: the same bytes each build.
    with open(OUT, 'wb') as f:
        with gzip.GzipFile(fileobj=f, mode='wb', mtime=0) as g:
            g.write(raw)
    print(f'{len(out)} hadiths, {len(raw)} bytes of JSON, '
          f'{OUT.stat().st_size} gzipped')
    print('SHA-256', hashlib.sha256(OUT.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
