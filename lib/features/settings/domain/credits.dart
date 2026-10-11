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
    useEn: 'The Quran text and its structure (surahs, ayahs, juz, pages)',
    useAr: 'نصّ القرآن الكريم وبنيته (السور والآيات والأجزاء والصفحات)',
  ),
  Credit(
    group: CreditGroup.quran,
    name: 'quran-transcript (Quran phonetizer)',
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
        'Affairs), Turkish (Rowwad) and French (Noor International Center) '
        'translations',
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
        'Turkish, French)',
    owner: 'QuranEnc — Tafsir Center for Quranic Studies',
    licence: 'QuranEnc terms: unmodified, with attribution',
    url: 'https://quranenc.com',
    useEn: 'Short tafsir',
    useAr: 'تفسير مختصر',
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
    name: 'Word audio',
    owner: 'Quran Foundation (Quran.com)',
    licence: 'Quran Foundation Developer Terms; streamed',
    url: 'https://quran.com',
    useEn: 'Hearing a word',
    useAr: 'الاستماع إلى الكلمة',
  ),
  // ── The Mushaf ──
  Credit(
    group: CreditGroup.mushaf,
    name: 'Quran Engine page corpus (KFGQPC Madinah Mushaf)',
    owner: 'quran.ws (Quran Engine); King Fahd Glorious Quran Printing Complex',
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
        'Glorious Qur’an Printing Complex, used under its usage rights.',
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
    owner: 'Tarteel (QUL); King Fahd Glorious Quran Printing Complex',
    licence:
        'Layouts free for personal and commercial use (QUL); word data: '
        'terms being confirmed. The Mushaf: the King Fahd Complex’s usage '
        'rights',
    url: 'https://qul.tarteel.ai',
    useEn: 'Mushaf layout and word data',
    useAr: 'تخطيط المصحف وبيانات الكلمات',
    citation: 'Data provided by QUL — https://qul.tarteel.ai',
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
        'The Quran pronunciation model Tahfeez’s on-device model learned '
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
    name: 'Recitations from everyayah.com and mp3quran.net',
    owner: 'The reciters; EveryAyah; mp3quran.net',
    licence:
        'Published for listening; no licence for training stated — used with '
        'credit while clarified',
    url: 'https://everyayah.com',
    useEn: 'Training and testing the recitation model (professional reciters)',
    useAr: 'تدريب نموذج التلاوة واختباره (قرّاء متقنون)',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'Quranic Audio Dataset (RetaSy)',
    owner: 'RetaSy',
    licence: 'Not stated by the dataset; used with credit',
    url: 'https://huggingface.co/datasets/RetaSy/quranic_audio_dataset',
    useEn: 'Training and testing on learners’ recitation',
    useAr: 'التدريب والاختبار على تلاوات المتعلّمين',
    citation:
        'Quranic Audio Dataset: Crowdsourced and Labeled Recitation from '
        'Non-Arabic Speakers, arXiv:2405.02675',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'QDAT (obadx/qdat)',
    owner: 'QDAT authors; cleaned by obadx',
    licence: 'MIT (obadx/qdat)',
    url: 'https://huggingface.co/datasets/obadx/qdat',
    useEn: 'Testing tajweed checks (madd, ghunnah, ikhfāʾ, qalqala)',
    useAr: 'اختبار فحص التجويد (المدّ والغنّة والإخفاء والقلقلة)',
    citation: 'QDAT: A data set for Reciting the Quran',
  ),
  Credit(
    group: CreditGroup.data,
    name: 'QuranMB.v2 (Iqra’Eval)',
    owner: 'Iqra’Eval / ArabicSpeech',
    licence: 'Not stated by the dataset; used with credit',
    url: 'https://huggingface.co/IqraEval',
    useEn: 'Testing on real, expert-annotated mistakes',
    useAr: 'الاختبار على أخطاء حقيقية علّمها خبراء',
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
    useEn: 'Testing on learners’ qalqala and vowel mistakes',
    useAr: 'الاختبار على أخطاء المتعلّمين في القلقلة والحركات',
  ),
  // ── Software ──
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
