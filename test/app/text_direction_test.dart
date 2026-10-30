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
}
