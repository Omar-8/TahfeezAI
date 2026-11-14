import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/supported_locales.dart';
import 'package:tahfeez_ai/quran/domain/surah_aims.dart';

/// The bundled surah aims: Al-Mukhtasar's own (from QuranEnc and the
/// Tafsir Center's API) in the languages its editions have them in, and
/// Tahfeez AI's translations of the English where they have none — every
/// surah in every interface language, the translations marked as such.
void main() {
  final json = jsonDecode(
    File('assets/quran/surah_aims.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final aims = SurahAims.fromJson(json);

  test('every interface language, all 114 surahs', () {
    for (final locale in kTahfeezSupportedLocales) {
      for (var surah = 1; surah <= 114; surah++) {
        expect(
          aims.of(surah, locale.languageCode)?.trim(),
          isNotEmpty,
          reason: '${locale.languageCode} $surah',
        );
      }
    }
  });

  test('as published: Yusuf\'s, in Arabic, Turkish and English', () {
    expect(
      aims.of(12, 'ar'),
      'الاعتبار بلطف تدبير الله لأوليائه وتمكينهم، وحسن عاقبتهم.',
    );
    expect(aims.of(12, 'tr'), startsWith('Allah\'ın veli kullarının'));
    expect(
      aims.of(12, 'en'),
      'Recognizing Allah\'s kindness in managing His allies and establishing '
      'them towards a noble end.',
    );
  });

  test('Tahfeez AI\'s translations: the six languages no edition has, and '
      'Korean\'s 2–35 — nothing else', () {
    for (final language in ['ms', 'kk', 'so', 'nl', 'da', 'el']) {
      for (var surah = 1; surah <= 114; surah++) {
        expect(aims.isTranslated(surah, language), isTrue);
      }
    }
    for (var surah = 1; surah <= 114; surah++) {
      expect(
        aims.isTranslated(surah, 'ko'),
        surah >= 2 && surah <= 35,
        reason: 'ko $surah',
      );
      for (final language in ['ar', 'en', 'fr', 'ur', 'zh', 'sw']) {
        expect(aims.isTranslated(surah, language), isFalse);
      }
    }
    // Korean's own, from its edition, kept.
    expect(aims.of(114, 'ko'), startsWith('이 장은 사탄과'));
  });

  test('no such surah or language: none', () {
    expect(aims.of(0, 'ar'), isNull);
    expect(aims.of(115, 'ar'), isNull);
    expect(aims.of(1, 'xx'), isNull);
  });
}
