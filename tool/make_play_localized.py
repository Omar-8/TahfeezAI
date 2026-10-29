#!/usr/bin/env python3
"""Google Play's phone screenshots for each listing language: the same 8
shots as the English listing (make_play_listing.py's PHONE), framed by
make_store_images.py under captions in that language. The app inside stays
in English, but for Arabic's Home and Ayah mode: those the screenshot test
takes in Arabic too.

  python3 tool/make_play_localized.py   # -> store/play/graphics/<language>/phoneScreenshots/
"""
from pathlib import Path

import make_store_images as msi
from make_play_listing import PHONE

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store/play/graphics"
NOTO = Path("/usr/share/fonts/truetype/noto")  # system Noto: Bengali, and Cyrillic

# Shots taken with the app in a language, in place of the English ones.
IN_LANGUAGE = {"ar": {"01-home-light": "15-home-arabic-light", "04-ayah-mode-light": "16-ayah-mode-arabic-light"}}

# Right-to-left languages: captions in the Arabic font.
RTL = {"ar", "ur", "fa"}

# language -> shot -> (headline, line under it), in PHONE's order.
CAPTIONS = {
    "ar": [
        ("كل كلمة تُراجَع", "سمِّع من الصفحة: الصحيح بالأخضر والخطأ بالأحمر"),
        ("يسمع الحركة التي نطقتها", "على الهمزة: المتوقَّع ضمّة، والمسموع فتحة"),
        ("سمِّع من حفظك", "تظهر كل كلمة حين تنطقها صحيحة"),
        ("رفيقك اليومي مع القرآن", "آية اليوم، ومتابعة القراءة، ومراجعة اليوم"),
        ("كل سورة كما يكتبها المصحف", "الأسماء بالخط، وبطاقات زجاجية فوق سماء الساعة"),
        ("مصحف المدينة", "كل صفحة كما طُبعت، واضحة على أي شاشة"),
        ("افهم كل كلمة", "معاني الكلمات والنطق والترجمة"),
        ("تابع تقدّمك", "كل صفحة حفظتها، في لمحة"),
    ],
    "de-DE": [
        ("Jedes Wort geprüft", "Von der Seite rezitieren: richtig in Grün, Fehler in Rot"),
        ("Hört den Vokal, den du sprichst", "Auf der Hamza: Ḍamma erwartet, Fatḥa gehört"),
        ("Auswendig rezitieren", "Jedes Wort erscheint, wenn du es richtig sprichst"),
        ("Dein täglicher Koran-Begleiter", "Aya des Tages, Weiterlesen, heutige Wiederholung"),
        ("Jede Sure, wie der Mushaf sie schreibt", "Namen in Kalligrafie, Glas über dem Himmel der Stunde"),
        ("Der Madinah-Mushaf", "Jede Seite wie gedruckt – scharf auf jedem Bildschirm"),
        ("Verstehe jedes Wort", "Wortbedeutungen, Umschrift und Übersetzung"),
        ("Sieh deinen Fortschritt", "Jede auswendig gelernte Seite auf einen Blick"),
    ],
    "fr-FR": [
        ("Chaque mot vérifié", "Récitez depuis la page : juste en vert, erreurs en rouge"),
        ("Entend la voyelle prononcée", "Sur la hamza : ḍamma attendue, fatḥa entendue"),
        ("Récitez de mémoire", "Chaque mot apparaît quand vous le dites juste"),
        ("Votre compagnon coranique quotidien", "Verset du jour, reprise de lecture, révision du jour"),
        ("Chaque sourate, telle que l'écrit le Mushaf", "Noms en calligraphie, verre sur le ciel de l'heure"),
        ("Le Mushaf de Médine", "Chaque page telle qu'imprimée, nette sur tout écran"),
        ("Comprenez chaque mot", "Sens des mots, translittération et traduction"),
        ("Suivez vos progrès", "Chaque page mémorisée, d'un coup d'œil"),
    ],
    "es-ES": [
        ("Cada palabra, revisada", "Recita desde la página: aciertos en verde, errores en rojo"),
        ("Oye la vocal que dijiste", "Sobre la hamza: se esperaba ḍamma, se oyó fatḥa"),
        ("Recita de memoria", "Cada palabra aparece cuando la dices bien"),
        ("Tu compañero diario del Corán", "Aleya del día, seguir leyendo, repaso de hoy"),
        ("Cada sura, como la escribe el Mushaf", "Nombres en caligrafía, cristal sobre el cielo de la hora"),
        ("El Mushaf de Medina", "Cada página tal como está impresa, nítida en cualquier pantalla"),
        ("Entiende cada palabra", "Significados, transliteración y traducción"),
        ("Mira tu progreso", "Cada página memorizada, de un vistazo"),
    ],
    "ru-RU": [
        ("Каждое слово проверено", "Читайте со страницы: верное зелёным, ошибки красным"),
        ("Слышит, какую огласовку вы сказали", "На хамзе: ожидалась дамма, услышана фатха"),
        ("Читайте наизусть", "Каждое слово появляется, когда вы произносите его верно"),
        ("Ваш ежедневный спутник с Кораном", "Аят дня, продолжение чтения, повторение на сегодня"),
        ("Каждая сура — как в мусхафе", "Названия каллиграфией, стекло над небом этого часа"),
        ("Мединский мусхаф", "Каждая страница как в печати — чётко на любом экране"),
        ("Понимайте каждое слово", "Значения слов, транслитерация и перевод"),
        ("Следите за прогрессом", "Каждая выученная страница — с первого взгляда"),
    ],
    "tr-TR": [
        ("Her kelime kontrol edilir", "Sayfadan oku: doğrular yeşil, hatalar kırmızı"),
        ("Söylediğin harekeyi duyar", "Hemze üzerinde: ötre beklendi, üstün duyuldu"),
        ("Ezberden oku", "Her kelime doğru söylediğinde açılır"),
        ("Günlük Kur'an arkadaşın", "Günün ayeti, okumaya devam, bugünün tekrarı"),
        ("Her sure, Mushaf'ın yazdığı gibi", "Hat ile sure adları, saatin gökyüzü üzerinde cam"),
        ("Medine Mushafı", "Her sayfa basıldığı gibi, her ekranda net"),
        ("Her kelimeyi anla", "Kelime anlamları, okunuş ve meal"),
        ("İlerlemeni gör", "Ezberlediğin her sayfa bir bakışta"),
    ],
    "id": [
        ("Setiap kata diperiksa", "Baca dari halaman: benar hijau, salah merah"),
        ("Mendengar harakat yang Anda ucapkan", "Pada hamzah: diharapkan ḍammah, terdengar fatḥah"),
        ("Setor hafalan", "Setiap kata muncul saat Anda mengucapkannya dengan benar"),
        ("Teman Al-Qur'an harian Anda", "Ayat hari ini, lanjut membaca, murajaah hari ini"),
        ("Setiap surah, seperti tertulis di mushaf", "Nama berkaligrafi, kaca di atas langit sesuai waktu"),
        ("Mushaf Madinah", "Setiap halaman seperti cetakannya, tajam di layar mana pun"),
        ("Pahami setiap kata", "Arti kata, transliterasi, dan terjemahan"),
        ("Lihat kemajuan Anda", "Setiap halaman yang Anda hafal, sekilas pandang"),
    ],
    "ms": [
        ("Setiap perkataan disemak", "Baca dari halaman: betul hijau, salah merah"),
        ("Mendengar baris yang anda sebut", "Pada hamzah: dijangka ḍammah, didengar fatḥah"),
        ("Tasmik dari ingatan", "Setiap perkataan muncul apabila anda menyebutnya dengan betul"),
        ("Teman Al-Quran harian anda", "Ayat hari ini, sambung bacaan, ulang kaji hari ini"),
        ("Setiap surah, seperti ditulis dalam mushaf", "Nama dalam khat, kaca di atas langit mengikut waktu"),
        ("Mushaf Madinah", "Setiap halaman seperti cetakannya, jelas pada mana-mana skrin"),
        ("Fahami setiap perkataan", "Makna perkataan, transliterasi dan terjemahan"),
        ("Lihat kemajuan anda", "Setiap halaman yang anda hafal, sepintas lalu"),
    ],
    "ur": [
        ("ہر لفظ کی جانچ", "صفحے سے پڑھیں: درست سبز، غلطیاں سرخ"),
        ("جو حرکت آپ نے ادا کی، وہ سنتا ہے", "ہمزہ پر: پیش متوقع تھا، زبر سنا گیا"),
        ("زبانی سنائیں", "ہر لفظ درست ادا کرنے پر ظاہر ہوتا ہے"),
        ("قرآن کا روزانہ ساتھی", "آج کی آیت، پڑھائی جاری رکھیں، آج کی دہرائی"),
        ("ہر سورت، جیسے مصحف میں لکھی ہے", "نام خطاطی میں، وقت کے آسمان پر شیشے جیسے کارڈ"),
        ("مدینہ مصحف", "ہر صفحہ جیسا چھپا ہے، ہر اسکرین پر واضح"),
        ("ہر لفظ سمجھیں", "الفاظ کے معانی، تلفظ اور ترجمہ"),
        ("اپنی پیش رفت دیکھیں", "ہر حفظ شدہ صفحہ، ایک نظر میں"),
    ],
    "fa": [
        ("هر کلمه بررسی می‌شود", "از روی صفحه بخوانید: درست سبز، خطا قرمز"),
        ("حرکتی را که گفتید می‌شنود", "روی همزه: ضمه انتظار می‌رفت، فتحه شنیده شد"),
        ("از حفظ بخوانید", "هر کلمه با ادای درستش ظاهر می‌شود"),
        ("همراه روزانهٔ قرآنی شما", "آیهٔ روز، ادامهٔ قرائت، مرور امروز"),
        ("هر سوره، همان‌طور که مصحف می‌نویسد", "نام‌ها با خوشنویسی، شیشه بر آسمانِ همان ساعت"),
        ("مصحف مدینه", "هر صفحه مانند نسخهٔ چاپی، روشن در هر صفحه‌نمایشی"),
        ("هر کلمه را بفهمید", "معنی کلمات، آوانویسی و ترجمه"),
        ("پیشرفت خود را ببینید", "هر صفحه‌ای که حفظ کرده‌اید، در یک نگاه"),
    ],
    "bn-BD": [
        ("প্রতিটি শব্দ যাচাই হয়", "পৃষ্ঠা দেখে পড়ুন: সঠিক সবুজে, ভুল লালে"),
        ("আপনার উচ্চারিত হরকত শোনে", "হামযার ওপর: পেশ প্রত্যাশিত, যবর শোনা গেছে"),
        ("মুখস্থ থেকে তিলাওয়াত", "সঠিকভাবে বললেই প্রতিটি শব্দ দেখা যায়"),
        ("আপনার প্রতিদিনের কুরআন সঙ্গী", "আজকের আয়াত, পড়া চালিয়ে যান, আজকের পুনরাবৃত্তি"),
        ("প্রতিটি সূরা, মুসহাফের লেখায়", "ক্যালিগ্রাফিতে নাম, সময়ের আকাশের ওপর কাচ"),
        ("মদিনা মুসহাফ", "প্রতিটি পৃষ্ঠা ছাপার মতোই, যেকোনো স্ক্রিনে স্পষ্ট"),
        ("প্রতিটি শব্দ বুঝুন", "শব্দার্থ, উচ্চারণ ও অনুবাদ"),
        ("আপনার অগ্রগতি দেখুন", "মুখস্থ করা প্রতিটি পৃষ্ঠা, এক নজরে"),
    ],
    "sw": [
        ("Kila neno linakaguliwa", "Soma kutoka ukurasani: sahihi kijani, makosa mekundu"),
        ("Inasikia irabu uliyotamka", "Juu ya hamza: ḍamma ilitarajiwa, fatḥa imesikika"),
        ("Soma kwa moyo", "Kila neno linaonekana unapolitamka sawasawa"),
        ("Mwenzako wa kila siku wa Qur'ani", "Aya ya leo, endelea kusoma, marudio ya leo"),
        ("Kila sura, kama Msahafu unavyoiandika", "Majina kwa hati nzuri, kioo juu ya anga la saa hiyo"),
        ("Msahafu wa Madina", "Kila ukurasa kama ulivyochapishwa, wazi kwenye skrini yoyote"),
        ("Elewa kila neno", "Maana ya maneno, matamshi na tafsiri"),
        ("Ona maendeleo yako", "Kila ukurasa uliohifadhi, kwa mtazamo mmoja"),
    ],
    "kk": [
        ("Әр сөз тексеріледі", "Беттен оқыңыз: дұрысы жасыл, қатесі қызыл"),
        ("Айтқан харакатыңызды естиді", "Хамзада: дамма күтілді, фатха естілді"),
        ("Жатқа оқыңыз", "Әр сөз дұрыс айтқанда пайда болады"),
        ("Күнделікті Құран серігіңіз", "Күн аяты, оқуды жалғастыру, бүгінгі қайталау"),
        ("Әр сүре мұсхафтағыдай", "Аттары каллиграфиямен, сағат аспанының үстінде шыны"),
        ("Мединалық мұсхаф", "Әр бет басылғандай, кез келген экранда анық"),
        ("Әр сөзді түсініңіз", "Сөз мағыналары, транслитерация және аударма"),
        ("Прогресіңізді көріңіз", "Жаттаған әр бетіңіз бір қарағанда"),
    ],
}


