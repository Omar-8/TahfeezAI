#!/usr/bin/env python3
"""Fetches the Quranic Arabic Corpus's ontology of Quranic concepts
(https://corpus.quran.com/ontology.jsp; Kais Dukes, University of Leeds;
GNU GPL v3 — non-commercial use, with a citation) into
tool/quran_data/.cache/corpus_ontology/concepts.json: every concept of its
topic index with its English and Arabic names, its place in the ontology
(the classification from the root), and the ayahs the corpus tags with it.

    python3 tool/quran_data/fetch_corpus_ontology.py

Each page fetched is cached beside it, so a second run fetches nothing.
Gently: one request at a time, half a second apart.
"""
import html
import json
import os
import re
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CACHE = os.path.join(ROOT, 'tool/quran_data/.cache/corpus_ontology')
SITE = 'https://corpus.quran.com'


def page(path):
    name = re.sub(r'[^a-zA-Z0-9_.-]', '_', path) + '.html'
    cached = os.path.join(CACHE, name)
    if not os.path.exists(cached):
        request = urllib.request.Request(
            SITE + path, headers={'User-Agent': 'Mozilla/5.0 (data build)'}
        )
        for attempt in range(4):
            try:
                body = urllib.request.urlopen(request, timeout=60).read()
                break
            except Exception:  # noqa: BLE001 - retried, then raised
                if attempt == 3:
                    raise
                time.sleep(5 * (attempt + 1))
        with open(cached, 'wb') as file:
            file.write(body)
        time.sleep(0.5)
    return open(cached, encoding='utf8', errors='ignore').read()


def text(fragment):
    fragment = re.sub(r'<script.*?</script>|<style.*?</style>', ' ', fragment,
                      flags=re.S)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ',
                                                    fragment))).strip()


def concept(cid):
    h = page(f'/concept.jsp?id={cid}')
    title = re.search(r'<td colspan="2" class="name">(.*?)</td>', h, re.S)
    arabic = re.search(r'<td colspan="2" class="arabic">(.*?)</td>', h, re.S)
    table = re.search(r'<table[^>]*class="hierarchyTable">(.*?)</table>', h,
                      re.S)
    path = re.findall(r'concept\.jsp\?id=([a-z0-9-]+)',
                      table.group(1)) if table else []
    # From the root: the classes above this concept, nearest last.
    classes = [c for c in path if c not in ('concept', cid)]
    return {
        'id': cid,
        'en': text(title.group(1)) if title else cid,
        'ar': text(arabic.group(1)) if arabic else '',
        'classes': classes,
        'parent': classes[-1] if classes else None,
        'category': '(Category)' in text(h),
    }


def verses(cid):
    refs, number = [], 1
    while True:
        query = f'/search.jsp?q=con%3A{cid}' + (
            f'&s=1&page={number}' if number > 1 else '')
        h = page(query)
        for chapter, verse in re.findall(r'\((\d+):(\d+):\d+\)', text(h)):
            ref = int(chapter) * 1000 + int(verse)
            if ref not in refs:
                refs.append(ref)
        if f'page={number + 1}"' not in h:
            return refs
        number += 1


def main():
    os.makedirs(CACHE, exist_ok=True)
    index = page('/topics.jsp')
    ids = sorted(set(re.findall(r'concept\.jsp\?id=([a-z0-9-]+)', index)))
    tree = page('/concept.jsp')
    ids = sorted(set(ids) | set(re.findall(r'concept\.jsp\?id=([a-z0-9-]+)',
                                           tree)))
    concepts = []
    for n, cid in enumerate(ids, 1):
        c = concept(cid)
        c['ayahs'] = verses(cid)
        concepts.append(c)
        if n % 25 == 0:
            print(f'{n}/{len(ids)}', flush=True)
    out = os.path.join(CACHE, 'concepts.json')
    with open(out, 'w', encoding='utf8') as file:
        json.dump(concepts, file, ensure_ascii=False, indent=1)
    print(f'{len(concepts)} concepts -> {out}')


if __name__ == '__main__':
    main()
