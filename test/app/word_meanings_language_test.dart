import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_ayah_sheet.dart';
import 'package:tahfeez_ai/quran/application/ayah_reading_extras.dart';
import 'package:tahfeez_ai/wbw/application/active_wbw_pack.dart';

import 'package:tahfeez_ai/wbw/application/arabic_word_gloss.dart';
import 'package:tahfeez_ai/wbw/presentation/word_detail_sheet.dart';

import '../test_helpers/real_app.dart';

/// Word meanings in the app's language (the bundled packs: Quran.com's),
/// English where the language has none, and the word's details a tap
/// away in the ayah sheet.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  for (final (locale, pack, first) in [
    ('ur', 'ur-qurancom', 'ساتھ نام'),
    ('bn', 'bn-qurancom', null),
    ('en', 'en-qurancom', null),
    // No word meanings in German: English's.
    ('de', 'en-qurancom', null),
  ]) {
    testWidgets('$locale: the $pack word meanings', (tester) async {
      final container = await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        locale: locale,
      );
      expect((await container.read(activeWbwPackProvider.future))?.id, pack);
      if (first != null) {
        final meanings = await container.read(
          ayahWordMeaningsProvider(1001).future,
        );
        expect(meanings[0], first);
      }
      await RealApp.quit(tester);
    });
  }

  testWidgets('tr: a word without a Turkish meaning takes the English', (
    tester,
  ) async {
    final container = await RealApp.launch(
      tester,
      route: '/quran/surah/2',
      locale: 'tr',
    );
    final meanings = await container.read(
      ayahWordMeaningsProvider(2004).future,
    );
    expect(meanings[8], 'before you');
    expect(
      (await container.read(ayahWordMeaningsProvider(1001).future))[0],
      'adıyla',
    );
    await RealApp.quit(tester);
  });

  testWidgets('the ayah sheet: a word tapped opens its details', (
    tester,
  ) async {
    await RealApp.launch(tester, route: '/quran/surah/112');
    showAyahDetailSheet(
      tester.element(find.byType(Scaffold).last),
      ayahId: 112001,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ayah-sheet-word-112001:1')));
    await tester.pumpAndSettle();
    expect(find.text('Word details'), findsOneWidget);
    expect(find.text('Ayah 112:1 · Word 2'), findsOneWidget);
    await RealApp.quit(tester);
  });

  testWidgets('ar: a word al-Siraj does not explain shows its ayah from '
      'al-Muyassar', (tester) async {
    final container = await RealApp.launch(
      tester,
      route: '/quran/surah/112',
      locale: 'ar',
    );
    // «قُلْ», 112:1's first word: an everyday word, not in al-Sirāj.
    const word = (ayahId: 112001, wordIndex: 0);
    expect(
      await container.read(
        arabicWordGlossProvider((ayahId: 112001, wordIndex: 0)).future,
      ),
      isNull,
    );
    final muyassar = await container.read(
      arabicAyahMeaningProvider(112001).future,
    );
    expect(muyassar, isNotEmpty);
    showWordDetailSheet(
      tester.element(find.byType(Scaffold).last),
      wordRef: word,
    );
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('word-muyassar')), findsOneWidget);
    expect(find.text('معنى الآية (التفسير الميسر)'), findsOneWidget);
    await RealApp.quit(tester);
  });
}
