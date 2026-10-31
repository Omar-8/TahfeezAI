#!/usr/bin/env python3
"""The App Store product page's creative assets (App Store Connect →
version → Header and Search Results):

- header.png          3840 x 1646 (21:9): three of the app's screens, no
                      text (the store sets the icon and name over it)
- search_results.png  3840 x 2560 (3:2): a short line over the same screens

  python3 tool/make_app_store_header.py   # -> store/app_store/graphics/

On the app's emerald, under a faint eight-pointed star lattice. The
screens are the app's own (screenshots/, tool/store_media/), their empty
status-bar strip cut off. No transparency (the store refuses it).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store/app_store/graphics"
UI_FONT = ROOT / "assets/fonts/NotoSans-Variable.ttf"

EMERALD = (23, 107, 91)
NIGHT_GREEN = (16, 48, 40)
MINT = (104, 198, 168)
CREAM = (247, 248, 244)
GOLD = (183, 154, 91)

# Left, centre (in front), right.
SCREENS = [
    ROOT / "screenshots/shot-02-mushaf-light.png",
    ROOT / "tool/store_media/shot-05b-recite-marks-dark.png",
    ROOT / "screenshots/shot-04-ayah-mode-light.png",
]
STATUS_STRIP = 96  # the screenshots' empty top, in their pixels


def font(size, weight=700):
    f = ImageFont.truetype(str(UI_FONT), size)
    try:
        f.set_variation_by_axes([weight])
    except OSError:
        pass
    return f


def background(w, h):
    # A soft diagonal from the night green (top left) into emerald, drawn
    # small and enlarged (smooth either way).
    sw, sh = 384, max(2, round(384 * h / w))
    grad = Image.new("L", (sw, sh))
    grad.putdata([min(255, int(255 * (x / sw * 0.6 + y / sh * 0.4))) for y in range(sh) for x in range(sw)])
    grad = grad.resize((w, h), Image.BICUBIC)
    img = Image.composite(Image.new("RGB", (w, h), EMERALD), Image.new("RGB", (w, h), NIGHT_GREEN), grad)

    # The lattice: an eight-pointed star (two squares, one turned 45°) at
    # every point of a grid, in thin pale lines.
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = round(h / 5.5)
    r = step * 0.42
    for gy in range(-1, h // step + 2):
        for gx in range(-1, w // step + 2):
            cx, cy = gx * step + (step // 2 if gy % 2 else 0), gy * step
            for turn in (0, 45):
                pts = [
                    (cx + r * math.cos(math.radians(turn + 45 + 90 * k)),
                     cy + r * math.sin(math.radians(turn + 45 + 90 * k)))
                    for k in range(4)
                ]
                d.polygon(pts, outline=(*MINT, 26), width=max(2, h // 700))
    img = img.convert("RGBA")
    img.alpha_composite(layer)
    return img


def phone(path, width, dark_bezel=(10, 16, 14)):
    shot = Image.open(path).convert("RGB")
    shot = shot.crop((0, STATUS_STRIP, shot.width, shot.height))
    sh = round(shot.height * width / shot.width)
    shot = shot.resize((width, sh), Image.LANCZOS)
    pad = round(width * 0.035)
    radius = round(width * 0.11)
    body = Image.new("RGBA", (width + 2 * pad, sh + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, *body.size), radius + pad, fill=dark_bezel + (255,))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *shot.size), radius, fill=255)
    body.paste(shot, (pad, pad), mask)
    return body


def place(img, body, x, y):
    # A soft shadow under the phone, then the phone; x is its centre.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    left = round(x - body.width / 2)
    blur = body.width // 10
    ImageDraw.Draw(shadow).rounded_rectangle(
        (left + blur // 2, y + blur, left + body.width - blur // 2, y + body.height + blur),
        body.width // 8, fill=(0, 0, 0, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    img.alpha_composite(body, (left, y))


def screens(img, top, centre_w, side_w, spread):
    w = img.width
    side_top = top + round(centre_w * 0.28)
    place(img, phone(SCREENS[0], side_w), w // 2 - spread, side_top)
    place(img, phone(SCREENS[2], side_w), w // 2 + spread, side_top)
    place(img, phone(SCREENS[1], centre_w), w // 2, top)


def header():
    w, h = 3840, 1646
    img = background(w, h)
    # The screens rise from the bottom edge, in the middle (narrow screens
    # show the header's centre).
    screens(img, top=150, centre_w=720, side_w=620, spread=780)
    return img.convert("RGB")


def search_results():
    w, h = 3840, 2560
    img = background(w, h)
    d = ImageDraw.Draw(img)
    d.text((w // 2, 170), "Recite from memory.", font=font(190, 800), fill=CREAM, anchor="ma")
    d.text((w // 2, 400), "Every word checked.", font=font(190, 800), fill=CREAM, anchor="ma")
    d.rounded_rectangle((w // 2 - 120, 700, w // 2 + 120, 712), 6, fill=GOLD)
    d.text((w // 2, 770), "Free · Offline · No ads · No account", font=font(96, 600), fill=MINT, anchor="ma")
    screens(img, top=980, centre_w=860, side_w=740, spread=930)
    return img.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in (("header", header), ("search_results", search_results)):
        img = make()
        path = OUT / f"{name}.png"
        img.save(path, optimize=True)
        print(path.relative_to(ROOT), img.size, img.mode, f"{path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
