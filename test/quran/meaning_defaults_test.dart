import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/supported_locales.dart';
import 'package:tahfeez_ai/quran/application/meaning_defaults.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';

/// Every interface language's default tafsir and translations are built
/// in or packs the app can download — and Chinese has its own Al-Mukhtasar.
void main() {
  final packs =
      (jsonDecode(File('assets/quran/db/manifest.json').readAsStringSync())
              as Map<String, dynamic>)['packs']
          as Map<String, dynamic>;
  // A pack to download, or built into the databases.
  final tafsirs = {
    ...(packs['tafsir'] as Map<String, dynamic>).keys,
    ...MeaningPackKind.tafsir.builtIn,
  };
  final translations = {
    ...(packs['translation'] as Map<String, dynamic>).keys,
    ...MeaningPackKind.translation.builtIn,
  };

  test('each language\'s default tafsir and translations exist', () {
    for (final locale in kTahfeezSupportedLocales) {
      final language = locale.languageCode;
      expect(tafsirs, contains(defaultTafsirId(language)), reason: language);
      for (final slug in defaultTranslationSlugs(language)) {
        expect(translations, contains(slug), reason: language);
      }
    }
  });

  test('Chinese: Al-Mukhtasar in Chinese', () {
    expect(defaultTafsirId('zh'), 'zh-mukhtasar');
  });
}
