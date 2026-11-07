#!/usr/bin/env python3
"""Google Play's phone screenshots for each listing language: the same 8
shots as the English listing (make_play_listing.py's PHONE), framed by
make_store_images.py under captions in that language. The app inside stays
in English, but for Arabic's Home and Ayah mode: those the screenshot test
takes in Arabic too.

  python3 tool/make_play_localized.py   # -> store/play/graphics/<language>/phoneScreenshots/
"""
from pathlib import Path

from PIL import ImageFont

import make_store_images as msi
from make_play_listing import PHONE

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store/play/graphics"
NOTO = Path("/usr/share/fonts/truetype/noto")  # system Noto: Bengali, Cyrillic, Greek
CJK = Path("/usr/share/fonts/opentype/noto")

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
    "nl-NL": [
        ("Elk woord gecontroleerd", "Reciteer van de pagina: goed in groen, fouten in rood"),
        ("Hoort de klinker die je zegt", "Op de hamza: ḍamma verwacht, fatḥa gehoord"),
        ("Reciteer uit je hoofd", "Elk woord verschijnt als je het goed zegt"),
        ("Je dagelijkse Koran-metgezel", "Vers van de dag, verder lezen, herhaling van vandaag"),
        ("Elke soera zoals de Mushaf haar schrijft", "Namen in kalligrafie, glas boven de lucht van het uur"),
        ("De Mushaf van Medina", "Elke pagina zoals gedrukt, scherp op elk scherm"),
        ("Begrijp elk woord", "Woordbetekenissen, transliteratie en vertaling"),
        ("Zie je voortgang", "Elke gememoriseerde pagina in één oogopslag"),
    ],
    "da-DK": [
        ("Hvert ord kontrolleret", "Reciter fra siden: rigtigt i grønt, fejl i rødt"),
        ("Hører den vokal, du siger", "På hamza: ḍamma forventet, fatḥa hørt"),
        ("Reciter udenad", "Hvert ord vises, når du siger det rigtigt"),
        ("Din daglige Koran-følgesvend", "Dagens vers, fortsæt læsningen, dagens repetition"),
        ("Hver sura, som Mushaf skriver den", "Navne i kalligrafi, glas over timens himmel"),
        ("Medina-Mushaf", "Hver side som trykt, skarp på enhver skærm"),
        ("Forstå hvert ord", "Ordbetydninger, translitteration og oversættelse"),
        ("Se dine fremskridt", "Hver side, du har lært udenad, med ét blik"),
    ],
    "el-GR": [
        ("Κάθε λέξη ελεγμένη", "Απάγγειλε από τη σελίδα: σωστά με πράσινο, λάθη με κόκκινο"),
        ("Ακούει το φωνήεν που λες", "Στη χάμζα: αναμενόταν ντάμμα, ακούστηκε φάτχα"),
        ("Απάγγειλε από μνήμης", "Κάθε λέξη εμφανίζεται όταν τη λες σωστά"),
        ("Ο καθημερινός σύντροφός σου στο Κοράνιο", "Εδάφιο της ημέρας, συνέχεια ανάγνωσης, σημερινή επανάληψη"),
        ("Κάθε σούρα όπως τη γράφει το Μους'χαφ", "Ονόματα σε καλλιγραφία, γυαλί πάνω από τον ουρανό της ώρας"),
        ("Το Μους'χαφ της Μεδίνας", "Κάθε σελίδα όπως τυπώθηκε, καθαρή σε κάθε οθόνη"),
        ("Κατάλαβε κάθε λέξη", "Σημασίες λέξεων, μεταγραφή και μετάφραση"),
        ("Δες την πρόοδό σου", "Κάθε σελίδα που απομνημόνευσες, με μια ματιά"),
    ],
    "ja-JP": [
        ("すべての語をチェック", "ページを見て読誦：正しい語は緑、間違いは赤"),
        ("発音した母音を聞き取る", "ハムザで：ダンマのはずがファトハと聞こえました"),
        ("暗記で読誦", "正しく言うと、語が一つずつ現れます"),
        ("毎日のクルアーンの友", "今日のアーヤ、続きを読む、今日の復習"),
        ("ムスハフの書体でスーラを", "書道のスーラ名、時間帯の空にガラスのカード"),
        ("マディーナのムスハフ", "印刷どおりのページを、どの画面でも鮮明に"),
        ("一語一語を理解", "語の意味、音写、対訳"),
        ("進み具合がひと目で", "暗記したページを一覧で"),
    ],
    "ko-KR": [
        ("모든 단어를 확인", "쪽을 보며 낭송: 맞으면 초록, 틀리면 빨강"),
        ("말한 모음까지 듣습니다", "함자에서: 담마가 맞는데 파트하로 들렸습니다"),
        ("외워서 낭송", "바르게 말하면 단어가 하나씩 나타납니다"),
        ("매일의 꾸란 동반자", "오늘의 아야, 이어 읽기, 오늘의 복습"),
        ("무스하프 서체 그대로의 수라", "서예로 쓴 이름, 시간대 하늘 위의 유리 카드"),
        ("메디나 무스하프", "인쇄된 그대로의 쪽을 어느 화면에서나 선명하게"),
        ("모든 단어를 이해", "단어 뜻, 음역, 번역"),
        ("진행 상황을 한눈에", "외운 쪽을 한눈에"),
    ],
    "pt-BR": [
        ("Cada palavra conferida", "Recite pela página: certo em verde, erros em vermelho"),
        ("Ouve a vogal que você diz", "No hamza: esperado ḍamma, ouvido fatḥa"),
        ("Recite de memória", "Cada palavra aparece quando você a diz certo"),
        ("Seu companheiro diário do Alcorão", "Versículo do dia, continuar lendo, revisão de hoje"),
        ("Cada surata como o Mushaf a escreve", "Nomes em caligrafia, vidro sobre o céu da hora"),
        ("O Mushaf de Medina", "Cada página como impressa, nítida em qualquer tela"),
        ("Entenda cada palavra", "Significados, transliteração e tradução"),
        ("Veja seu progresso", "Cada página memorizada, num relance"),
    ],
    "zh-CN": [
        ("每个词都经过检查", "对照页面诵读：正确为绿色，错误为红色"),
        ("连你读的元音都能听出", "在哈姆宰上：应为合口符，听到的是开口符"),
        ("凭记忆诵读", "读对一个词，就显示一个词"),
        ("你每天的古兰经伙伴", "每日一节、继续阅读、今日复习"),
        ("每一章都如经本所书", "书法章名，玻璃卡片映着此刻的天空"),
        ("麦地那经本", "每一页都与印刷版一致，在任何屏幕上都清晰"),
        ("理解每一个词", "词义、音译和译文"),
        ("一眼看清你的进度", "背记过的每一页，一目了然"),
    ],
}


