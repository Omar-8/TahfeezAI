#!/usr/bin/env python3
"""Builds assets/quran/surah_aims.json: each surah's aims (مقاصد السورة) as
Al-Mukhtasar fi Tafsir al-Qur'an al-Karim gives them — the Arabic original
and its translations — from two places:

- QuranEnc.com's pages of that tafsir (the aims are on its pages only: not
  in its API nor its sqlite exports): the 12 languages in EDITIONS;
- the Tafsir Center's own Al-Mukhtasar API (mokhtasr.com/en/api-doc,
  `mobile-updated-data`: every edition's surah introductions), for the
  languages QuranEnc has no pages of: those in API_BOOKS. It needs the
  app's token (registered by the owner, 2026-11-13) once:

      MOKHTASAR_TOKEN=… python3 tool/quran_data/build_surah_aims.py

Verbatim: nothing is reworded (no modification, with attribution). Each
language must have all 114 surahs, non-empty; the Arabic shown beside
every QuranEnc translation must be the Arabic edition's own.

What is fetched is kept in tool/quran_data/.cache/surah_aims/ (each page's
aims block; the API's introductions), so a second run fetches nothing and
needs no token.

Then, where the Tafsir Center publishes none (owner's request,
2026-11-14): Tahfeez AI's own translations of the English edition's aims,
tool/quran_data/surah_aims_tahfeez/<language>.txt — one line per surah,
line N for surah N; a blank line where the language already has the
edition's own (Korean's 1 and 36–114). Listed under "translated" in the
output, so the app says "Translated by Tahfeez AI" under them. Never in
place of an edition's own text.
"""
import concurrent.futures
import hashlib
import html
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, 'tool/quran_data/.cache/surah_aims')
OUT = os.path.join(ROOT, 'assets/quran/surah_aims.json')

# The app's language -> QuranEnc's Al-Mukhtasar edition. (English and
# Russian have no pages on the site — only the API, which has no aims.)
EDITIONS = {
    'ar': 'arabic_mokhtasar',
    'fr': 'french_mokhtasar',
    'tr': 'turkish_mokhtasar',
    'id': 'indonesian_mokhtasar',
    'es': 'spanish_mokhtasar',
    'fa': 'persian_mokhtasar',
    'bn': 'bengali_mokhtasar',
    'ckb': 'kurdish_mokhtasar',
    'ps': 'pashto_mokhtasar',
    'uz': 'uzbek_mokhtasar',
    'ja': 'japanese_mokhtasar',
    'zh': 'chinese_mokhtasar',
}

# The app's language -> the Al-Mukhtasar API's book (edition) id.
API_BOOKS = {
    'en': 319,
    'ru': 321,
    'de': 336,
    'ur': 333,
    'pt': 338,
    'ha': 332,
    'sw': 328,
    'ko': 344,
}

# Editions without the aims of some surahs (their introductions' headings
# left empty): kept, the missing ones stored empty — the app shows no aims
# for those surahs. (Korean: 34 surahs, 2026-11-13; owner: add it.)
PARTIAL = {'ko'}
API = 'https://admin.mokhtasr.com/api/v1'
TRANSLATED = os.path.join(ROOT, 'tool/quran_data/surah_aims_tahfeez')
PBUH = 'صلى الله عليه وسلم'
API_CACHE = os.path.join(CACHE, 'mokhtasr_surah_intro.json')
HEADING = re.compile(r'<strong[^>]*>.*?</strong>', re.S)

BLOCK = re.compile(
    r'<div class="alert border[^"]*">\s*<div class="my-2"><b>.*?</b></div>'
    r'(.*?)<a class="btn[^"]*note_mokhtasar"',
    re.S,
)
ARABIC = re.compile(r'<div class="rtl text-info">(.*?)</div>', re.S)
SPAN = re.compile(r'<div class="aligner">\s*<span>(.*?)</span>', re.S)


def clean(fragment):
    text = html.unescape(re.sub(r'<[^>]+>', '', fragment))
    return re.sub(r'\s+', ' ', text).strip()


def block(edition, surah):
    """The aims block of [surah]'s page (cached)."""
    path = os.path.join(CACHE, f'{edition}_{surah:03d}.html')
    if os.path.exists(path):
        return open(path, encoding='utf8').read()
    url = f'https://quranenc.com/en/browse/{edition}/{surah}'
    for attempt in range(4):
        try:
            request = urllib.request.Request(
                url, headers={'User-Agent': 'Mozilla/5.0 (data build)'}
            )
            page = urllib.request.urlopen(request, timeout=60).read()
            break
        except Exception as error:  # noqa: BLE001 - retried, then raised
            if attempt == 3:
                raise RuntimeError(f'{url}: {error}') from error
            time.sleep(5 * (attempt + 1))
    found = BLOCK.search(page.decode('utf8', 'ignore'))
    if not found:
        raise RuntimeError(f'{url}: no aims block')
    with open(path, 'w', encoding='utf8') as file:
        file.write(found.group(0))
    time.sleep(0.5)  # gently
    return found.group(0)


def aims(edition, surah):
    """(the Arabic beside it or None, the edition's own text)."""
    text = block(edition, surah)
    arabic = ARABIC.search(text)
    own = SPAN.search(text)
    if not own:
        raise RuntimeError(f'{edition} {surah}: no text')
    return (clean(arabic.group(1)) if arabic else None, clean(own.group(1)))


