#!/usr/bin/env python3
"""Builds assets/quran/topics.json — the Quran tab's Topics — from the
Quranic Arabic Corpus's ontology of concepts (fetched by
fetch_corpus_ontology.py; GNU GPL v3, non-commercial, cited) and the
concepts' names in the app's languages: the corpus's English; Arabic from
the corpus (tool/quran_data/topic_names/ar.txt, one word made the Quran's
own: «المصباح» for its «لمبة»); the others TahfeezAI's translations of the
English, tool/quran_data/topic_names/<language>.txt — line N the name of
the concept on line N of _ids.txt.

Each concept tagged in at least one ayah is put in one of the app's groups
by where it sits in the ontology (GROUPS: the first whose classes it falls
under), the most mentioned first — the prophets in the order they were
sent (PROPHETS_ORDER).

    python3 tool/quran_data/build_topics.py
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, 'tool/quran_data/.cache/corpus_ontology/concepts.json')
NAMES = os.path.join(ROOT, 'tool/quran_data/topic_names')
OUT = os.path.join(ROOT, 'assets/quran/topics.json')

LANGUAGES = ['en', 'ar', 'ur', 'tr', 'fr', 'de', 'id', 'es', 'ru', 'fa', 'bn',
             'ms', 'ha', 'ckb', 'ps', 'sw', 'kk', 'uz', 'so', 'nl', 'da', 'el',
             'ja', 'ko', 'pt', 'zh']

# Group -> the ontology classes (or concepts) whose members it takes; a
# concept goes to the first group it matches.
GROUPS = [
    ('prophets', {'prophet', 'messenger'}),
    ('stories', set()),  # STORIES only
    ('unseen', {'angel', 'satan', 'iblis', 'jinn', 'allahs-throne',
                'beast-of-the-earth'}),
    ('hereafter', {'afterlife-location', 'afterlife-event', 'hell',
                   'paradise'}),
    ('people', {'human', 'historic-people', 'historic-person', 'king',
                'children-of-adam'}),
    ('places', {'location', 'geographical-location', 'place-of-worship'}),
    ('sky', {'astronomical-body', 'weather-phenomena', 'physical-event'}),
    ('nature', {'biological-organism', 'food'}),
    ('body', {'body-part', 'disease', 'embryo', 'alaq', 'organic-object'}),
    ('times', {'calendar-event', 'historic-event', 'event'}),
    ('scriptures', {'holy-book', 'religion', 'false-deity', 'language',
                    'quran'}),
    ('things', {'artifact', 'physical-substance', 'physical-attribute'}),
]


# Left out (owner, 2026-11-14): Allah — the corpus tags every mention of
# the Name (1,834 ayahs), not a topic to browse.
LEFT_OUT = {'allah'}

# Folded into another (owner, 2026-11-14): the prophet Israel is Ya'qub —
# his name in the list; the corpus's "Israel" is nearly all «بني إسرائيل»
# (its own topic, Children of Israel), so only the ayahs where إسرائيل is
# Ya'qub himself go to him: 3:93 (ما حرم إسرائيل على نفسه) and 19:58
# (ومن ذرية إبراهيم وإسرائيل).
# A prophet's other names, one topic (owner, 2026-11-14): «المسيح» Isa's,
# «أحمد» Muhammad's ﷺ — all their ayahs (None).
FOLDED = {
    'israel': ('yaqub', {3093, 19058}),
    'messiah': ('jesus', None),
    'ahmad': ('muhammad', None),
}

# A story told in one passage: its whole passage, not only the ayahs that
# name it (owner, 2026-11-14) — (surah, first ayah, last ayah), TahfeezAI's
# ranges, each checked against the Tanzil text (the story begins at the
# first, the next ayah after the last moves on). The corpus's own ayahs are
# kept too.
PASSAGES = {
    'companions-of-the-cave': [(18, 9, 26)],
    'dhul-qarnayn': [(18, 83, 98)],
    'gog-and-magog': [(18, 94, 98), (21, 96, 97)],
    'companions-of-the-elephant': [(105, 1, 5)],
    'companions-of-the-pit': [(85, 4, 10)],
    'qarun': [(28, 76, 82)],
    'luqman': [(31, 12, 19)],
    'talut': [(2, 246, 251)],
    'jalut': [(2, 249, 251)],
    'abel': [(5, 27, 31)],
    'cain': [(5, 27, 31)],
    'cow': [(2, 67, 73)],
    'hoopoe': [(27, 20, 28)],
    'ant': [(27, 18, 19)],
    'sheba': [(27, 22, 44), (34, 15, 21)],
    'samiri': [(20, 85, 97)],
    'abu-lahab': [(111, 1, 5)],
    'umm-jamil': [(111, 4, 5)],
    'romans': [(30, 2, 5)],
    'quraysh': [(106, 1, 4)],
}

# The prophets in the order they were sent, Adam to Muhammad ﷺ (owner,
# 2026-11-14) — the order commonly given (Ibn Kathir's Qisas al-Anbiya);
# every prophet kept must be here.
PROPHETS_ORDER = [
    'adam', 'idris', 'nuh', 'hud', 'salih', 'ibrahim', 'lut', 'ishmael',
    'isaac', 'yaqub', 'yusuf', 'ayyub', 'shuayb', 'musa', 'harun', 'david',
    'solomon', 'elijah', 'elisha', 'yunus', 'uzair', 'zechariah', 'yahya',
    'jesus', 'muhammad',
]

# Stories told in one passage that are not concepts of the corpus (owner,
# 2026-11-15): TahfeezAI's own — (id, English name, passage), in the order
# they took place; each checked against the Tanzil text (the story begins
# at its first ayah, the ayah after its last moves on). Their names in the
# other languages are in topic_names/ as the corpus's concepts' are.
STORIES = [
    ('story-adam', 'Adam and Iblis', (2, 30, 39)),
    ('story-nuh', 'Nuh and the Flood', (11, 25, 49)),
    ('story-ibrahim', 'Ibrahim and the idols', (21, 51, 70)),
    ('story-yusuf', 'The story of Yusuf', (12, 4, 101)),
    ('story-musa-birth', 'The birth of Musa', (28, 3, 13)),
    ('story-believer', "The believer of Pharaoh's family", (40, 28, 45)),
    ('story-khidr', 'Musa and al-Khidr', (18, 60, 82)),
    ('story-sabbath', 'The people of the Sabbath', (7, 163, 166)),
    ('story-yunus', 'Yunus and the whale', (37, 139, 148)),
    ('story-maryam', 'Maryam and the birth of Isa', (19, 16, 34)),
    ('story-town', 'The people of the town', (36, 13, 29)),
    ('story-two-gardens', 'The man of the two gardens', (18, 32, 44)),
    ('story-garden', 'The owners of the garden', (68, 17, 33)),
]

# Put in a group other than the ontology's (owner, 2026-11-14): 'Uzair
# among the prophets (the corpus has him among people; scholars differ).
MOVED = {'uzair': 'prophets', **{i: 'stories' for i, _, _ in STORIES}}


def group_of(concept):
    if concept['id'] in MOVED:
        return MOVED[concept['id']]
    lineage = set(concept['classes']) | {concept['id']}
    for group, members in GROUPS:
        if lineage & members:
            return group
    return None


def main():
    concepts = json.load(open(SOURCE, encoding='utf8'))
    concepts += [
        {'id': i, 'en': en, 'classes': [],
         'ayahs': [s * 1000 + a for a in range(a0, a1 + 1)]}
        for i, en, (s, a0, a1) in STORIES
    ]
    order = [line.split('\t')[0] for line in
             open(os.path.join(NAMES, '_ids.txt'), encoding='utf8')
             .read().splitlines()]
    names = {i: {} for i in order}
    for language in LANGUAGES:
        if language == 'en':
            continue
        lines = open(os.path.join(NAMES, f'{language}.txt'),
                     encoding='utf8').read().splitlines()
        if len(lines) != len(order):
            sys.exit(f'{language}: {len(lines)} names, not {len(order)}')
        for i, name in zip(order, lines):
            if not name.strip():
                sys.exit(f'{language}: no name for {i}')
            names[i][language] = name.strip()
    kept, groups = {}, {g: [] for g, _ in GROUPS}
    by_id = {c['id']: c for c in concepts}
    for folded, (into, ayahs) in FOLDED.items():
        if ayahs is None:
            ayahs = set(by_id[folded]['ayahs'])
        if not ayahs <= set(by_id[folded]['ayahs']):
            sys.exit(f'{folded}: not tagged in {sorted(ayahs)}')
        by_id[into]['ayahs'] = sorted(set(by_id[into]['ayahs']) | ayahs)
    for concept_id, ranges in PASSAGES.items():
        concept = by_id[concept_id]
        passage = {s * 1000 + a for s, a0, a1 in ranges
                   for a in range(a0, a1 + 1)}
        concept['ayahs'] = sorted(set(concept['ayahs']) | passage)
    for c in concepts:
        if not c['ayahs'] or c['id'] in LEFT_OUT or c['id'] in FOLDED:
            continue
        group = group_of(c)
        if group is None:
            sys.exit(f"{c['id']} ({c['classes']}): in no group")
        own = names.get(c['id'])
        if own is None:
            sys.exit(f"{c['id']} ({c['en']}): no names")
        missing = [l for l in LANGUAGES if l not in ('en', 'ar')
                   and not own.get(l)]
        if missing:
            sys.exit(f"{c['id']}: no name in {missing}")
        kept[c['id']] = {
            # Its Arabic name (the corpus's, as corrected in ar.txt).
            'ar': own['ar'],
            'names': {'en': c['en'], **{l: own[l] for l in LANGUAGES
                                        if l != 'en' and own.get(l)}},
            'ayahs': sorted(c['ayahs']),
        }
        groups[group].append(c['id'])
    unused = sorted(set(names) - set(kept))
    if unused:
        print(f'names for concepts not kept: {unused}')
    if sorted(groups['prophets']) != sorted(PROPHETS_ORDER):
        sys.exit(f"prophets: {sorted(groups['prophets'])} not as ordered")

    def order(group, ids):
        if group == 'prophets':
            return PROPHETS_ORDER
        if group == 'stories':
            return [i for i, _, _ in STORIES]
        return sorted(ids, key=lambda i: (-len(kept[i]['ayahs']),
                                          kept[i]['names']['en']))

    data = {
        'version': 1,
        'source': 'Quranic Arabic Corpus, ontology of Quranic concepts '
        '(corpus.quran.com; Kais Dukes, University of Leeds; GNU GPL v3). '
        "Names: the corpus's English and Arabic; the others TahfeezAI's "
        'translations of the English.',
        'groups': [
            {'id': g, 'concepts': order(g, ids)}
            for g, ids in groups.items() if ids
        ],
        'concepts': kept,
    }
    with open(OUT, 'w', encoding='utf8') as file:
        json.dump(data, file, ensure_ascii=False, separators=(',', ':'))
    digest = hashlib.sha256(open(OUT, 'rb').read()).hexdigest()
    for g in data['groups']:
        print(f"{g['id']}: {len(g['concepts'])}")
    print(f'{len(kept)} concepts -> {OUT} '
          f'({os.path.getsize(OUT)} bytes, sha256 {digest})')


if __name__ == '__main__':
    main()
