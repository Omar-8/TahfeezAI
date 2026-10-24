#!/usr/bin/env python3
"""Google Play listing graphics from the landing page's media: the phone
screenshots (site/images/screens, framed by make_store_images.py) as PNG,
the 512 px icon as 32-bit PNG, and a 1024 x 500 feature graphic in the
app's colours.

  python3 tool/make_play_listing.py   # -> store/play/graphics/

The listing text is beside it (store/play/listings/<language>/).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SCREENS = ROOT / "site/images/screens"
OUT = ROOT / "store/play/graphics"
UI_FONT = ROOT / "assets/fonts/NotoSans-Variable.ttf"

# The app's palette (lib/core/theme/app_colors.dart), as in make_store_images.py.
EMERALD = (23, 107, 91)
NIGHT = (3, 16, 12)
NIGHT_GREEN = (16, 48, 40)
MINT = (104, 198, 168)
GOLD = (183, 154, 91)
CREAM = (247, 248, 244)

# Play shows up to 8 phone screenshots, in this order: what the app is for
# first (reciting from memory, checked), then reading and listening.
PHONE = [
    "05b-recite-marks-dark",
    "06b-pronunciation-dark",
    "10b-hide-recite-dark",
    "02-mushaf-light",
    "03-listening-dark",
    "04-ayah-mode-light",
    "12-memorize-dark",
    "15-home-arabic-light",
]


def font(size, weight=700):
    f = ImageFont.truetype(str(UI_FONT), size)
    try:
        f.set_variation_by_axes([weight])
    except OSError:
        pass
    return f


def feature_graphic(path):
    w, h = 1024, 500
    # A soft diagonal from the night green (top left) into emerald.
    grad = Image.new("L", (w, h))
    grad.putdata([min(255, int(255 * (x / w * 0.7 + y / h * 0.3))) for y in range(h) for x in range(w)])
    img = Image.composite(Image.new("RGB", (w, h), EMERALD), Image.new("RGB", (w, h), NIGHT_GREEN), grad)
    icon = Image.open(ROOT / "site/images/icon-512.png").convert("RGBA").resize((300, 300), Image.LANCZOS)
    mask = Image.new("L", icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *icon.size), radius=66, fill=255)
    img.paste(icon, (70, (h - 300) // 2), mask)
    d = ImageDraw.Draw(img)
    x = 420
    d.text((x, 118), "Tahfeez AI", font=font(84, 800), fill=CREAM)
    d.text((x, 228), "Memorize the Quran with a", font=font(36, 500), fill=CREAM)
    d.text((x, 274), "listener in your pocket", font=font(36, 500), fill=CREAM)
    d.text((x, 350), "Free · Offline · No ads · No account", font=font(26, 600), fill=MINT)
    d.line((x, 334, x + 120, 334), fill=GOLD, width=3)
    img.save(path, optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    phone = OUT / "phoneScreenshots"
    phone.mkdir(exist_ok=True)
    for old in phone.glob("*.png"):
        old.unlink()
    for i, name in enumerate(PHONE, 1):
        Image.open(SCREENS / f"{name}.webp").convert("RGB").save(phone / f"{i:02d}-{name}.png", optimize=True)
    Image.open(ROOT / "site/images/icon-512.png").convert("RGBA").save(OUT / "icon.png", optimize=True)
    feature_graphic(OUT / "featureGraphic.png")
    for f in sorted(OUT.rglob("*.png")):
        im = Image.open(f)
        print(f.relative_to(ROOT), im.size, im.mode, f"{f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