def api_intros():
    """book id -> surah -> its introduction (HTML), from the API (cached)."""
    if not os.path.exists(API_CACHE):
        token = os.environ.get('MOKHTASAR_TOKEN')
        if not token:
            sys.exit('MOKHTASAR_TOKEN is needed to fetch the API editions '
                     '(or its cache, ' + API_CACHE + ')')
        books = ','.join(str(b) for b in API_BOOKS.values())
        request = urllib.request.Request(
            f'{API}/mobile-updated-data?book={books}&date=2015-01-01',
            headers={
                'Authorization': f'Bearer {token}',
                'Accept': 'application/json',
                'User-Agent': 'Mozilla/5.0 (data build)',
            },
        )
        data = json.load(urllib.request.urlopen(request, timeout=300))
        wanted = set(API_BOOKS.values())
        rows = [
            {k: r[k] for k in ('book_id', 'surah_id', 'content')}
            for r in data['surah_intro']
            if r['book_id'] in wanted
        ]
        with open(API_CACHE, 'w', encoding='utf8') as file:
            json.dump({'surah_intro': rows}, file, ensure_ascii=False)
    intros = {}
    for row in json.load(open(API_CACHE, encoding='utf8'))['surah_intro']:
        intros.setdefault(row['book_id'], {})[row['surah_id']] = row['content']
    return intros


def api_aims(content, where):
    """The aims in a surah's introduction: what is between its two
    headings ("Surah Objective(s):" … "Explanation:")."""
    parts = HEADING.split(content)
    if len(parts) != 3:
        sys.exit(f'{where}: {len(parts) - 1} headings, not 2')
    return clean(parts[1])


def main():
    os.makedirs(CACHE, exist_ok=True)
    jobs = [(e, s) for e in EDITIONS.values() for s in range(1, 115)]
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        results = dict(zip(jobs, pool.map(lambda j: aims(*j), jobs)))
    languages = {}
    for language, edition in EDITIONS.items():
        texts = [results[(edition, s)][1] for s in range(1, 115)]
        empty = [s for s, t in enumerate(texts, 1) if not t]
        if empty:
            sys.exit(f'{edition}: empty for surahs {empty}')
        languages[language] = texts
    # The Arabic beside each translation: the Arabic edition's own.
    for language, edition in EDITIONS.items():
        if language == 'ar':
            continue
        for s in range(1, 115):
            beside = results[(edition, s)][0]
            if beside is not None and beside != languages['ar'][s - 1]:
                sys.exit(f'{edition} {s}: its Arabic differs from the original')
    # The languages QuranEnc has no pages of: the Tafsir Center's own.
    intros = api_intros()
    for language, book in API_BOOKS.items():
        texts = [
            api_aims(intros.get(book, {}).get(s, ''), f'{language} {s}')
            for s in range(1, 115)
        ]
        empty = [s for s, t in enumerate(texts, 1) if not t]
        if empty and language not in PARTIAL:
            sys.exit(f'{language} (book {book}): empty for surahs {empty}')
        if empty:
            print(f'{language}: {114 - len(empty)} surahs, none for {empty}')
        languages[language] = texts
    # Tahfeez AI's translations, where no edition has the aims.
    translated = {}
    english = languages['en']
    for name in sorted(os.listdir(TRANSLATED)):
        language = name.removesuffix('.txt')
        lines = open(os.path.join(TRANSLATED, name), encoding='utf8').read()
        lines = lines.split('\n')
        if lines and lines[-1] == '':
            lines.pop()
        own = languages.get(language)
        texts = list(own) if own else [''] * 114
        done = []
        for surah in range(1, 115):
            line = lines[surah - 1].strip() if surah <= len(lines) else ''
            if own and own[surah - 1]:
                if line:
                    sys.exit(f'{name} {surah}: the edition has its own')
                continue
            if not line:
                sys.exit(f'{name} {surah}: no translation')
            if english[surah - 1].count(PBUH) != line.count(PBUH):
                sys.exit(f'{name} {surah}: the salawat differ from English')
            texts[surah - 1] = line
            done.append(surah)
        languages[language] = texts
        translated[language] = done
        print(f'{language}: {len(done)} surahs translated by Tahfeez AI')
    data = {
        'version': 3,
        'source': "Al-Mukhtasar fi Tafsir al-Qur'an al-Karim (Tafsir Center "
        'for Quranic Studies), surah aims: QuranEnc.com (editions) and the '
        "Tafsir Center's Al-Mukhtasar API, mokhtasr.com (apiBooks)",
        'editions': EDITIONS,
        'apiBooks': API_BOOKS,
        # Surahs whose aims are Tahfeez AI's translations of the English.
        'translated': translated,
        'aims': languages,
    }
    with open(OUT, 'w', encoding='utf8') as file:
        json.dump(data, file, ensure_ascii=False, indent=1)
        file.write('\n')
    digest = hashlib.sha256(open(OUT, 'rb').read()).hexdigest()
    print(f'{len(languages)} languages x 114 surahs -> {OUT}')
    print(f'{os.path.getsize(OUT)} bytes, sha256 {digest}')


if __name__ == '__main__':
    main()
