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
ENGLISH_MORE = [
    "10-hide-mode-dark", "05-follow-along-light", "18-quran-tab-light",
    "08-ayah-mode-dark", "23-calendar-light",
]

# Every language: the recitation shots too (owner, 2026-11-15), captioned.
MORE = {
    "ar": {
        "10-hide-mode-dark": ("سمِّع من حفظك", "تبقى الكلمات مخفية حتى تتلوها"),
        "05-follow-along-light": ("سمِّع بعد القارئ", "المتابعة: استمع، ثم دورك"),
    },
    "de-DE": {
        "10-hide-mode-dark": ("Aus dem Gedächtnis rezitieren", "Die Wörter bleiben verborgen, bis du sie rezitierst"),
        "05-follow-along-light": ("Nach dem Rezitator rezitieren", "Mitlesen: zuhören, dann bist du dran"),
    },
    "fr-FR": {
        "10-hide-mode-dark": ("Récitez de mémoire", "Les mots restent cachés jusqu'à ce que vous les récitiez"),
        "05-follow-along-light": ("Récitez après le récitateur", "Suivre : écoutez, puis c'est votre tour"),
    },
    "es-ES": {
        "10-hide-mode-dark": ("Recita de memoria", "Las palabras siguen ocultas hasta que las recitas"),
        "05-follow-along-light": ("Recita después del recitador", "Seguir: escucha y luego es tu turno"),
    },
    "ru-RU": {
        "10-hide-mode-dark": ("Читайте наизусть", "Слова скрыты, пока вы их не прочтёте"),
        "05-follow-along-light": ("Читайте вслед за чтецом", "Следование: послушайте, затем ваша очередь"),
    },
    "tr-TR": {
        "10-hide-mode-dark": ("Ezberden okuyun", "Kelimeler siz okuyana kadar gizli kalır"),
        "05-follow-along-light": ("Kârinin ardından okuyun", "Takip: dinleyin, sonra sıra sizde"),
    },
    "id": {
        "10-hide-mode-dark": ("Bacalah dari hafalan", "Kata tetap tersembunyi sampai Anda membacanya"),
        "05-follow-along-light": ("Membaca mengikuti qari", "Ikuti: dengarkan, lalu giliran Anda"),
    },
    "ms": {
        "10-hide-mode-dark": ("Baca dari hafalan", "Perkataan kekal tersembunyi sehingga anda membacanya"),
        "05-follow-along-light": ("Baca selepas qari", "Ikut: dengar, kemudian giliran anda"),
    },
    "ur": {
        "10-hide-mode-dark": ("حفظ سے تلاوت کریں", "الفاظ تب تک چھپے رہتے ہیں جب تک آپ تلاوت نہ کریں"),
        "05-follow-along-light": ("قاری کے بعد تلاوت کریں", "ساتھ پڑھیں: سنیں، پھر آپ کی باری"),
    },
    "fa": {
        "10-hide-mode-dark": ("از حفظ تلاوت کنید", "کلمه‌ها تا وقتی تلاوت نکنید پنهان می‌مانند"),
        "05-follow-along-light": ("بعد از قاری تلاوت کنید", "همراهی: گوش دهید، سپس نوبت شماست"),
    },
    "bn-BD": {
        "10-hide-mode-dark": ("মুখস্থ থেকে তিলাওয়াত করুন", "আপনি তিলাওয়াত না করা পর্যন্ত শব্দগুলো লুকানো থাকে"),
        "05-follow-along-light": ("কারীর পরে তিলাওয়াত করুন", "অনুসরণ: শুনুন, তারপর আপনার পালা"),
    },
    "sw": {
        "10-hide-mode-dark": ("Soma kwa moyo", "Maneno yanabaki yamefichwa hadi uyasome"),
        "05-follow-along-light": ("Soma baada ya msomaji", "Fuatisha: sikiliza, kisha ni zamu yako"),
    },
    "kk": {
        "10-hide-mode-dark": ("Жатқа оқыңыз", "Сөздер сіз оқығанша жасырын тұрады"),
        "05-follow-along-light": ("Қарыдан кейін оқыңыз", "Бірге оқу: тыңдаңыз, сосын сіздің кезегіңіз"),
    },
    "nl-NL": {
        "10-hide-mode-dark": ("Reciteer uit je hoofd", "Woorden blijven verborgen tot je ze reciteert"),
        "05-follow-along-light": ("Reciteer na de reciteur", "Meelezen: luister, dan ben jij aan de beurt"),
    },
    "da-DK": {
        "10-hide-mode-dark": ("Reciter udenad", "Ordene forbliver skjulte, til du reciterer dem"),
        "05-follow-along-light": ("Reciter efter recitatoren", "Følg med: lyt, så er det din tur"),
    },
    "el-GR": {
        "10-hide-mode-dark": ("Απαγγείλετε από μνήμης", "Οι λέξεις μένουν κρυφές μέχρι να τις απαγγείλετε"),
        "05-follow-along-light": ("Απαγγείλετε μετά τον απαγγέλτη", "Ακολουθήστε: ακούστε, μετά σειρά σας"),
    },
    "ja-JP": {
        "10-hide-mode-dark": ("暗記して読誦", "読誦するまで語は隠れたまま"),
        "05-follow-along-light": ("読誦者に続いて読誦", "一緒に：聞いて、次はあなたの番"),
    },
    "ko-KR": {
        "10-hide-mode-dark": ("외워서 낭송하세요", "낭송할 때까지 단어가 숨겨져 있어요"),
        "05-follow-along-light": ("낭송자를 따라 낭송하세요", "따라 하기: 듣고 나서 당신 차례"),
    },
    "pt-BR": {
        "10-hide-mode-dark": ("Recite de memória", "As palavras ficam ocultas até você recitá-las"),
        "05-follow-along-light": ("Recite depois do recitador", "Acompanhar: ouça e depois é a sua vez"),
    },
    "zh-CN": {
        "10-hide-mode-dark": ("凭记忆诵读", "词语保持隐藏，直到你诵读出来"),
        "05-follow-along-light": ("跟随诵读者诵读", "跟读：先听，再轮到你"),
    },
}

# The order on the store: recitation first (owner, 2026-11-15).
ORDER = [
    "10-hide-mode-dark", "05-follow-along-light", "01-home-light",
    "20-prayer-times-light", "21-athkar-light", "22-habits-dark", "02-mushaf-light",
    "18-quran-tab-light", "08-ayah-mode-dark", "23-calendar-light",
]


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
            mpl.use_font(lang, plain_font)
            if captions is None:
                shots = [(name, msi.CAPTIONS[name][:2]) for name in SHARED + ENGLISH_MORE]
            else:
                by_name = {**dict(zip(PHONE, captions)), **MORE[lang]}
                shots = [(name, by_name[name]) for name in SHARED + list(MORE[lang])]
            shots.sort(key=lambda shot: ORDER.index(shot[0]))
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
