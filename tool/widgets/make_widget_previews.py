"""The widget picker's preview pictures (Android; owner, 2026-11-22: some
launchers — MIUI's — show these, not the live preview layouts): each
widget in the app's light look with sample content, drawn here.

  python3 tool/widgets/make_widget_previews.py

Writes android/app/src/main/res/drawable-nodpi/widget_preview_<kind>.png.
The daily ayah's text is the dataset's (94:5, Uthmani, Tanzil) and its
translation the bundled Rowwad one's — never typed or generated.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'android/app/src/main/res/drawable-nodpi'
ICONS = '/home/omar/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
SANS = str(ROOT / 'assets/fonts/NotoSans-Variable.ttf')
QURAN = str(ROOT / 'assets/fonts/AmiriQuran.ttf')
K = 3  # px per dp

GOLD = (0xE0, 0xA5, 0x26)

# The app's two looks, as the widgets draw them (TahfeezWidgets.kt's Look,
# drawable/widget_glass_*, widget_tile_*).
LOOKS = {
    'light': dict(TEXT=(0x18, 0x20, 0x1D), MUTED=(0x58, 0x63, 0x5E), PRIMARY=(0x17, 0x6B, 0x5B),
                  CONTAINER=(0xC3, 0xE2, 0xD6), ON=(0x0D, 0x3F, 0x35), OUTLINE=(0xB7, 0xC2, 0xBC),
                  GLASS=(252, 253, 251, 235), EDGE=(0x17, 0x6B, 0x5B, 70),
                  TILE=(255, 255, 255, 240), TILE_EDGE=(0xE4, 0xE8, 0xE5, 255),
                  NEXT_EDGE=(0x17, 0x6B, 0x5B, 90)),
    'dark': dict(TEXT=(0xEC, 0xF2, 0xEF), MUTED=(0xAA, 0xB6, 0xB0), PRIMARY=(0x68, 0xC6, 0xA8),
                 CONTAINER=(0x20, 0x3D, 0x34), ON=(0xC3, 0xE2, 0xD6), OUTLINE=(0x5E, 0x6B, 0x65),
                 GLASS=(0x1A, 0x22, 0x1E, 230), EDGE=(255, 255, 255, 40),
                 TILE=(0x2A, 0x35, 0x2F, 255), TILE_EDGE=(255, 255, 255, 18),
                 NEXT_EDGE=(0x68, 0xC6, 0xA8, 90)),
}
globals().update(LOOKS['light'])

# Each picture as drawn in each look, before the two are put together.
DRAWN = {}
GLYPH = {'explore': 0xf037, 'athkar': 0xf2f3, 'habits': 0xf02c, 'khatmah': 0xeeaf, 'quran': 0xf1c2,
         'memorize': 0xf33c, 'ayah': 0xeea9, 'bookmark': 0xe0f4, 'calendar': 0xf051f, 'done': 0xf635,
         'open': 0xe504, 'sun': 0xf02ae}
AYAH = 'فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا'  # 94:5, from the app's dataset
# Its English, the app's bundled Rowwad translation's (its footnote mark
# left out).
AYAH_EN = 'For indeed, with hardship comes ease'


def font(size, bold=False, path=SANS):
    f = ImageFont.truetype(path, size * K)
    if bold and path == SANS:
        try:
            f.set_variation_by_name('Bold')
        except Exception:
            pass
    return f


class Canvas:
    def __init__(self, w, h):
        self.im = Image.new('RGBA', (w * K, h * K), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def glass(self, x, y, w, h, r=24):
        box = [x * K, y * K, (x + w) * K - 1, (y + h) * K - 1]
        self.d.rounded_rectangle(box, r * K, fill=GLASS, outline=EDGE, width=K)

    def tile(self, x, y, w, h, nxt=False):
        self.d.rounded_rectangle([x * K, y * K, (x + w) * K, (y + h) * K], 12 * K,
                                 fill=CONTAINER if nxt else TILE,
                                 outline=NEXT_EDGE if nxt else TILE_EDGE, width=K)

    def text(self, x, y, s, size=13, color=None, bold=False, anchor='la', path=SANS, direction=None):
        color = color or TEXT
        self.d.text((x * K, y * K), s, font=font(size, bold, path), fill=color, anchor=anchor,
                    direction=direction)

    def icon(self, x, y, name, size=18, color=None, anchor='la'):
        color = color or PRIMARY
        if name == 'duas':
            # The Duas hands (tool/widgets/make_dua_hands.py), not a glyph:
            # its shape, in [color].
            shape = Image.open(OUT / 'widget_preview_icon_duas.png').resize((size * K, size * K))
            im = Image.new('RGBA', shape.size, color + (0,))
            im.putalpha(shape.getchannel('A'))
            left = x * K - (size * K // 2 if anchor[0] == 'm' else 0)
            self.im.alpha_composite(im, (int(left), int(y * K)))
            return
        self.d.text((x * K, y * K), chr(GLYPH[name]), font=ImageFont.truetype(ICONS, size * K),
                    fill=color, anchor=anchor)

    def save(self, kind):
        DRAWN.setdefault(kind, []).append(self.im)


def prayer_row(c, x, y, w, header):
    names = ['Fajr', 'Sunrise', 'Dhuhr', 'ʿAsr', 'Maghrib', 'ʿIshāʾ']
    times = ['5:12', '6:41', '11:52', '2:47', '5:04', '6:27']
    if header:
        c.text(x, y, '1:35 PM', 14, PRIMARY, bold=True)
        c.text(x + 62, y, '|', 13, OUTLINE)
        c.text(x + 72, y + 1, 'Sun, Nov 22', 12, MUTED)
    else:
        c.text(x, y, 'Cairo, Egypt', 14, bold=True)
    c.text(x + w, y + 1, 'ʿAsr in 1 h 12 min', 13, PRIMARY, bold=True, anchor='ra')
    tw = (w - 10) / 6
    for i in range(6):
        tx = x + i * (tw + 2)
        c.tile(tx, y + 22, tw, 40, nxt=i == 3)
        c.text(tx + tw / 2, y + 28, names[i], 10, ON if i == 3 else MUTED, anchor='ma')
        c.text(tx + tw / 2, y + 42, times[i], 13, ON if i == 3 else TEXT, bold=True, anchor='ma')


def date_card(c, x, y, w):
    # The time on its glass square; today's date, the Hijri date under it.
    c.glass(x, y, 60, 56, r=16)
    c.text(x + 30, y + 24, '1:35', 19, PRIMARY, bold=True, anchor='mm')
    c.text(x + 30, y + 42, 'PM', 11, PRIMARY, bold=True, anchor='mm')
    c.text(x + 72, y + 8, 'Sunday, November 22', 15, bold=True)
    c.text(x + 72, y + 30, '12 Jumada al-Akhirah 1448 AH', 13, MUTED)
    c.icon(x + w, y + 18, 'sun', 22, GOLD, anchor='ra')


def buttons(c, x, y, w, h):
    """Home's four buttons as one group (owner, 2026-11-23)."""
    c.glass(x, y, w, h)
    bw = w / 4
    for i, (name, label) in enumerate([('explore', 'Qibla'), ('athkar', 'Athkar'),
                                       ('duas', 'Duas'), ('habits', 'Habits')]):
        bx = x + i * bw
        if i:
            c.d.line([(bx * K, (y + 14) * K), (bx * K, (y + h - 14) * K)],
                     fill=(0x17, 0x6B, 0x5B, 36), width=K)
        c.icon(bx + bw / 2, y + h / 2 - 16, name, 24, anchor='ma')
        c.text(bx + bw / 2, y + h / 2 + 12, label, 13, PRIMARY, bold=True, anchor='ma')


