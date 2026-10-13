import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/theme/app_typography.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_appearance_sheet.dart';

void main() {
  testWidgets("Ayah mode's view settings: the Arabic font chosen there is "
      "Settings' own; the Quran font its own", (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(readerModeProvider);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMushafAppearanceSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ayah-view-text-size')), findsOneWidget);
    final almarai = find.byKey(const ValueKey('settings-arabic-font-almarai'));
    await tester.ensureVisible(almarai);
    await tester.tap(almarai);
    await tester.pumpAndSettle();
    expect(container.read(arabicFontControllerProvider), ArabicUiFont.almarai);

    // The Quran text's own font, beside it.
    final amiri = find.byKey(const ValueKey('ayah-view-quran-font-amiri'));
    await tester.ensureVisible(amiri);
    await tester.tap(amiri);
    await tester.pumpAndSettle();
    expect(
      container.read(ayahViewPreferencesProvider).quranFont,
      QuranFont.amiri,
    );
  });
}