def source(name):
    for d in (ROOT / "screenshots", ROOT / "tool/store_media"):
        if (d / f"shot-{name}.png").exists():
            return d / f"shot-{name}.png"
    raise FileNotFoundError(name)


def main():
    plain_font = msi.font
    for lang, captions in CAPTIONS.items():
        assert len(captions) == len(PHONE), lang
        # Bengali and Cyrillic (the bundled Noto Sans has neither): the
        # system's Noto, two static files each (no weight axis).
        family = {"bn-BD": "NotoSansBengali", "ru-RU": "NotoSans", "kk": "NotoSans"}.get(lang)
        if family:
            msi.font = lambda path, size, weight="Regular", family=family: plain_font(
                NOTO / f"{family}-{'Bold' if weight == 'Bold' else 'Regular'}.ttf", size)
        else:
            msi.font = plain_font
        out = OUT / lang / "phoneScreenshots"
        out.mkdir(parents=True, exist_ok=True)
        for old in out.glob("*.png"):
            old.unlink()
        for i, (name, (head, sub)) in enumerate(zip(PHONE, captions), 1):
            dark = name.endswith("-dark")
            shot = source(IN_LANGUAGE.get(lang, {}).get(name, name))
            img = msi.frame(shot, head, sub, dark, lang in RTL)
            img.save(out / f"{i:02d}-{name}.png", optimize=True)
        print(out.relative_to(ROOT), len(PHONE))


if __name__ == "__main__":
    main()