def header(c, x, y, w, glyph, title, corner=None):
    c.icon(x, y, glyph, 18)
    c.text(x + 24, y + 1, title, 13, bold=True)
    if corner:
        c.text(x + w, y + 2, corner, 12, PRIMARY, bold=True, anchor='ra')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for look in ('light', 'dark'):
        globals().update(LOOKS[look])
        draw()
    # One picture each, light and dark together (owner, 2026-11-23): the
    # widget split on a slant — light before, dark after.
    for kind, (light, dark) in DRAWN.items():
        w, h = light.size
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).polygon([(w * 0.58, 0), (w, 0), (w, h), (w * 0.42, h)], fill=255)
        out = light.copy()
        out.paste(dark, (0, 0), mask)
        out.save(OUT / f'widget_preview_{kind}.png', optimize=True)
    print('ok')


def draw():
    # Prayer times, 5 × 1.
    c = Canvas(360, 90); c.glass(0, 0, 360, 90); prayer_row(c, 12, 10, 336, True); c.save('prayer')
    # The date, 5 × 1.
    c = Canvas(360, 80); c.glass(0, 0, 360, 80); date_card(c, 12, 10, 336); c.save('date')
    # Date and prayer times.
    c = Canvas(360, 170)
    c.glass(0, 0, 360, 78); date_card(c, 12, 10, 336)
    c.glass(0, 86, 360, 84); prayer_row(c, 12, 96, 336, False); c.save('today')
    # Home: date, prayer times, buttons.
    c = Canvas(360, 254)
    c.glass(0, 0, 360, 78); date_card(c, 12, 10, 336)
    c.glass(0, 86, 360, 84); prayer_row(c, 12, 96, 336, False)
    buttons(c, 0, 178, 360, 76); c.save('home')
    # The four buttons, 5 × 1 and 3 × 1.
    c = Canvas(360, 76); buttons(c, 0, 0, 360, 76); c.save('shortcuts')
    c = Canvas(220, 76); buttons(c, 0, 0, 220, 76); c.save('shortcuts_small')
    # One button each.
    for kind, glyph, label in [('qibla', 'explore', 'Qibla'), ('athkar', 'athkar', 'Athkar'),
                               ('duas', 'duas', 'Duas'), ('habits', 'habits', 'Habits'),
                               ('quran', 'quran', "Qur'an")]:
        c = Canvas(84, 84); c.glass(0, 0, 84, 84)
        c.icon(42, 18, glyph, 30, anchor='ma'); c.text(42, 56, label, 13, PRIMARY, bold=True, anchor='ma')
        c.save(kind)
    # The daily ayah.
    c = Canvas(360, 150); c.glass(0, 0, 360, 150); header(c, 12, 12, 336, 'ayah', 'Daily Ayah', 'Ash-Sharh · 5')
    c.text(180, 70, AYAH, 26, TEXT, anchor='mm', path=QURAN, direction='rtl')
    c.text(180, 112, AYAH_EN, 12, MUTED, anchor='ma'); c.save('ayah')
    # Continue reading.
    c = Canvas(220, 84); c.glass(0, 0, 220, 84); header(c, 12, 12, 196, 'bookmark', 'Continue Reading')
    c.text(12, 38, 'Al-Kahf · 10', 16, bold=True); c.text(12, 60, 'Continue', 13, PRIMARY); c.save('reading')
    # Memorization and the khatmah.
    for kind, glyph, title, corner, line, p in [
            ('memorize', 'memorize', 'Memorization', '1/3', 'New lesson · An-Naas 1–6', 1 / 3),
            ('khatmah', 'khatmah', 'Khatmah', '40%', 'Today: pages 241–250', 0.4)]:
        c = Canvas(220, 84); c.glass(0, 0, 220, 84); header(c, 12, 12, 196, glyph, title, corner)
        c.text(12, 38, line, 13, TEXT, bold=True)
        c.d.rounded_rectangle([12 * K, 64 * K, 208 * K, 70 * K], 3 * K, fill=(0xE4, 0xE8, 0xE5, 255))
        c.d.rounded_rectangle([12 * K, 64 * K, (12 + 196 * p) * K, 70 * K], 3 * K, fill=PRIMARY)
        c.save(kind)


if __name__ == '__main__':
    main()
