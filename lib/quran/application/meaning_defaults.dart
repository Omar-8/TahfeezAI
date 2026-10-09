import 'dart:ui' show PlatformDispatcher;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/localization/locale_controller.dart';

/// The language meaning (translation and tafsir) defaults follow: the app's
/// chosen language, else the phone's — including one the app's own
/// interface doesn't offer (e.g. Urdu).
String meaningLanguage(Ref ref) =>
    ref.read(localeControllerProvider)?.languageCode ??
    PlatformDispatcher.instance.locale.languageCode;

/// The bundled translation shown by default for each language; none for
/// Arabic; English for any other.
List<String> defaultTranslationSlugs(String language) => switch (language) {
  'ar' => const [],
  'de' => const ['de-rowwad'],
  'ur' => const ['ur-junagarhi'],
  'id' => const ['id-affairs'],
  'tr' => const ['tr-rowwad'],
  'fr' => const ['fr-noor'],
  _ => const ['en-rowwad'],
};

/// The bundled tafsir shown by default for each language: Al-Muyassar for
/// Arabic, Al-Mukhtasar where it exists in the language, none otherwise
/// (Urdu, German).
String? defaultTafsirId(String language) => switch (language) {
  'ar' => 'ar-muyassar',
  'en' => 'en-mukhtasar',
  'id' => 'id-mukhtasar',
  'tr' => 'tr-mukhtasar',
  'fr' => 'fr-mukhtasar',
  'ur' || 'de' => null,
  _ => 'en-mukhtasar',
};
