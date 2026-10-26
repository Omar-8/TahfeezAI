#!/usr/bin/env python3
"""Frames the app's screenshots for the README, the landing page and the
stores: each on the app's own colours, in a phone outline, under a short
caption saying what it shows.

  python3 tool/make_store_images.py [screenshots/] [site/images/screens/]

The screenshots come from integration_test/store_screenshots_test.dart
(screenshots/shot-NN-name.png). Captions are below, one per shot; a shot
without one is skipped.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "screenshots"
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "site" / "images" / "screens"
UI_FONT = ROOT / "assets/fonts/NotoSans-Variable.ttf"
AR_FONT = ROOT / "assets/fonts/NotoKufiArabic-Variable.ttf"

# The app's palette (lib/core/theme/app_colors.dart).
EMERALD = (23, 107, 91)
ACCENT = (33, 138, 115)
MINT = (104, 198, 168)
GOLD = (183, 154, 91)
CREAM = (247, 248, 244)
MINT_PALE = (220, 239, 232)
INK = (24, 32, 29)
NIGHT = (3, 16, 12)
NIGHT_GREEN = (16, 48, 40)

# shot name -> (headline, line under it, dark background?, Arabic?)
CAPTIONS = {
    "01-home-light": ("Your daily Quran companion", "Daily ayah, continue reading, today's revision", False, False),
    "02-mushaf-light": ("The Madinah Mushaf", "Every page as printed — crisp on any screen", False, False),
    "03-listening-dark": ("Listen to 18 reciters", "The ayah being recited lights up and follows", True, False),
    "05b-recite-marks-dark": ("Every word, checked", "Recite from the page: right in green, mistakes in red", True, False),
    "06b-pronunciation-dark": ("Hears the vowel you said", "On the hamza: ḍamma expected, fatḥa heard", True, False),
    "10b-hide-recite-dark": ("Recite it from memory", "Each word appears as you say it right", True, False),
    "17-translations-light": ("Translations, with footnotes", "Rowwad, Noor, Junagarhi and more — in 18 languages", False, False),
    "18-quran-tab-light": ("Every surah, as the Mushaf writes it", "Names in calligraphy, glass over a sky of the hour", False, False),
    "04-ayah-mode-light": ("Understand every word", "Word meanings, transliteration and translation", False, False),
    "05-follow-along-light": ("Recite after the reciter", "Follow along: listen, then it's your turn", False, False),
    "06-tajweed-settings-light": ("Tajweed feedback", "Madd, qalqala, ghunnah, ikhfāʾ, iqlāb — checked as you recite", False, False),
    "07-search-light": ("Find any ayah, offline", "Search the Arabic text and translations", False, False),
    "08-ayah-mode-dark": ("Tafsir beside every ayah", "Translations in 18 languages, tafsir in 13", True, False),
    "09-view-settings-dark": ("Make it yours", "4 Quran fonts, text size, what each ayah shows", True, False),
    "10-hide-mode-dark": ("Memorize from memory", "Words stay hidden until you recite them", True, False),
    "11-mushaf-sepia-passages": ("Read your way", "Light, warm, sepia, dark and black pages", False, False),
    "12-memorize-dark": ("A plan that remembers", "Spaced revision of everything you've memorized", True, False),
    "13-progress-dark": ("See your progress", "Every page you've memorized, at a glance", True, False),
    "14-settings-dark": ("19 languages, many themes", "Light and dark, warm, sepia, black — your colours", True, False),
    "15-home-arabic-light": ("بالعربية أيضًا", "تسع عشرة لغة، منها العربية والأردية والفارسية", False, True),
    "16-ayah-mode-arabic-light": ("افهم كل كلمة", "معاني الكلمات والترجمة والتفسير", False, True),
}

W, H = 1242, 2208  # the canvas (9:16)
PHONE_W = 880


def font(path, size, weight="Regular"):
    f = ImageFont.truetype(str(path), size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def gradient(top, bottom):
    img = Image.new("RGB", (W, H), top)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        c = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = c
    return img


def glow(img, centre, radius, colour, alpha):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = centre
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=colour + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(radius // 2))
    img.alpha_composite(layer)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def wrap(draw, text, f, width):
    words, lines, line = text.split(), [], ""
    for w in words:
        trial = (line + " " + w).strip()
        if draw.textlength(trial, font=f) <= width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = w
    if line:
        lines.append(line)
    return lines


def frame(shot: Path, headline, sub, dark, arabic):
    if dark:
        bg = gradient(NIGHT, NIGHT_GREEN).convert("RGBA")
        glow(bg, (W // 2, int(H * 0.62)), 520, ACCENT, 70)
        head_c, sub_c, bezel = (236, 242, 239), MINT, (8, 12, 10)
    else:
        bg = gradient(CREAM, MINT_PALE).convert("RGBA")
        glow(bg, (W // 2, int(H * 0.64)), 520, MINT, 60)
        head_c, sub_c, bezel = INK, EMERALD, (24, 32, 29)
    d = ImageDraw.Draw(bg)

    # The caption: headline, then its line, centred.
    face = AR_FONT if arabic else UI_FONT
    hf, sf = font(face, 78, "Bold"), font(face, 40, "Regular")
    direction = "rtl" if arabic else None
    y = 120
    for line in wrap(d, headline, hf, W - 160):
        d.text((W // 2, y), line, font=hf, fill=head_c, anchor="ma", direction=direction)
        y += 96
    y += 14
    for line in wrap(d, sub, sf, W - 200):
        d.text((W // 2, y), line, font=sf, fill=sub_c, anchor="ma", direction=direction)
        y += 54
    # A small gold rule under the caption.
    d.rounded_rectangle((W // 2 - 40, y + 18, W // 2 + 40, y + 24), 3, fill=GOLD)

    # The phone: the screenshot in a bezel, a soft shadow below it.
    screen = Image.open(shot).convert("RGB")
    sh = round(screen.height * PHONE_W / screen.width)
    screen = screen.resize((PHONE_W, sh), Image.LANCZOS)
    top = max(y + 70, H - sh - 40)
    pad = 16
    bx = (W - PHONE_W) // 2 - pad
    shadow = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (bx + 10, top + 30, bx + PHONE_W + 2 * pad - 10, top + sh + 2 * pad + 40),
        78, fill=(0, 0, 0, 120 if dark else 70))
    bg.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(36)))
    ImageDraw.Draw(bg).rounded_rectangle(
        (bx, top, bx + PHONE_W + 2 * pad, top + sh + 2 * pad), 76, fill=bezel)
    bg.alpha_composite(rounded(screen, 60), (bx + pad, top + pad))
    return bg.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = 0
    # The app's own screenshots, and those taken by hand during a real
    # recitation (tool/store_media/: a script can't recite).
    shots = sorted([*SRC.glob("shot-*.png"), *(ROOT / "tool/store_media").glob("shot-*.png")])
    for shot in shots:
        name = shot.stem[len("shot-"):]
        if name not in CAPTIONS:
            print("no caption, skipped:", name)
            continue
        img = frame(shot, *CAPTIONS[name])
        img.save(OUT / f"{name}.webp", "WEBP", quality=86, method=6)
        made += 1
    print(f"{made} images in {OUT}")


if __name__ == "__main__":
    main()
