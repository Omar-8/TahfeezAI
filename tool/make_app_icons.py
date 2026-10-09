"""Builds the app icons from assets/branding/app_icon_source.png.

The source is a rounded tile on a dark margin. The tile is cropped inside
its rim and its rounded corners are filled with the tile's own colours,
giving a full-bleed square master; each platform then gets its sizes
(Android adaptive + legacy, iOS, web).

  python3 tool/make_app_icons.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = Image.open(os.path.join(ROOT, 'assets/branding/app_icon_source.png')).convert('RGB')

# The tile, inside its rim.
L, T, R, B = 116, 102, 1138, 1124
tile = src.crop((L, T, R, B))
w, h = tile.size

# Each row's tile colour, away from the emblem, fills the corners.
fill = Image.new('RGB', (w, h))
px = fill.load()
for y in range(h):
    sy = y + T
    sx = 300 if sy < 230 or sy > 1000 else 160
    c = src.getpixel((sx, sy))
    for x in range(w):
        px[x, y] = c
mask = Image.new('L', (w, h), 0)
ImageDraw.Draw(mask).rounded_rectangle((22, 22, w - 23, h - 23), radius=200, fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(10))
master = Image.composite(tile, fill, mask).resize((1024, 1024), Image.LANCZOS)
BG = fill.getpixel((w // 2, h - 1))  # the tile's darkest, at its foot


def padded(scale, size):
    """[master] at [scale] of a [size] square of the tile's colours."""
    inner = round(size * scale)
    canvas = fill.resize((size, size), Image.LANCZOS)
    canvas.paste(master.resize((inner, inner), Image.LANCZOS),
                 ((size - inner) // 2, (size - inner) // 2))
    return canvas


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def rounded(img, radius_share):
    out = img.convert('RGBA')
    m = Image.new('L', img.size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, img.size[0] - 1, img.size[1] - 1),
        radius=round(img.size[0] * radius_share), fill=255)
    out.putalpha(m)
    return out


if __name__ == '__main__':
    save(master, 'assets/branding/app_icon.png')

    # Android: adaptive (API 26+): an opaque foreground with the emblem
    # inside the masks' safe circle; legacy icons below.
    res = 'android/app/src/main/res'
    for d, scale in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
        save(padded(0.68, round(108 * scale)), f'{res}/drawable-{d}/ic_launcher_foreground.png')
        save(rounded(master.resize((round(48 * scale),) * 2, Image.LANCZOS), 0.18),
             f'{res}/mipmap-{d}/ic_launcher.png')
    os.makedirs(f'{ROOT}/{res}/mipmap-anydpi-v26', exist_ok=True)
    with open(f'{ROOT}/{res}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@drawable/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    with open(f'{ROOT}/{res}/values/ic_launcher_background.xml', 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
                '</resources>\n' % BG)

    # iOS: opaque squares; iOS rounds them.
    ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    with open(f'{ROOT}/{ios}/Contents.json') as f:
        contents = json.load(f)
    for image in contents['images']:
        if 'filename' not in image:
            continue
        pt = float(image['size'].split('x')[0])
        px_ = round(pt * int(image['scale'][0]))
        save(master.resize((px_, px_), Image.LANCZOS), f'{ios}/{image["filename"]}')

    # Web: rounded icons, and maskable ones inside the 80% safe circle.
    save(rounded(master.resize((192, 192), Image.LANCZOS), 0.18), 'web/icons/Icon-192.png')
    save(rounded(master.resize((512, 512), Image.LANCZOS), 0.18), 'web/icons/Icon-512.png')
    save(padded(0.84, 192), 'web/icons/Icon-maskable-192.png')
    save(padded(0.84, 512), 'web/icons/Icon-maskable-512.png')
    save(rounded(master.resize((32, 32), Image.LANCZOS), 0.18), 'web/favicon.png')
    print('background #%02X%02X%02X' % BG)
