#!/usr/bin/env python3
"""The App Store's screenshots, for each listing language: framed by
make_store_images.py at the sizes App Store Connect asks for, from
screenshots the store screenshot test took on simulators
(.github/workflows/ios-screenshots.yml: <shots>/iphone/, ipad/, duo/):

- iphone-6.3   1206 x 2622  (the one iPhone size required)
- iphone-6.9   1320 x 2868
- ipad-13      2064 x 2752  (required: the app runs on iPad)
- duo-inner    2007 x 2853  (iPhone Duo, optional until April 2027)
- duo-outer    1398 x 2034

  python3 tool/make_app_store_images.py [screenshots/] [store/app_store/screenshots/]

Only shots taken on iOS: the Play listing's recitation shots were taken by
hand on Android (tool/store_media/), whose status bar the App Store does not
allow. Captions are the Play listing's, in each language; English has a few
more shots.
"""
import sys
from pathlib import Path

import make_play_localized as mpl
import make_store_images as msi
from make_play_listing import PHONE

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "screenshots"
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "store/app_store/screenshots"

# App Store size -> (the simulator's shots, canvas width, height, the
# screenshot's width on it)
DEVICES = {
    "iphone-6.3": ("iphone", 1206, 2622, 854),
    "iphone-6.9": ("iphone", 1320, 2868, 935),
    "ipad-13": ("ipad", 2064, 2752, 1380),
    "duo-inner": ("duo", 2007, 2853, 1390),
    "duo-outer": ("duo", 1398, 2034, 1000),
}

# The Play listing's shots that iOS takes too (its captions in each language).
SHARED = [name for name in PHONE if not (ROOT / "tool/store_media" / f"shot-{name}.png").exists()]

# English only: more of the app (make_store_images.py's captions).
ENGLISH_MORE = ["10-hide-mode-dark", "05-follow-along-light", "08-ayah-mode-dark", "07-search-light"]


def main():
    plain_font = msi.font
    languages = {"en-US": None, **mpl.CAPTIONS}
    for device, (shots_of, w, h, phone_w) in DEVICES.items():
        src = SRC / shots_of
        if not src.is_dir():
            print("no screenshots for", device, "in", src)
            continue
        msi.W, msi.H, msi.PHONE_W = w, h, phone_w
        for lang, captions in languages.items():
            family = {"bn-BD": "NotoSansBengali", "ru-RU": "NotoSans", "kk": "NotoSans"}.get(lang)
            if family:
                msi.font = lambda path, size, weight="Regular", family=family: plain_font(
                    mpl.NOTO / f"{family}-{'Bold' if weight == 'Bold' else 'Regular'}.ttf", size)
            else:
                msi.font = plain_font
            if captions is None:
                shots = [(name, msi.CAPTIONS[name][:2]) for name in SHARED + ENGLISH_MORE]
            else:
                by_name = dict(zip(PHONE, captions))
                shots = [(name, by_name[name]) for name in SHARED]
            out = OUT / lang / device
            out.mkdir(parents=True, exist_ok=True)
            for old in out.glob("*.png"):
                old.unlink()
            made = 0
            for i, (name, (head, sub)) in enumerate(shots, 1):
                shot = src / f"shot-{mpl.IN_LANGUAGE.get(lang, {}).get(name, name)}.png"
                if not shot.exists():
                    print("missing:", shot)
                    continue
                img = msi.frame(shot, head, sub, name.endswith("-dark"), lang in mpl.RTL)
                assert img.size == (w, h), img.size
                img.save(out / f"{i:02d}-{name}.png", optimize=True)
                made += 1
            print(out, made)


if __name__ == "__main__":
    main()