def source(name):
    for d in (ROOT / "screenshots", ROOT / "tool/store_media"):
        if (d / f"shot-{name}.png").exists():
            return d / f"shot-{name}.png"
    raise FileNotFoundError(name)


def use_font(lang, plain_font):
    """The captions' font for [lang]: Bengali, Cyrillic and Greek (the
    bundled Noto Sans has none) in the system's Noto, two static files each
    (no weight axis); Japanese, Korean and Chinese in the system's Noto Sans
    CJK (its JP, KR and SC faces in one collection); the rest in
    [plain_font]."""
    family = {"bn-BD": "NotoSansBengali", "ru-RU": "NotoSans", "kk": "NotoSans",
              "el-GR": "NotoSans"}.get(lang)
    cjk = {"ja-JP": 0, "ko-KR": 1, "zh-CN": 2}.get(lang)
    if cjk is not None:
        msi.font = lambda path, size, weight="Regular", index=cjk: ImageFont.truetype(
            str(CJK / f"NotoSansCJK-{'Bold' if weight == 'Bold' else 'Regular'}.ttc"),
            size, index=index)
    elif family:
        msi.font = lambda path, size, weight="Regular", family=family: plain_font(
            NOTO / f"{family}-{'Bold' if weight == 'Bold' else 'Regular'}.ttf", size)
    else:
        msi.font = plain_font


def main():
    plain_font = msi.font
    for lang, captions in CAPTIONS.items():
        assert len(captions) == len(PHONE), lang
        use_font(lang, plain_font)
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
