"""Builds assets/athkar/athkar.json.gz from Hisn al-Muslim as hisnmuslim.com
publishes it (its JSON API: /api/{ar,en}/husn_{ar,en}.json and
/api/{ar,en}/<category>.json — Arabic and English).

  python3 -I tool/athkar/build_athkar.py <download dir with ar/ and en/>

Fetch first (once; ~270 small files):
  for each language: <lang>/index.json = /api/<lang>/husn_<lang>.json,
  then <lang>/<ID>.json for every category ID in it.

The text is kept as published. Only changed:
- Arabic presentation-form letters (U+FB50–FDCF, FE70–FEFF: e.g. «ﺗﻬنئة»)
  written as the ordinary letters they show (NFKC, letter by letter) —
  how they look is the same; word ligatures (ﷺ, U+FDF0–FDFF) are kept;
- spaces at the ends trimmed;
- the titles from each language's index (en/126.json's own is malformed);
- two Arabic titles' misprints ([TITLE_FIXES]: a damma before its letter,
  «مترلا» for «منزلا»);
- the English titles' first letter a capital, their spaces trimmed, and
  one's lost letters («vocation for someone…» → «Invocation for…»).
Added: Tahfeez's own short titles ([SHORT_EN], [SHORT_AR]), beside the
book's.
Checks: both languages have the same categories and athkar (by ID), every
zikr has Arabic and a count >= 1, its audio a file under /audio/ar/ (or
none).
"""
import gzip, json, re, sys, unicodedata
from pathlib import Path

src = Path(sys.argv[1])
out = Path(__file__).resolve().parents[2] / 'assets/athkar/athkar.json.gz'


def letters(s):
    def one(ch):
        c = ord(ch)
        if (0xFB50 <= c <= 0xFDCF) or (0xFE70 <= c <= 0xFEFF):
            return unicodedata.normalize('NFKC', ch)
        return ch
    return ''.join(one(ch) for ch in s).strip()


# Misprints in the Arabic titles (the categories' text itself is untouched).
TITLE_FIXES = {
    'دعاء ُلبْس الثوب': 'دعاء لُبْس الثوب',
    'دعاء ُلبْس الثوب الجديد': 'دعاء لُبْس الثوب الجديد',
    'الدعاء إذا نزل مترلا في سفر أو غيره': 'الدعاء إذا نزل منزلًا في سفر أو غيره',
}


def english_title(t):
    t = letters(t)
    if t.startswith('vocation '):
        t = 'In' + t
    return t[:1].upper() + t[1:]

