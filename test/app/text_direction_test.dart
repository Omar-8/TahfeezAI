import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/application/home_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/application/translation_selection_controller.dart';

import '../test_helpers/real_app.dart';

/// A translation or tafsir is laid out in its own language's direction,
/// whatever the app's: Arabic tafsir right to left in the English app, an
/// English translation left to right in the Arabic one.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  testWidgets('Arabic tafsir in the English app: right to left', (
    tester,
  ) async {
    final container = await RealApp.launch(
      tester,
      route: '/quran/surah/1',
      mode: ReaderMode.ayah,
    );
    await container
        .read(tafsirSelectionControllerProvider.notifier)
        .select('ar-muyassar');
    await RealApp.settle(tester);
    final tafsir = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('ayah-mode-tafsir-1:1')),
        matching: find.byType(Text),
      ),
    );
    expect(tafsir.textDirection, TextDirection.rtl);
    await RealApp.quit(tester);
  });

  testWidgets("The Daily Ayah's English translation in the Arabic app: left "
      'to right', (tester) async {
    final container = await RealApp.launch(tester, locale: 'ar');
    if (!container
        .read(translationSelectionControllerProvider)
        .contains('en-rowwad')) {
      await container
          .read(translationSelectionControllerProvider.notifier)
          .toggle('en-rowwad');
    }
    await RealApp.settle(tester);
    // Today's ayah's translation, whatever its length (94:5's is 40 letters).
    final daily = container.read(dailyAyahProvider).value;
    expect(daily?.translationLanguage, 'en');
    final translations = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data == daily!.translation)
        .toList();
    expect(translations, isNotEmpty, reason: 'the translation on Home');
    expect(translations.first.textDirection, TextDirection.ltr);
    await RealApp.quit(tester);
  });

  // Ayah mode's page buttons read as a Mushaf's pages turn: «< Next» on the
  // left, «Previous >» on the right, each arrow pointing its way in every
  // language — a chevron icon flips itself in a right-to-left one
  // (owner, 2026-11-18).
  for (final locale in ['en', 'ar', 'ur', 'fa']) {
    testWidgets("$locale: Ayah mode's page buttons point their way", (
      tester,
    ) async {
      await RealApp.launch(
        tester,
        route: '/quran/surah/1',
        mode: ReaderMode.ayah,
        layout: AyahLayout.paged,
        locale: locale,
      );
      final next = find.byKey(const ValueKey('ayah-mode-next-page'));
      final previous = find.byKey(const ValueKey('ayah-mode-previous-page'));
      await tester.scrollUntilVisible(
        next,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(next).dx,
        lessThan(tester.getCenter(previous).dx),
      );
      for (final icon in ['chevron_left', 'chevron_right']) {
        final finder = find.byKey(ValueKey('ayah-mode-$icon'));
        // Not mirrored (a mirrored icon is drawn under a flipping Transform).
        expect(
          find.descendant(of: finder, matching: find.byType(Transform)),
          findsNothing,
          reason: '$icon mirrored in $locale',
        );
      }
      // Each arrow on the outer side of its button's word.
      final left = tester
          .getCenter(find.byKey(const ValueKey('ayah-mode-chevron_left')))
          .dx;
      final right = tester
          .getCenter(find.byKey(const ValueKey('ayah-mode-chevron_right')))
          .dx;
      expect(left, lessThan(tester.getCenter(next).dx));
      expect(right, greaterThan(tester.getCenter(previous).dx));
      await RealApp.quit(tester);
    });
  }
}
