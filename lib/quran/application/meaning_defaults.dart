import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/localization/locale_controller.dart';

/// The language meaning (translation and tafsir) defaults follow: the app's
/// chosen language, else the phone's — including one the app's own
/// interface doesn't offer (e.g. Urdu).
String meaningLanguage(Ref ref) =>
    ref.read(localeControllerProvider)?.languageCode ??
    PlatformDispatcher.instance.locale.languageCode;

/// The language of the surah names shown for the UI [language]: the
/// dataset has Arabic names (also used for Urdu and Persian) and English
/// transliterations (used for every other language).
String surahNameLanguage(String language) =>
    usesArabicScript(language) ? 'ar' : 'en';

/// Whether [language] is written in Arabic script, so Arabic names (of
/// surahs, reciters) read naturally in it.
bool usesArabicScript(String language) =>
    const {'ar', 'ur', 'fa', 'ckb', 'ps'}.contains(language);

/// The bundled translation shown by default for each language; none for
/// Arabic; English for any other.
List<String> defaultTranslationSlugs(String language) => switch (language) {
  'ar' => const [],
  'de' => const ['de-rowwad'],
  'ur' => const ['ur-junagarhi'],
  'id' => const ['id-affairs'],
  'tr' => const ['tr-rowwad'],
  'fr' => const ['fr-noor'],
  'es' => const ['es-noor'],
  'ru' => const ['ru-rowwad'],
  'fa' => const ['fa-rowwad'],
  'bn' => const ['bn-rowwad'],
  'ms' => const ['ms-basumayyah'],
  'ha' => const ['ha-gumi'],
  'ckb' => const ['ckb-bamoki'],
  'ps' => const ['ps-rowwad'],
  'sw' => const ['sw-rowwad'],
  'kk' => const ['kk-altai'],
  'uz' => const ['uz-rowwad'],
  'so' => const ['so-yaqoub'],
  'nl' => const ['nl-rowwad'],
  'ko' => const ['ko-hamid'],
  'ja' => const ['ja-sato'],
  'el' => const ['el-rowwad'],
  'pt' => const ['pt-nasr'],
  'zh' => const ['zh-suliman'],
  // Danish: no translation found that may be shipped (2026-11-01).
  _ => const ['en-rowwad'],
};

/// The bundled tafsir shown by default for each language: Al-Muyassar for
/// Arabic, Al-Mukhtasar where it exists in the language; Urdu,
/// Ahsan-ul-Bayan; German and the languages with none, the English
/// Al-Mukhtasar. (Arabic also has al-Sirāj's word meanings, chosen in the
/// tafsir list.)
String? defaultTafsirId(String language) => switch (language) {
  'ar' => 'ar-muyassar',
  'en' => 'en-mukhtasar',
  'id' => 'id-mukhtasar',
  'tr' => 'tr-mukhtasar',
  'fr' => 'fr-mukhtasar',
  'es' => 'es-mukhtasar',
  'ru' => 'ru-mukhtasar',
  'fa' => 'fa-mukhtasar',
  'bn' => 'bn-mukhtasar',
  'de' => 'en-mukhtasar',
  'ur' => 'ur-ahsanulbayan',
  'ckb' => 'ckb-mukhtasar',
  'ps' => 'ps-mukhtasar',
  'uz' => 'uz-mukhtasar',
  'ja' => 'ja-mukhtasar',
  // Malay, Hausa, Swahili, Kazakh, Somali (2026-10-25), Dutch, Korean,
  // Greek, Portuguese and Danish (2026-11-01), Chinese (2026-11-07): no
  // Al-Mukhtasar.
  _ => 'en-mukhtasar',
};
