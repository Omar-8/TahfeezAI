import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/recitation_score.dart';
import 'package:tahfeez_ai/quran/application/surah_aims_provider.dart';
import 'package:tahfeez_ai/quran/domain/surah_aims.dart';

import '../test_helpers/real_app.dart';

/// About a surah: tapping its name at its start (Ayah mode), or "About this
/// surah" in Go to — its facts from the bundled data, then Read.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  // The bundled aims, read here (the app reads them off the UI thread,
  // which a test's clock does not wait for).
  final aims = surahAimsProvider.overrideWith(
    (ref) async => SurahAims.fromJson(
      jsonDecode(File('assets/quran/surah_aims.json').readAsStringSync())
          as Map<String, Object?>,
    ),
  );

  Finder fact(String label, String value) => find.ancestor(
    of: find.text(value),
    matching: find.ancestor(of: find.text(label), matching: find.byType(Row)),
  );

  testWidgets('As-Sajdah\'s name tapped in Ayah mode: Meccan, 30 ayahs, its '
      'sajdah at ayah 15, juz 21', (tester) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/32',
      mode: ReaderMode.ayah,
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-32')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-32')), findsOneWidget);
    expect(fact('Revealed in', 'Meccan'), findsOneWidget);
    expect(fact('Order of revelation', '75'), findsOneWidget);
    expect(fact('Ayahs', '30'), findsOneWidget);
    expect(fact('Sajdah', 'Ayah 15'), findsOneWidget);
    expect(fact('Juz', '21'), findsOneWidget);
    expect(find.text('The Prostration'), findsOneWidget, reason: 'its meaning');
    await RealApp.quit(tester);
  });

  testWidgets('from Go to: the chosen surah\'s facts; Read opens it', (
    tester,
  ) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/1',
      mode: ReaderMode.ayah,
    );
    // The title opens Go to; its surah is the one read.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Al-Faatiha'),
      ),
    );
    await RealApp.settle(tester);
    await tester.tap(find.byKey(const ValueKey('jump-surah-info')));
    await RealApp.settle(tester);
    expect(fact('Ayahs', '7'), findsOneWidget);
    expect(find.byKey(const ValueKey('surah-info-sajdah')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('surah-info-read')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-1')), findsNothing);
    await RealApp.quit(tester);
  });

  testWidgets('its aims, Al-Mukhtasar\'s, in the app\'s language; where '
      'no edition has them, Tahfeez AI\'s translation (Dutch)', (tester) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/12',
      mode: ReaderMode.ayah,
      locale: 'ar',
      overrides: [aims],
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-12')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-aims')), findsOneWidget);
    expect(find.text('مقاصد السورة'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('surah-info-aims-text')))
          .data,
      'الاعتبار بلطف تدبير الله لأوليائه وتمكينهم، وحسن عاقبتهم.',
    );
    await RealApp.quit(tester);

    await RealApp.launch(
      tester,
      route: '/quran/surah/12',
      mode: ReaderMode.ayah,
      overrides: [aims],
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-12')));
    await RealApp.settle(tester);
    // English: the Tafsir Center's own.
    expect(find.text('Aims of the surah'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('surah-info-aims-text')))
          .data,
      startsWith('Recognizing Allah\'s kindness'),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('surah-info-aims-source')))
          .data,
      contains('Tafsir Center'),
    );
    await RealApp.quit(tester);

    await RealApp.launch(
      tester,
      route: '/quran/surah/12',
      mode: ReaderMode.ayah,
      locale: 'nl',
      overrides: [aims],
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-12')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('surah-info-aims')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('surah-info-aims-source')))
          .data,
      'Vertaald door TahfeezAI',
    );
    await RealApp.quit(tester);
  });

  testWidgets('a long surah\'s aims on a small phone, large text (French): '
      'the sheet scrolls, nothing overflows', (tester) async {
    await RealApp.launch(
      tester,
      route: '/quran/surah/2',
      mode: ReaderMode.ayah,
      locale: 'fr',
      size: const Size(320, 640),
      textScale: 2,
      overrides: [aims],
    );
    await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-2')));
    await RealApp.settle(tester);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('surah-info-read')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('surah-info-2')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('surah-info-aims')), findsOneWidget);
    await RealApp.quit(tester);
  });

  for (final (locale, ayahs, memorized) in [
    ('en', '7', '6 of 7 ayahs memorized'),
    ('ar', '7', null),
  ]) {
    testWidgets('$locale: the memorization line in the values\' column, '
        'below the numbers', (tester) async {
      await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        mode: ReaderMode.ayah,
        locale: locale,
        // A smaller phone, larger text: the line wraps.
        size: const Size(360, 780),
        textScale: 1.3,
        overrides: [
          surahProgressProvider.overrideWith(
            (ref) async => {
              1: const SurahProgress(
                ayahs: 7,
                memorized: 6,
                latest: RecitationScore(),
              ),
            },
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('ayah-mode-surah-info-1')));
      await RealApp.settle(tester);
      final rtl = locale == 'ar';
      // Where its first letter is drawn (not its box: text aligned to the
      // box's far side starts there).
      double start(Finder f) {
        final paragraph = tester.renderObject<RenderParagraph>(f);
        final first = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .first;
        final at = paragraph.localToGlobal(Offset.zero);
        return rtl ? at.dx + first.right : at.dx + first.left;
      }

      final count = find.descendant(
        of: find.byKey(const ValueKey('surah-info-ayahs')),
        matching: find.byType(Text),
      );
      final line = find.descendant(
        of: find.byKey(const ValueKey('surah-info-memorized')),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(count.last).data, contains(ayahs));
      if (memorized != null) {
        expect(tester.widget<Text>(line.last).data, memorized);
      }
      expect(start(line.last), moreOrLessEquals(start(count.last)));
      await RealApp.quit(tester);
    });
  }
}