# Tahfeez's own short titles (owner, 2026-11-21: the book's were too long
# for its tiles) — shown on the tiles and as a chapter's name, the book's
# own title under it; every chapter in English, the long ones in Arabic.
SHORT_EN = {
    27: 'Morning & evening', 28: 'Before sleeping', 1: 'Waking up',
    6: 'Entering the restroom', 7: 'Leaving the restroom',
    8: 'Before ablution', 9: 'After ablution', 10: 'Leaving home',
    11: 'Entering home', 12: 'Going to the mosque',
    13: 'Entering the mosque', 14: 'Leaving the mosque',
    15: 'The call to prayer', 2: 'Getting dressed', 3: 'New clothes',
    4: 'For someone in new clothes', 5: 'Undressing',
    16: 'Opening the prayer', 17: 'Bowing (rukuʿ)',
    18: 'Rising from bowing', 19: 'Prostration (sujud)',
    20: 'Between the prostrations', 21: 'Prostration of recitation',
    22: 'The tashahhud', 23: 'Blessings on the Prophet ﷺ',
    24: 'Before the salam', 25: 'After the prayer', 26: 'Istikhara',
    29: 'Turning in the night', 30: 'Fear or loneliness at night',
    31: 'Bad dreams', 32: 'Qunut in Witr', 33: 'After Witr',
    34: 'Worry and grief', 35: 'Anguish', 36: 'Facing an enemy or ruler',
    37: "Fearing a ruler's injustice", 38: 'Against an enemy',
    39: 'Fearing people', 40: 'Doubts in faith', 41: 'Settling a debt',
    42: 'Whispers in prayer', 43: 'When something is hard',
    44: 'After a sin', 45: 'Driving Satan away',
    46: 'When the unwanted happens', 47: 'A newborn',
    48: 'Protecting children', 49: 'Visiting the sick',
    50: 'Reward of visiting the sick', 51: 'The gravely ill',
    52: 'The dying', 53: 'A calamity', 54: 'Closing the eyes of the dead',
    55: 'Funeral prayer', 56: 'Funeral prayer for a child',
    57: 'Condolence', 58: 'Placing in the grave', 59: 'After burial',
    60: 'Visiting graves', 61: 'Wind', 62: 'Thunder', 63: 'Asking for rain',
    64: 'When it rains', 65: 'After rain', 66: 'Asking for clear skies',
    67: 'The new moon', 68: 'Breaking the fast', 69: 'Before eating',
    70: 'After eating', 71: 'A guest for the host',
    72: 'For one who gives you drink', 73: 'Breaking the fast as a guest',
    74: 'Fasting, offered food', 75: 'Fasting and insulted',
    76: 'First fruits', 77: 'Sneezing', 78: 'A non-Muslim sneezes',
    79: 'For the groom', 80: 'The groom; a new animal',
    81: 'Before intimacy', 82: 'Anger', 83: 'Seeing someone afflicted',
    84: 'In a gathering', 85: 'Leaving a gathering',
    86: '"May Allah forgive you"', 87: 'For a kindness',
    88: 'Protection from the Dajjal', 89: '"I love you for Allah\'s sake"',
    90: 'For one who offers wealth', 91: 'Repaying a loan',
    92: 'Fear of shirk', 93: '"May Allah bless you"',
    94: 'Against bad omens', 95: 'Riding', 96: 'Travel',
    97: 'Entering a town', 98: 'Entering a market',
    99: 'When the mount stumbles', 100: 'The traveler to those staying',
    101: 'Those staying to the traveler', 102: 'Takbir on the way',
    103: 'The traveler at dawn', 104: 'Stopping on the way',
    105: 'Returning from travel', 106: 'Good or bad news',
    107: 'Virtue of blessings on the Prophet ﷺ', 108: 'Spreading salam',
    109: "Returning a non-Muslim's salam",
    110: 'A rooster crows, a donkey brays', 111: 'Dogs barking at night',
    112: 'For one you insulted', 113: 'Praising a Muslim',
    114: 'When praised', 115: 'The talbiya', 116: 'At the Black Stone',
    117: 'Yemeni corner to the Black Stone', 118: 'At Safa and Marwa',
    119: 'The day of ʿArafah', 120: 'At al-Mashʿar al-Haram',
    121: 'Stoning the pillars', 122: 'Surprise and good news',
    123: 'Pleasing news', 124: 'Pain in the body',
    125: 'Fearing the evil eye', 126: 'Fright', 127: 'Slaughtering',
    128: 'Foiling the devils', 129: 'Repentance', 130: 'Virtue of dhikr',
    131: "The Prophet's tasbih", 132: 'Good manners',
}
SHORT_AR = {
    24: 'الدعاء قبل السلام',
    30: 'الفزع في النوم والوحشة',
    36: 'لقاء العدو وذي السلطان',
    42: 'الوسوسة في الصلاة',
    46: 'إذا وقع ما لا يرضاه',
    72: 'طلب الطعام أو الشراب',
    74: 'الصائم إذا حضر الطعام',
    78: 'الكافر إذا عطس',
    89: 'لمن قال: أحبك في الله',
    102: 'التكبير في السفر',
    104: 'إذا نزل منزلًا',
    106: 'أمر يسره أو يكرهه',
    107: 'فضل الصلاة على النبي ﷺ',
    109: 'رد السلام على الكافر',
    110: 'صياح الديك ونهيق الحمار',
    115: 'التلبية',
    117: 'بين الركنين',
    121: 'رمي الجمار',
    128: 'رد كيد الشياطين',
    130: 'فضل التسبيح والتحميد',
}


