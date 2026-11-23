import 'package:flutter/foundation.dart';

/// What a credited source is used for.
enum CreditGroup { quran, translations, mushaf, ai, data, software }

/// One credited source: who made it, under which licence, and what Tahfeez
/// uses it for. Mirrors docs/THIRD_PARTY_RESOURCES.md (the record of truth);
/// a licence not stated by its source is said so, not guessed.
@immutable
class Credit {
  const Credit({
    required this.group,
    required this.name,
    required this.owner,
    required this.licence,
    required this.url,
    required this.useEn,
    required this.useAr,
    this.citation,
  });

  final CreditGroup group;
  final String name, owner, licence, url;

  /// What Tahfeez uses it for, in English and Arabic.
  final String useEn, useAr;

  /// The work to cite, where its authors ask for it.
  final String? citation;

  /// The licence notice for Flutter's licence page.
  String get notice => [
    name,
    'By $owner — $url',
    'Licence: $licence',
    'Used for: $useEn',
    ?citation,
  ].join('\n\n');
}

const credits = <Credit>[
  // ── The Quran ──
  Credit(
    group: CreditGroup.quran,
    name: 'Tanzil Quran text (Uthmani 1.1) and metadata',
    owner: 'Tanzil Project',
    licence:
        'Tanzil text licence: verbatim copies only, with attribution '
        '(tanzil.net/docs/text_license); metadata CC BY',
    url: 'https://tanzil.net',
    useEn: "The Qur'an text and its structure (surahs, ayahs, juz, pages)",
    useAr: 'نصّ القرآن الكريم وبنيته (السور والآيات والأجزاء والصفحات)',
  ),
  Credit(
    group: CreditGroup.quran,
    name: 'Tajweed annotations (quran-tajweed)',
    owner: 'Collin Fair (cpfair)',
    licence: 'CC BY 4.0',
    url: 'https://github.com/cpfair/quran-tajweed',
    useEn: "Ayah mode's tajweed colours",
    useAr: 'ألوان التجويد في وضع الآيات',
  ),
  Credit(
    group: CreditGroup.quran,
    name: "Ontology of Quranic concepts (Quranic Arabic Corpus)",
    owner: 'Kais Dukes, University of Leeds',
    licence: 'GNU GPL v3 (non-commercial use)',
    url: 'https://corpus.quran.com/ontology.jsp',
    useEn:
        "The Quran tab's Topics (names in other languages translated by "
        'TahfeezAI)',
    useAr: 'المواضيع في تبويب القرآن',
  ),
  Credit(
    group: CreditGroup.quran,
    name: 'Quranic Arabic Corpus morphology 0.4',
    owner: 'Kais Dukes, University of Leeds',
    licence: 'GNU GPL',
    url: 'https://corpus.quran.com',
    useEn: "Each word's root, in the word's pill and its sheet (Arabic)",
    useAr: 'جذر الكلمة في بطاقتها ونافذتها',
  ),
  Credit(
    group: CreditGroup.quran,
    name: "quran-transcript (Qur'an phonetizer)",
    owner: 'Abdullah (obadx)',
    licence: 'MIT',
    url: 'https://github.com/obadx/quran-transcript',
    useEn: 'The expected pronunciation (Ḥafṣ) used to check recitation',
    useAr: 'النطق المتوقَّع (رواية حفص) الذي تُفحَص به التلاوة',
  ),
  // ── Translations and tafsir ──
  Credit(
    group: CreditGroup.translations,
    name: 'English and German translations (Rowwad)',
    owner: 'QuranEnc — Rowwad Translation Center',
    licence: 'QuranEnc terms: unmodified, with attribution and version',
    url: 'https://quranenc.com',
    useEn: 'Translations of the meanings',
    useAr: 'ترجمات المعاني',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Tafsir Al-Muyassar',
    owner: 'QuranEnc',
    licence: 'QuranEnc terms: unmodified, with attribution',
    url: 'https://quranenc.com',
    useEn: 'Tafsir',
    useAr: 'التفسير',
  ),
  Credit(
    group: CreditGroup.translations,
    name:
        'Urdu (Muhammad Junagarhi), Indonesian (Ministry of Religious '
        'Affairs), Turkish, Russian, Persian and Bengali (Rowwad), and French '
        'and Spanish (Noor International Center) translations',
    owner: 'QuranEnc',
    licence: 'QuranEnc terms: unmodified, with attribution and version',
    url: 'https://quranenc.com',
    useEn: 'Translations of the meanings',
    useAr: 'ترجمات المعاني',
  ),
  Credit(
    group: CreditGroup.translations,
    name:
        'Al-Mukhtasar in Interpreting the Noble Quran (English, Indonesian, '
        'Turkish, French, Spanish, Russian, Persian, Bengali)',
    owner: 'QuranEnc — Tafsir Center for Quranic Studies',
    licence: 'QuranEnc terms: unmodified, with attribution',
    url: 'https://quranenc.com',
    useEn: 'Short tafsir',
    useAr: 'تفسير مختصر',
  ),
  Credit(
    group: CreditGroup.translations,
    name:
        'Malay (Abdullah Basumayyah), Hausa (Abu Bakr Gumi), Kurdish Sorani '
        '(Muhammad Salih Bamoki), Kazakh (Khalifa Altai), Somali (Abdullah '
        'Hasan Yaqoub), Korean (Hamid Choi), Japanese (Saeed Sato) and '
        'Portuguese (Helmi Nasr), Chinese (Muhammad Suleiman, Muhammad '
        'Makin), Hindi (Azizul Haq Al-Omari), Tamil (Omar Sharif) and '
        'Malayalam (Abdul Hamid Haidar, Kunhi Muhammad) translations; '
        'Pashto, Swahili, Uzbek, Dutch, Greek and Italian (Rowwad); '
        'Al-Mukhtasar in Kurdish, Pashto, Uzbek, Japanese, Chinese, Hindi, '
        'Tamil, Malayalam and Italian; '
        "Al-Mukhtasar's aims of each surah (16 languages; 8 more from "
        "the Tafsir Center's own Al-Mukhtasar, mokhtasr.com)",
    owner: 'QuranEnc',
    licence: 'QuranEnc terms: unmodified, with attribution and version',
    url: 'https://quranenc.com',
    useEn: 'Translations of the meanings and short tafsir',
    useAr: 'ترجمات المعاني والتفسير المختصر',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Ahsan-ul-Bayan (Urdu tafsir, the Junagarhi translation’s notes)',
    owner: 'Hafiz Salahuddin Yusuf — via QuranEnc',
    licence: 'QuranEnc terms: unmodified, with attribution',
    url: 'https://quranenc.com',
    useEn: 'Urdu tafsir',
    useAr: 'التفسير بالأردية',
  ),
  Credit(
    group: CreditGroup.translations,
    name:
        'Al-Mukhtasar in Arabic; Al-Nafahat Al-Makkiyyah (Muhammad ibn Salih '
        'al-Shawi); Bayan Ma\'ani Al-Quran Al-Karim',
    owner: 'QuranEnc',
    licence: 'QuranEnc terms: unmodified, with attribution',
    url: 'https://quranenc.com',
    useEn: 'Arabic tafsir',
    useAr: 'التفسير بالعربية',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Word-by-word French (meanings)',
    owner: 'Quranic Universal Library (QUL, Tarteel)',
    licence: 'Not stated by the source; used with credit while clarified',
    url: 'https://qul.tarteel.ai',
    useEn: 'Word meanings in French',
    useAr: 'معاني الكلمات بالفرنسية',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Word-by-word English (meanings and transliteration)',
    owner: 'Quran.com (Quranic Universal Library, resource 92)',
    licence: 'Not stated by the source; used with credit while clarified',
    url: 'https://quran.com',
    useEn: 'Word meanings',
    useAr: 'معاني الكلمات',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Recitation audio (ayahs)',
    owner: 'Islamic Network (alquran.cloud) — the reciters',
    licence: 'Licensed by the reciters for free redistribution; streamed',
    url: 'https://alquran.cloud',
    useEn: 'Listening to ayahs and surahs',
    useAr: 'الاستماع إلى الآيات والسور',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Translation readings (audio)',
    owner: 'Islamic Network (alquran.cloud) — the readers',
    licence: 'Licensed by the readers for free redistribution; streamed',
    url: 'https://alquran.cloud',
    useEn:
        'A translation read after each ayah: Ibrahim Walk (English), '
        'Shamshad Ali Khan (Urdu), Youssouf Leclerc (French), Elmir Kuliev '
        '(Russian), Hedayatfar (Persian), Diyanet Vakfı (Turkish), Khalifah '
        'Altai (Kazakh), Muhammad Sodik Muhammad Yusuf (Uzbek), and a '
        'Chinese reading',
    useAr:
        'ترجمة مسموعة بعد كل آية: إبراهيم ووك (الإنجليزية)، شمشاد علي خان '
        '(الأردية)، يوسف لوكلير (الفرنسية)، إلمير كولييف (الروسية)، هدايت‌فر '
        '(الفارسية)، وقف الديانة (التركية)، خليفة ألطاي (الكازاخية)، محمد '
        'صادق محمد يوسف (الأوزبكية)، وقراءة صينية',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Recitations by ayah from everyayah.com',
    owner: 'EveryAyah (everyayah.com) — the reciters',
    licence: 'No licence stated; streamed with credit',
    url: 'https://everyayah.com',
    useEn:
        'Listening to ayahs and surahs: Al-Tablawi, Al-Banna, Al-Husary '
        '(Muallim), Saad Al-Ghamdi, Yasser Al-Dossary, Nasser Al-Qatami, '
        'Fares Abbad, Ali Jaber, Salah Bukhatir, Yasser Salamah, Karim '
        'Mansoori, Abdullah Awad Al-Juhani, Abdullah Matroud, Khalifa '
        'Al-Tunaiji',
    useAr:
        'الاستماع إلى الآيات والسور: الطبلاوي، البنا، الحصري (المعلّم)، '
        'سعد الغامدي، ياسر الدوسري، ناصر القطامي، فارس عباد، علي جابر، '
        'صلاح بو خاطر، ياسر سلامة، كريم منصوري، عبد الله عواد الجهني، '
        'عبد الله المطرود، خليفة الطنيجي',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Word audio',
    owner: 'Quran Foundation (Quran.com)',
    licence: 'Quran Foundation Developer Terms; streamed',
    url: 'https://quran.com',
    useEn: 'Hearing a word',
    useAr: 'الاستماع إلى الكلمة',
  ),
  // ── Reciters' photos (Wikimedia Commons; cropped and made small) ──
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Mahmoud Khalil Al-Husary',
    owner: 'Egyptian Government (his identity card)',
    licence: 'Public domain (an Egyptian photograph over 15 years old)',
    url: 'https://commons.wikimedia.org/wiki/File:بطاقة_شخصية_لمحمود_خليل_الحصري_(cropped).png',
    useEn: "Mahmoud Khalil Al-Husary's picture beside his name",
    useAr: 'صورة محمود خليل الحصري بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Muhammad Siddiq Al-Minshawi',
    owner: 'Unknown photographer (before 1969)',
    licence: 'Public domain (an Egyptian photograph over 15 years old)',
    url: 'https://commons.wikimedia.org/wiki/File:Elminshwey.jpg',
    useEn: "Muhammad Siddiq Al-Minshawi's picture beside his name",
    useAr: 'صورة محمد صديق المنشاوي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Abdul Basit Abdus-Samad',
    owner: 'Unknown photographer, Muslim News (South Africa), 1966',
    licence: 'Public domain',
    url: 'https://commons.wikimedia.org/wiki/File:Abdul_Basit_Abd_us-Samad_in_South_Africa_in_1966_(3)_(cropped).jpg',
    useEn: "Abdul Basit Abdus-Samad's picture beside his name",
    useAr: 'صورة عبد الباسط عبد الصمد بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Abdur-Rahman As-Sudais',
    owner: 'Prime Minister\'s Office, Government of India (2011)',
    licence: 'Government Open Data License – India (GODL)',
    url: 'https://commons.wikimedia.org/wiki/File:Shaikh_Abdur_Rahman_Abdul_Aziz_al_Sudais_in_New_Delhi_on_March_24,_2011.jpg',
    useEn: "Abdur-Rahman As-Sudais's picture beside his name",
    useAr: 'صورة عبد الرحمن السديس بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Saud Ash-Shuraym',
    owner: 'Vice President\'s Secretariat, Government of India (2012)',
    licence: 'Government Open Data License – India (GODL)',
    url: 'https://commons.wikimedia.org/wiki/File:The_IMAM_of_Holy_Mosque_in_Makka_Al_Mukarramah,_Saudi_Arabia,_Sheikh_Dr._Saud_Bin_Ibrahem_Al_Shuraim_meeting_the_Vice_President,_Shri_Mohd._Hamid_Ansari,_in_New_Delhi_on_March_03,_2012_(cropped).jpg',
    useEn: "Saud Ash-Shuraym's picture beside his name",
    useAr: 'صورة سعود الشريم بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Yasser Al-Dossary',
    owner: 'MAL MALDIVE (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:Yasser_Al-Dosari_(cropped).jpg',
    useEn: "Yasser Al-Dossary's picture beside his name",
    useAr: 'صورة ياسر الدوسري بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Nasser Al-Qatami',
    owner: 'Ayman dhū alghiná (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:صورة_شخصية_الشيخ_ناصر_القطامي.jpg',
    useEn: "Nasser Al-Qatami's picture beside his name",
    useAr: 'صورة ناصر القطامي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Shahriar Parhizgar',
    owner: 'Mostafameraji (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:شهریار_پرهیزکار_04_(1).jpg',
    useEn: "Shahriar Parhizgar's picture beside his name",
    useAr: 'صورة شهريار پرهيزگار بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Karim Mansoori',
    owner: 'Mostafameraji (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:عکس_کریم_منصوری_قاری_بین_المللی.jpg',
    useEn: "Karim Mansoori's picture beside his name",
    useAr: 'صورة كريم منصوري بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Muhammad Jibreel',
    owner: 'Alhidaya Croydon (YouTube, Ramadan 2019)',
    licence: 'CC BY 3.0',
    url: 'https://commons.wikimedia.org/wiki/File:Qari_Muhammad_Jebril,_Ramadan_2019.png',
    useEn: "Muhammad Jibreel's picture beside his name",
    useAr: 'صورة محمد جبريل بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Mishary Alafasy',
    owner: 'quranic.ru (via Wikimedia Commons)',
    licence: 'Copyrighted free use as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Мишари_Рашид.jpg',
    useEn: "Mishary Alafasy's picture beside his name",
    useAr: 'صورة مشاري العفاسي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Maher Al-Muaiqly',
    owner: 'Real avdulmouhd (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Professor_Maher_Al-Mu\'aiqly.jpg',
    useEn: "Maher Al-Muaiqly's picture beside his name",
    useAr: 'صورة ماهر المعيقلي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Saad Al-Ghamdi',
    owner: 'الشيخ هيثم الدخين (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Saad_al_Ghamdi.jpg',
    useEn: "Saad Al-Ghamdi's picture beside his name",
    useAr: 'صورة سعد الغامدي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Ahmad al-Ajamy',
    owner: 'أحمد زين (Wikimedia Commons)',
    licence: 'CC BY-SA 3.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Ahmad_bin_Ali_Al-Ajmi.png',
    useEn: "Ahmad al-Ajamy's picture beside his name",
    useAr: 'صورة أحمد بن علي العجمي بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Ayman Suwaid',
    owner: 'propagerlislam.net (via Wikimedia Commons)',
    licence: 'Public domain as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Aymen_souaid.jpg',
    useEn: "Ayman Suwaid's picture beside his name",
    useAr: 'صورة أيمن سويد بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Ali Jaber',
    owner: 'Engalali9 (Wikimedia Commons)',
    licence: 'CC0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:الشيخ_علي_جابر.png',
    useEn: "Ali Jaber's picture beside his name",
    useAr: 'صورة علي جابر بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Abdullah Awad Al-Juhani',
    owner: 'الشيخ هيثم الدخين (Wikimedia Commons)',
    licence: 'CC BY-SA 4.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Abdullah_Al_Juhany_(Cropped).png',
    useEn: "Abdullah Awad Al-Juhani's picture beside his name",
    useAr: 'صورة عبد الله عواد الجهني بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Abdullah Matroud',
    owner: 'tvquran.com (via Wikimedia Commons)',
    licence: 'CC BY-SA 4.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Abdullah_Al_Matroud.jpg',
    useEn: "Abdullah Matroud's picture beside his name",
    useAr: 'صورة عبد الله المطرود بجانب اسمه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Recitation of Islam Sobhi (mp3quran.net)',
    owner: 'Islam Sobhi; mp3quran.net',
    licence: 'No licence stated; streamed with credit (removed if its rights holder asks)',
    url: 'https://mp3quran.net/eng/islam-sobhi',
    useEn:
        'Listening to ayahs and surahs: his whole-surah recordings (109 '
        'surahs), cut ayah by ayah at timings Tahfeez worked out itself',
    useAr:
        'الاستماع إلى الآيات والسور: تسجيلاته للسور كاملة (109 سور)، '
        'مقطّعة آيةً آيةً بتوقيتات استخرجها تحفيظ بنفسه',
  ),
  Credit(
    group: CreditGroup.translations,
    name: 'Photo of Islam Sobhi',
    owner: 'Moaz600 (via Wikimedia Commons)',
    licence: 'CC BY-SA 4.0 as stated on Wikimedia Commons (not verified; removed if its rights holder asks)',
    url: 'https://commons.wikimedia.org/wiki/File:Islam_Sobhi.jpg',
    useEn: "Islam Sobhi's picture beside his name",
    useAr: 'صورة إسلام صبحي بجانب اسمه',
  ),
  // ── The Mushaf ──
  Credit(
    group: CreditGroup.mushaf,
    name: 'Quran Engine page corpus (KFGQPC Madinah Mushaf)',
    owner:
        'quran.ws (Quran Engine); King Fahd Glorious Qur\'an Printing Complex',
    licence:
        'quran.ws data: CC BY 4.0. The Mushaf: the King Fahd Complex’s '
        'usage rights (free use, including in software)',
    url: 'https://github.com/quran-ws/quran-engine',
    useEn: 'The Mushaf pages as printed',
    useAr: 'صفحات المصحف كما طُبعت',
    citation:
        'Data from Quran Engine (quran-engine-pages-hafs-kfgqpc) by Quran.ws, '
        'licensed under CC BY 4.0. Source: https://cdn.quran.ws/qvp/v0.3.0/. '
        'Version: 0.3.0. Modified: no. Mus’haf al-Madinah © King Fahd '
        'Glorious Qur\'an Printing Complex, used under its usage rights.',
  ),
  Credit(
    group: CreditGroup.mushaf,
    name: 'qvp_flutter (Quran Engine for Flutter)',
    owner: 'quran.ws',
    licence: 'MIT',
    url: 'https://pub.dev/packages/qvp_flutter',
    useEn: 'Drawing the Mushaf pages',
    useAr: 'رسم صفحات المصحف',
  ),
  Credit(
    group: CreditGroup.mushaf,
    name: 'Quranic Universal Library: KFGQPC V2 layout and word data',
    owner: 'Tarteel (QUL); King Fahd Glorious Qur\'an Printing Complex',
    licence:
        'Layouts free for personal and commercial use (QUL); word data: '
        'no licence stated, used with credit. The Mushaf: the King Fahd '
        'Complex’s usage rights',
    url: 'https://qul.tarteel.ai',
    useEn: 'Mushaf layout and word data',
    useAr: 'تخطيط المصحف وبيانات الكلمات',
    citation: 'Data provided by QUL — https://qul.tarteel.ai',
  ),
  Credit(
    group: CreditGroup.mushaf,
    name: 'Scheherazade New, Amiri Quran, Noto Naskh Arabic and Lateef',
    owner: 'SIL Global; the Amiri Project Authors; the Noto Project Authors',
    licence: 'SIL Open Font License 1.1',
    url: 'https://github.com/aliftype/amiri',
    useEn: "The Qur'an text outside the printed pages",
    useAr: 'نص القرآن خارج صفحات المصحف',
  ),
  Credit(
    group: CreditGroup.mushaf,
    name: 'Noto Sans, Noto Kufi Arabic, Almarai and Tajawal',
    owner:
        'The Noto Project Authors; the Almarai Project Authors; '
        'Boutros International (via Google Fonts)',
    licence: 'SIL Open Font License 1.1',
    url: 'https://github.com/google/fonts',
    useEn: 'The app’s text',
    useAr: 'خطوط نصوص التطبيق',
  ),
  // ── Recitation AI ──
  Credit(
    group: CreditGroup.ai,
    name: 'Muaalem (obadx/muaalem-model-v3_2)',
    owner: 'Abdullah (obadx)',
    licence: 'MIT',
    url: 'https://huggingface.co/obadx/muaalem-model-v3_2',
    useEn:
        "The Qur'an pronunciation model Tahfeez’s on-device model learned "
        'from (as its teacher)',
    useAr: 'نموذج نطق القرآن الذي تعلّم منه نموذجُ تحفيظ على الجهاز',
    citation:
        'Automatic Pronunciation Error Detection and Correction of the Holy '
        'Quran’s Learners Using Deep Learning, arXiv:2509.00094',
  ),
  Credit(
    group: CreditGroup.ai,
    name: 'ONNX Runtime',
    owner: 'Microsoft',
    licence: 'MIT',
    url: 'https://github.com/microsoft/onnxruntime',
    useEn: 'Running the recitation model on the device',
    useAr: 'تشغيل نموذج التلاوة على الجهاز',
  ),
  // ── Training and evaluation data ──
  Credit(
    group: CreditGroup.data,
    name: 'Muaalem annotated recitations (obadx/muaalem-annotated-v3)',
    owner: 'Abdullah (obadx); the reciters',
    licence: 'MIT (obadx/muaalem-annotated-v3)',
    url: 'https://huggingface.co/datasets/obadx/muaalem-annotated-v3',
    useEn: 'Training the recitation model (professional reciters)',
    useAr: 'تدريب نموذج التلاوة (قرّاء متقنون)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Recitations from mp3quran.net',
    owner: 'The reciters; mp3quran.net',
    licence:
        '“All rights are available to everyone”: any developer may copy any '
        'material (mp3quran.net)',
    url: 'https://www.mp3quran.net',
    useEn: 'Training and testing the recitation model (professional reciters)',
    useAr: 'تدريب نموذج التلاوة واختباره (قرّاء متقنون)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Recitations from everyayah.com',
    owner: 'The reciters; EveryAyah',
    licence: 'No licence stated; used with credit',
    url: 'https://everyayah.com',
    useEn: 'Training and testing the recitation model (professional reciters)',
    useAr: 'تدريب نموذج التلاوة واختباره (قرّاء متقنون)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Quranic Audio Dataset (RetaSy)',
    owner: 'RetaSy',
    licence: 'No licence stated; used with credit',
    url: 'https://huggingface.co/datasets/RetaSy/quranic_audio_dataset',
    useEn: 'Training and testing on learners’ recitation',
    useAr: 'التدريب والاختبار على تلاوات المتعلّمين',
    citation:
        'Quranic Audio Dataset: Crowdsourced and Labeled Recitation from '
        'Non-Arabic Speakers, arXiv:2405.02675',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'User Recited Verses Full (greentechapps)',
    owner: 'greentechapps; originally collected by the Tarteel project',
    licence: 'CC BY 4.0',
    url: 'https://huggingface.co/datasets/greentechapps/user_recited_verses_full',
    useEn: 'Training the recitation model on real phone recordings',
    useAr: 'تدريب نموذج التلاوة على تسجيلات هواتف حقيقية',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'QDAT (obadx/qdat)',
    owner: 'QDAT authors; cleaned by obadx',
    licence: 'MIT (obadx/qdat)',
    url: 'https://huggingface.co/datasets/obadx/qdat',
    useEn:
        'Training and testing tajweed checks (madd, ghunnah, ikhfāʾ, '
        'qalqala)',
    useAr: 'تدريب فحص التجويد واختباره (المدّ والغنّة والإخفاء والقلقلة)',
    citation: 'QDAT: A data set for Reciting the Quran',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'QuranMB.v2 (Iqra’Eval)',
    owner: 'Iqra’Eval / ArabicSpeech',
    licence: 'Not stated by the dataset; used with credit',
    url: 'https://huggingface.co/IqraEval',
    useEn: 'Training and testing on real, expert-annotated mistakes',
    useAr: 'التدريب والاختبار على أخطاء حقيقية علّمها خبراء',
    citation:
        'Iqra’Eval: A Shared Task on Qur’anic Pronunciation Assessment '
        '(ArabicNLP 2025)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Iqra_Extra_IS26 (Iqra’Eval)',
    owner: 'Iqra’Eval / ArabicSpeech',
    licence: 'No licence stated; used with credit',
    url: 'https://huggingface.co/datasets/IqraEval/Iqra_Extra_IS26',
    useEn: 'Training on learners’ real recitation mistakes',
    useAr: 'التدريب على أخطاء حقيقية في تلاوات المتعلّمين',
    citation:
        'Iqra’Eval: A Shared Task on Qur’anic Pronunciation Assessment '
        '(ArabicNLP 2025)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Surah Al-Ikhlas Recitation Error Detection Dataset',
    owner: 'Muaz Ahmad (MuazAhmad7)',
    licence: 'CC BY 4.0',
    url: 'https://huggingface.co/datasets/MuazAhmad7/Surah_Ikhlas-Labeled_Dataset',
    useEn: 'Training and testing on learners’ qalqala and vowel mistakes',
    useAr: 'التدريب والاختبار على أخطاء المتعلّمين في القلقلة والحركات',
  ),
  // ── Software ──
  Credit(
    group: CreditGroup.data,
    name:
        "Hisn al-Muslim (Fortress of the Muslim) — Sa'id ibn Wahf "
        'al-Qahtani; Arabic, English and audio as published by '
        'hisnmuslim.com',
    owner: "Sa'id ibn Wahf al-Qahtani; hisnmuslim.com",
    licence: 'No licence stated; used with credit (the audio streamed)',
    url: 'https://www.hisnmuslim.com',
    useEn: 'Athkar and Duas: the remembrances, their counts and their audio',
    useAr: 'الأذكار والأدعية: نصوصها وأعداد تكرارها وصوتها',
  ),
  Credit(
    group: CreditGroup.data,
    name:
        'Hadith API — Sahih al-Bukhari and Sahih Muslim, Arabic and '
        'translations',
    owner: 'Fawaz Ahmed (fawazahmed0), from sunnah.com and others',
    licence: 'The Unlicense (public domain)',
    url: 'https://github.com/fawazahmed0/hadith-api',
    useEn: 'Duas: 19 supplications from Sahih al-Bukhari and Sahih Muslim',
    useAr: 'الأدعية: ١٩ دعاءً من صحيحي البخاري ومسلم',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'GeoNames world cities (50,000+ people)',
    owner: 'GeoNames',
    licence: 'CC BY 4.0',
    url: 'https://www.geonames.org',
    useEn: 'Choosing a city for the qibla',
    useAr: 'اختيار المدينة لتحديد القبلة',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'World Magnetic Model 2025 (through the geomag package)',
    owner: 'NOAA NCEI and the British Geological Survey',
    licence: 'Public domain (the model); MIT (geomag)',
    url: 'https://www.ncei.noaa.gov/products/world-magnetic-model',
    useEn: "The compass's true north for the qibla",
    useAr: 'الشمال الحقيقي في البوصلة لتحديد القبلة',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Umm al-Qura calendar (through the hijri package)',
    owner: 'Ahmed Aljoaid (hijri)',
    licence: 'BSD 2-Clause',
    url: 'https://pub.dev/packages/hijri',
    useEn: "Habits: the Hijri dates (Ayyām al-Bīḍ, ʿArafah, ʿĀshūrāʾ)",
    useAr: 'العادات: التاريخ الهجري (الأيام البيض، عرفة، عاشوراء)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Unicode CLDR country names',
    owner: 'Unicode, Inc.',
    licence: 'Unicode License v3',
    url: 'https://cldr.unicode.org',
    useEn: 'Prayer times: the country of the place shown',
    useAr: 'مواقيت الصلاة: اسم بلد المكان المعروض',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan, Madinah',
    owner: 'ejaz215 (Freesound)',
    licence: 'CC BY 3.0',
    url: 'https://freesound.org/people/ejaz215/sounds/33937/',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan — Aaqib Azeez',
    owner: 'Aaqib Azeez; uploaded by Atcovi',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:The_Adhan_-_Muslim_Call_to_Prayer_-_Aaqib_Azeez.mp3',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Azan',
    owner: 'Andrewler',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:Azan.ogg',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Beautiful adhan',
    owner: 'Adam-synagda',
    licence: 'CC0 1.0',
    url: 'https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Call to prayer',
    owner: 'Isaacayodele32',
    licence: 'CC BY-SA 4.0',
    url: 'https://commons.wikimedia.org/wiki/File:Call_to_prayer.ogg',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan by Ali Mulla (Makkah)',
    owner: 'Ali Mulla; Internet Archive, "Azaan of World Mosques"',
    licence: 'Marked public domain by its uploader (not verified; removed if its rights holder asks)',
    url: 'https://archive.org/details/azaan-of-world-mosques-english',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan by Abdul Majeed Al-Surayhi (Quba)',
    owner: 'Abdul Majeed Al-Surayhi; Internet Archive',
    licence: 'Marked public domain by its uploader (not verified; removed if its rights holder asks)',
    url: 'https://archive.org/details/zied_hadj_hassen1',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan by Abdulnasser Harak',
    owner: 'Abdulnasser Harak; Internet Archive',
    licence: 'Marked public domain by its uploader (not verified; removed if its rights holder asks)',
    url: 'https://archive.org/details/adhan-from-egypt-abdulnasser-harak',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Adhan by Naji Qazzaz (Al-Aqsa)',
    owner: 'Naji Qazzaz; Internet Archive, "Azaan of World Mosques"',
    licence: 'Marked public domain by its uploader (not verified; removed if its rights holder asks)',
    url: 'https://archive.org/details/azaan-of-world-mosques-english',
    useEn: 'Prayer times: an adhan to be reminded with (trimmed, evened)',
    useAr: 'مواقيت الصلاة: أذان للتنبيه (مقصوص وموحّد الصوت)',
  ),
  Credit(
    group: CreditGroup.software,
    name: 'Adhan for Dart (prayer-time calculation)',
    owner: 'Riajul Islam (adhan-dart), after the Batoul Apps Adhan library',
    licence: 'MIT',
    url: 'https://pub.dev/packages/adhan',
    useEn: 'Prayer times: worked out on the phone for the place chosen',
    useAr: 'مواقيت الصلاة: تُحسب على الهاتف للمكان المختار',
  ),
  Credit(
    group: CreditGroup.software,
    name: 'Flutter, Dart and the packages Tahfeez uses',
    owner: 'Google and the package authors',
    licence: 'Each package’s own licence (listed under Licences)',
    url: 'https://flutter.dev',
    useEn: 'The app itself',
    useAr: 'التطبيق نفسه',
  ),
];
