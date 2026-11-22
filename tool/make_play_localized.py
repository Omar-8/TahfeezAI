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
    'ar': [
        ('كل كلمة تُراجَع', 'سمِّع من الصفحة: الصحيح بالأخضر والخطأ بالأحمر'),
        ('يسمع الحركة التي نطقتها', 'على الهمزة: المتوقَّع ضمّة، والمسموع فتحة'),
        ('سمِّع من حفظك', 'تظهر كل كلمة حين تنطقها صحيحة'),
        ('رفيقك كل يوم', 'مواقيت الصلاة والتاريخ وآية اليوم ومتابعة القراءة'),
        ('مواقيت الصلاة مع الأذان', 'مواقيت مدينتك — بأذان مكة أو المدينة'),
        ('أذكار الصباح والمساء', 'من حصن المسلم، مع العدّ والصوت'),
        ('حافظ على عاداتك الطيبة', 'الورد والسنن والصيام — مع التذكير'),
        ('مصحف المدينة', 'كل صفحة كما طُبعت، واضحة على أي شاشة'),
    ],
    'de-DE': [
        ('Jedes Wort geprüft', 'Von der Seite rezitieren: richtig in Grün, Fehler in Rot'),
        ('Hört den Vokal, den du sprichst', 'Auf der Hamza: Ḍamma erwartet, Fatḥa gehört'),
        ('Auswendig rezitieren', 'Jedes Wort erscheint, wenn du es richtig sprichst'),
        ('Dein täglicher Begleiter', 'Gebetszeiten, Datum, Vers des Tages und Lesen'),
        ('Gebetszeiten mit Adhan', 'Die Zeiten deiner Stadt — Adhan aus Mekka oder Medina'),
        ('Morgen- und Abend-Adhkar', 'Aus Hisn al-Muslim, gezählt, mit Audio'),
        ('Bleib bei guten Gewohnheiten', 'Wird, Sunna-Gebete, Fasten — mit Erinnerungen'),
        ('Der Madinah-Mushaf', 'Jede Seite wie gedruckt – scharf auf jedem Bildschirm'),
    ],
    'fr-FR': [
        ('Chaque mot vérifié', 'Récitez depuis la page : juste en vert, erreurs en rouge'),
        ('Entend la voyelle prononcée', 'Sur la hamza : ḍamma attendue, fatḥa entendue'),
        ('Récitez de mémoire', 'Chaque mot apparaît quand vous le dites juste'),
        ('Votre compagnon quotidien', 'Heures de prière, date, verset du jour et lecture'),
        ("Les heures de prière, avec l'adhan", "Celles de votre ville — l'adhan de La Mecque ou Médine"),
        ('Adhkar du matin et du soir', 'De Hisn al-Muslim, comptés, avec audio'),
        ('Gardez vos bonnes habitudes', 'Wird, prières sunna, jeûne — avec rappels'),
        ('Le Mushaf de Médine', "Chaque page telle qu'imprimée, nette sur tout écran"),
    ],
    'es-ES': [
        ('Cada palabra, revisada', 'Recita desde la página: aciertos en verde, errores en rojo'),
        ('Oye la vocal que dijiste', 'Sobre la hamza: se esperaba ḍamma, se oyó fatḥa'),
        ('Recita de memoria', 'Cada palabra aparece cuando la dices bien'),
        ('Tu compañero diario', 'Horarios de oración, la fecha, la aleya del día y tu lectura'),
        ('Horarios de oración con adhan', 'Los de tu ciudad — el adhan de La Meca o Medina'),
        ('Adhkar de la mañana y la tarde', 'De Hisn al-Muslim, con contador y audio'),
        ('Mantén tus buenos hábitos', 'Wird, oraciones sunnah, ayuno — con recordatorios'),
        ('El Mushaf de Medina', 'Cada página tal como está impresa, nítida en cualquier pantalla'),
    ],
    'ru-RU': [
        ('Каждое слово проверено', 'Читайте со страницы: верное зелёным, ошибки красным'),
        ('Слышит, какую огласовку вы сказали', 'На хамзе: ожидалась дамма, услышана фатха'),
        ('Читайте наизусть', 'Каждое слово появляется, когда вы произносите его верно'),
        ('Ваш спутник на каждый день', 'Время намаза, дата, аят дня и чтение'),
        ('Время намаза с азаном', 'Время вашего города — азан Мекки или Медины'),
        ('Утренние и вечерние азкары', 'Из «Крепости мусульманина», со счётчиком и аудио'),
        ('Храните добрые привычки', 'Вирд, сунна-намазы, пост — с напоминаниями'),
        ('Мединский мусхаф', 'Каждая страница как в печати — чётко на любом экране'),
    ],
    'tr-TR': [
        ('Her kelime kontrol edilir', 'Sayfadan oku: doğrular yeşil, hatalar kırmızı'),
        ('Söylediğin harekeyi duyar', 'Hemze üzerinde: ötre beklendi, üstün duyuldu'),
        ('Ezberden oku', 'Her kelime doğru söylediğinde açılır'),
        ('Her günkü yol arkadaşınız', 'Namaz vakitleri, tarih, günün ayeti ve okuma'),
        ('Ezanla namaz vakitleri', 'Şehrinizin vakitleri — Mekke veya Medine ezanı'),
        ('Sabah ve akşam zikirleri', "Hısnu'l-Müslim'den, sayaçlı ve sesli"),
        ('İyi alışkanlıklarınızı sürdürün', 'Vird, sünnet namazlar, oruç — hatırlatıcılarla'),
        ('Medine Mushafı', 'Her sayfa basıldığı gibi, her ekranda net'),
    ],
    'id': [
        ('Setiap kata diperiksa', 'Baca dari halaman: benar hijau, salah merah'),
        ('Mendengar harakat yang Anda ucapkan', 'Pada hamzah: diharapkan ḍammah, terdengar fatḥah'),
        ('Setor hafalan', 'Setiap kata muncul saat Anda mengucapkannya dengan benar'),
        ('Teman harian Anda', 'Waktu salat, tanggal, ayat hari ini dan bacaan'),
        ('Waktu salat dengan azan', 'Waktu kota Anda — azan Makkah atau Madinah'),
        ('Zikir pagi dan petang', 'Dari Hisnul Muslim, dihitung, dengan audio'),
        ('Jaga kebiasaan baik', 'Wirid, salat sunah, puasa — dengan pengingat'),
        ('Mushaf Madinah', 'Setiap halaman seperti cetakannya, tajam di layar mana pun'),
    ],
    'ms': [
        ('Setiap perkataan disemak', 'Baca dari halaman: betul hijau, salah merah'),
        ('Mendengar baris yang anda sebut', 'Pada hamzah: dijangka ḍammah, didengar fatḥah'),
        ('Tasmik dari ingatan', 'Setiap perkataan muncul apabila anda menyebutnya dengan betul'),
        ('Teman harian anda', 'Waktu solat, tarikh, ayat hari ini dan bacaan'),
        ('Waktu solat dengan azan', 'Waktu bandar anda — azan Makkah atau Madinah'),
        ('Zikir pagi dan petang', 'Daripada Hisnul Muslim, dikira, dengan audio'),
        ('Kekalkan tabiat baik', 'Wirid, solat sunat, puasa — dengan peringatan'),
        ('Mushaf Madinah', 'Setiap halaman seperti cetakannya, jelas pada mana-mana skrin'),
    ],
    'ur': [
        ('ہر لفظ کی جانچ', 'صفحے سے پڑھیں: درست سبز، غلطیاں سرخ'),
        ('جو حرکت آپ نے ادا کی، وہ سنتا ہے', 'ہمزہ پر: پیش متوقع تھا، زبر سنا گیا'),
        ('زبانی سنائیں', 'ہر لفظ درست ادا کرنے پر ظاہر ہوتا ہے'),
        ('آپ کا روز کا ساتھی', 'نماز کے اوقات، تاریخ، آج کی آیت اور تلاوت'),
        ('اذان کے ساتھ نماز کے اوقات', 'آپ کے شہر کے اوقات — مکہ یا مدینہ کی اذان'),
        ('صبح و شام کے اذکار', 'حصن المسلم سے، گنتی اور آڈیو کے ساتھ'),
        ('اچھی عادات قائم رکھیں', 'ورد، سنت نمازیں، روزے — یاد دہانی کے ساتھ'),
        ('مدینہ مصحف', 'ہر صفحہ جیسا چھپا ہے، ہر اسکرین پر واضح'),
    ],
    'fa': [
        ('هر کلمه بررسی می\u200cشود', 'از روی صفحه بخوانید: درست سبز، خطا قرمز'),
        ('حرکتی را که گفتید می\u200cشنود', 'روی همزه: ضمه انتظار می\u200cرفت، فتحه شنیده شد'),
        ('از حفظ بخوانید', 'هر کلمه با ادای درستش ظاهر می\u200cشود'),
        ('همراه هر روز شما', 'اوقات نماز، تاریخ، آیهٔ روز و ادامهٔ خواندن'),
        ('اوقات نماز با اذان', 'اوقات شهر شما — با اذان مکه یا مدینه'),
        ('اذکار صبح و شام', 'از حصن المسلم، با شمارنده و صوت'),
        ('عادت\u200cهای نیک را نگه دارید', 'ورد، نمازهای سنت، روزه — با یادآور'),
        ('مصحف مدینه', 'هر صفحه مانند نسخهٔ چاپی، روشن در هر صفحه\u200cنمایشی'),
    ],
    'bn-BD': [
        ('প্রতিটি শব্দ যাচাই হয়', 'পৃষ্ঠা দেখে পড়ুন: সঠিক সবুজে, ভুল লালে'),
        ('আপনার উচ্চারিত হরকত শোনে', 'হামযার ওপর: পেশ প্রত্যাশিত, যবর শোনা গেছে'),
        ('মুখস্থ থেকে তিলাওয়াত', 'সঠিকভাবে বললেই প্রতিটি শব্দ দেখা যায়'),
        ('আপনার প্রতিদিনের সঙ্গী', 'নামাজের সময়, তারিখ, আজকের আয়াত ও পড়া'),
        ('আজানসহ নামাজের সময়', 'আপনার শহরের সময় — মক্কা বা মদিনার আজান'),
        ('সকাল-সন্ধ্যার যিকির', 'হিসনুল মুসলিম থেকে, গণনা ও অডিওসহ'),
        ('ভালো অভ্যাস ধরে রাখুন', 'ওয়ির্দ, সুন্নত নামাজ, রোজা — রিমাইন্ডারসহ'),
        ('মদিনা মুসহাফ', 'প্রতিটি পৃষ্ঠা ছাপার মতোই, যেকোনো স্ক্রিনে স্পষ্ট'),
    ],
    'sw': [
        ('Kila neno linakaguliwa', 'Soma kutoka ukurasani: sahihi kijani, makosa mekundu'),
        ('Inasikia irabu uliyotamka', 'Juu ya hamza: ḍamma ilitarajiwa, fatḥa imesikika'),
        ('Soma kwa moyo', 'Kila neno linaonekana unapolitamka sawasawa'),
        ('Mwenzako wa kila siku', 'Nyakati za swala, tarehe, aya ya leo na usomaji'),
        ('Nyakati za swala na adhana', 'Nyakati za mji wako — adhana ya Makka au Madina'),
        ('Adhkar za asubuhi na jioni', 'Kutoka Hisnul Muslim, zinahesabiwa, na sauti'),
        ('Dumisha mazoea mema', 'Wiridi, swala za sunna, saumu — na vikumbusho'),
        ('Msahafu wa Madina', 'Kila ukurasa kama ulivyochapishwa, wazi kwenye skrini yoyote'),
    ],
    'kk': [
        ('Әр сөз тексеріледі', 'Беттен оқыңыз: дұрысы жасыл, қатесі қызыл'),
        ('Айтқан харакатыңызды естиді', 'Хамзада: дамма күтілді, фатха естілді'),
        ('Жатқа оқыңыз', 'Әр сөз дұрыс айтқанда пайда болады'),
        ('Күнделікті серігіңіз', 'Намаз уақыттары, күн, күннің аяты және оқу'),
        ('Азанмен намаз уақыттары', 'Қалаңыздың уақыттары — Мекке не Мәдина азаны'),
        ('Таңғы және кешкі зікірлер', '«Хисн әл-Муслимнен», санағыш пен дыбыспен'),
        ('Жақсы әдеттерді сақтаңыз', 'Уирд, сүннет намаздар, ораза — еске салумен'),
        ('Мединалық мұсхаф', 'Әр бет басылғандай, кез келген экранда анық'),
    ],
    'nl-NL': [
        ('Elk woord gecontroleerd', 'Reciteer van de pagina: goed in groen, fouten in rood'),
        ('Hoort de klinker die je zegt', 'Op de hamza: ḍamma verwacht, fatḥa gehoord'),
        ('Reciteer uit je hoofd', 'Elk woord verschijnt als je het goed zegt'),
        ('Je dagelijkse metgezel', 'Gebedstijden, de datum, het vers van de dag en lezen'),
        ('Gebedstijden met de adhan', 'De tijden van je stad — de adhan van Mekka of Medina'),
        ('Ochtend- en avond-adhkar', 'Uit Hisn al-Muslim, geteld, met audio'),
        ('Houd goede gewoonten vast', 'Wird, sunnah-gebeden, vasten — met herinneringen'),
        ('De Mushaf van Medina', 'Elke pagina zoals gedrukt, scherp op elk scherm'),
    ],
    'da-DK': [
        ('Hvert ord kontrolleret', 'Reciter fra siden: rigtigt i grønt, fejl i rødt'),
        ('Hører den vokal, du siger', 'På hamza: ḍamma forventet, fatḥa hørt'),
        ('Reciter udenad', 'Hvert ord vises, når du siger det rigtigt'),
        ('Din daglige ledsager', 'Bedetider, datoen, dagens vers og din læsning'),
        ('Bedetider med adhan', 'Din bys tider — adhan fra Makkah eller Madinah'),
        ('Morgen- og aften-adhkar', 'Fra Hisn al-Muslim, talt, med lyd'),
        ('Hold fast i gode vaner', 'Wird, sunnah-bønner, faste — med påmindelser'),
        ('Medina-Mushaf', 'Hver side som trykt, skarp på enhver skærm'),
    ],
    'el-GR': [
        ('Κάθε λέξη ελεγμένη', 'Απάγγειλε από τη σελίδα: σωστά με πράσινο, λάθη με κόκκινο'),
        ('Ακούει το φωνήεν που λες', 'Στη χάμζα: αναμενόταν ντάμμα, ακούστηκε φάτχα'),
        ('Απάγγειλε από μνήμης', 'Κάθε λέξη εμφανίζεται όταν τη λες σωστά'),
        ('Ο καθημερινός σας σύντροφος', 'Ώρες προσευχής, ημερομηνία, εδάφιο και ανάγνωση'),
        ('Ώρες προσευχής με αζάν', 'Οι ώρες της πόλης σας — αζάν Μέκκας ή Μεδίνας'),
        ('Πρωινά και βραδινά άζκαρ', 'Από το Hisn al-Muslim, με μετρητή και ήχο'),
        ('Κρατήστε καλές συνήθειες', 'Wird, προσευχές σούννα, νηστεία — με υπενθυμίσεις'),
        ("Το Μους'χαφ της Μεδίνας", 'Κάθε σελίδα όπως τυπώθηκε, καθαρή σε κάθε οθόνη'),
    ],
    'ja-JP': [
        ('すべての語をチェック', 'ページを見て読誦：正しい語は緑、間違いは赤'),
        ('発音した母音を聞き取る', 'ハムザで：ダンマのはずがファトハと聞こえました'),
        ('暗記で読誦', '正しく言うと、語が一つずつ現れます'),
        ('毎日の相棒', '礼拝時刻、日付、今日の節、続きを読む'),
        ('アザーンつきの礼拝時刻', 'お住まいの都市の時刻 — マッカやマディーナのアザーン'),
        ('朝と夕方のズィクル', '『ヒスヌル・ムスリム』から、カウントと音声つき'),
        ('良い習慣を続ける', 'ウィルド、スンナの礼拝、断食 — リマインダーつき'),
        ('マディーナのムスハフ', '印刷どおりのページを、どの画面でも鮮明に'),
    ],
    'ko-KR': [
        ('모든 단어를 확인', '쪽을 보며 낭송: 맞으면 초록, 틀리면 빨강'),
        ('말한 모음까지 듣습니다', '함자에서: 담마가 맞는데 파트하로 들렸습니다'),
        ('외워서 낭송', '바르게 말하면 단어가 하나씩 나타납니다'),
        ('매일의 동반자', '예배 시간, 날짜, 오늘의 아야와 이어 읽기'),
        ('아잔과 함께하는 예배 시간', '내 도시의 시간 — 메카나 메디나의 아잔'),
        ('아침·저녁 디크르', '히스눌 무슬림에서, 카운터와 오디오'),
        ('좋은 습관을 지키세요', '위르드, 순나 예배, 단식 — 알림과 함께'),
        ('메디나 무스하프', '인쇄된 그대로의 쪽을 어느 화면에서나 선명하게'),
    ],
    'pt-BR': [
        ('Cada palavra conferida', 'Recite pela página: certo em verde, erros em vermelho'),
        ('Ouve a vogal que você diz', 'No hamza: esperado ḍamma, ouvido fatḥa'),
        ('Recite de memória', 'Cada palavra aparece quando você a diz certo'),
        ('Seu companheiro diário', 'Horários de oração, data, versículo do dia e leitura'),
        ('Horários de oração com adhan', 'Os da sua cidade — o adhan de Meca ou Medina'),
        ('Adhkar da manhã e da tarde', 'Do Hisn al-Muslim, contados, com áudio'),
        ('Mantenha bons hábitos', 'Wird, orações sunnah, jejum — com lembretes'),
        ('O Mushaf de Medina', 'Cada página como impressa, nítida em qualquer tela'),
    ],
    'zh-CN': [
        ('每个词都经过检查', '对照页面诵读：正确为绿色，错误为红色'),
        ('连你读的元音都能听出', '在哈姆宰上：应为合口符，听到的是开口符'),
        ('凭记忆诵读', '读对一个词，就显示一个词'),
        ('每日的好伙伴', '礼拜时间、日期、今日经文与继续阅读'),
        ('礼拜时间与宣礼', '你所在城市的时间——麦加或麦地那的宣礼'),
        ('早晨与傍晚记念词', '出自《穆斯林堡垒》，可计数，附音频'),
        ('坚持好习惯', '功课、圣行礼拜、斋戒——附提醒'),
        ('麦地那经本', '每一页都与印刷版一致，在任何屏幕上都清晰'),
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