def load(p):
    # (Some files' strings hold raw line breaks: strict=False.)
    return json.loads(p.read_text(encoding='utf-8-sig'), strict=False)


def index(lang):
    d = load(src / lang / 'index.json')
    return list(d.values())[0]


def items(lang, cid):
    raw = (src / lang / f'{cid}.json').read_text(encoding='utf-8-sig')
    if lang == 'en' and cid == 126:
        # Its title lacks its closing quote; the index has the title.
        raw = raw.replace('"What to say when you feel frightened: ',
                          '"What to say when you feel frightened": ', 1)
    d = json.loads(raw, strict=False)
    return list(d.values())[0]


ar_index, en_index = index('ar'), index('en')
assert [c['ID'] for c in ar_index] == [c['ID'] for c in en_index]
cats = []
for a, e in zip(ar_index, en_index):
    cid = a['ID']
    audio = a['AUDIO_URL'].rsplit('/', 1)[-1]
    assert e['AUDIO_URL'].rsplit('/', 1)[-1] == audio, cid
    assert re.fullmatch(r'ar_7esn_AlMoslem_by_Doors_\d{3}\.mp3', audio), audio
    ai, ei = items('ar', cid), items('en', cid)
    assert [x['ID'] for x in ai] == [x['ID'] for x in ei], cid
    zs = []
    for x, y in zip(ai, ei):
        assert x['REPEAT'] == y['REPEAT'] and x['REPEAT'] >= 1, (cid, x['ID'])
        # Its audio: /audio/ar/<file>.mp3, or none ("…/ar/.mp3").
        file = x['AUDIO'].rsplit('/', 1)[-1]
        assert x['AUDIO'].startswith('http://www.hisnmuslim.com/audio/ar/'), x
        assert re.fullmatch(r'(\d+\.mp3|\.mp3)', file), file
        text = letters(x['ARABIC_TEXT'])
        assert text, x['ID']
        zs.append({
            'id': x['ID'],
            'ar': text,
            # (A few English entries lack one of these: empty.)
            'en': letters(y.get('TRANSLATED_TEXT', '')),
            # Its transliteration, or how to say it ("Recite Ayat-Al-Kursiy").
            'note': letters(y.get('LANGUAGE_ARABIC_TRANSLATED_TEXT', '')),
            'repeat': x['REPEAT'],
            'audio': None if file == '.mp3' else file,
        })
    cats.append({
        'id': cid,
        'ar': TITLE_FIXES.get(letters(a['TITLE']), letters(a['TITLE'])),
        'en': english_title(e['TITLE']),
        'arShort': SHORT_AR.get(cid),
        'enShort': SHORT_EN[cid],
        'audio': audio,
        'items': zs,
    })

assert {c['ar'] for c in cats}.isdisjoint(TITLE_FIXES), 'a fix not applied'
assert set(SHORT_EN) == {c['id'] for c in cats}, 'a short English title each'
assert set(SHORT_AR) <= {c['id'] for c in cats}
ids = [z['id'] for c in cats for z in c['items']]
assert len(ids) == len(set(ids))
data = {
    'source': 'Hisn al-Muslim (Saʿid ibn Wahf al-Qahtani), as published '
              'by hisnmuslim.com (Arabic and English)',
    'categories': cats,
}
body = json.dumps(data, ensure_ascii=False, separators=(',', ':')).encode()
out.write_bytes(gzip.compress(body, mtime=0))
print(f'{len(cats)} categories, {len(ids)} athkar, '
      f'{len(body)} bytes, {out.stat().st_size} gzipped')
