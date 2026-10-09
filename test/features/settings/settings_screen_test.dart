import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/app_typography.dart';
import 'package:tahfeez_ai/quran/application/ayah_sheet_content.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/settings/domain/credits.dart';
import 'package:tahfeez_ai/features/settings/presentation/about_screen.dart';

import '../../test_helpers/widget_test_overrides.dart';

void main() {
  testWidgets('the Settings tab sets the theme and the language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.system);

    Finder appTheme(String name) => find.descendant(
      of: find.byKey(const ValueKey('settings-app-theme')),
      matching: find.text(name),
    );
    await tester.tap(appTheme('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Language'))).brightness,
      Brightness.dark,
    );

    // Black: the dark theme on black paper.
    await tester.tap(appTheme('Black'));
    await tester.pumpAndSettle();
    expect(container.read(appSurfaceToneProvider), AppSurfaceTone.black);
    expect(
      Theme.of(tester.element(find.text('Language'))).colorScheme.surface,
      const Color(0xFF000000),
    );

    // Warm: a light theme again.
    await tester.tap(appTheme('Warm'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Language'))).colorScheme.surface,
      const Color(0xFFFBF1DE),
    );

    // The Arabic UI font: the app's text falls back to it.
    expect(container.read(arabicFontControllerProvider), ArabicUiFont.kufi);
    final tajawal = find.byKey(const ValueKey('settings-arabic-font-tajawal'));
    await tester.ensureVisible(tajawal);
    await tester.tap(tajawal);
    await tester.pumpAndSettle();
    expect(container.read(arabicFontControllerProvider), ArabicUiFont.tajawal);
    expect(
      Theme.of(tester.element(tajawal)).textTheme.bodyLarge?.fontFamilyFallback,
      ['Tajawal'],
    );

    // Translation & tafsir: what a long-pressed ayah shows.
    expect(container.read(ayahSheetContentProvider), AyahSheetContent.both);
    final tafsirOnly = find.descendant(
      of: find.byKey(const ValueKey('settings-ayah-sheet-content')),
      matching: find.text('Tafsir'),
    );
    await tester.ensureVisible(tafsirOnly);
    await tester.tap(tafsirOnly);
    await tester.pumpAndSettle();
    expect(container.read(ayahSheetContentProvider), AyahSheetContent.tafsir);

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), const Locale('ar'));
    expect(find.text('اللغة'), findsOneWidget); // "Language", now in Arabic
    expect(find.text('داكن'), findsOneWidget); // "Dark"

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لغة النظام')); // back to the system language
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), isNull);
  });

  testWidgets('About lists every source with its licence, and the licences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    registerCreditLicences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: tahfeezWidgetTestOverrides(),
        child: const TahfeezApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About'), 200);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('The Quran text'), findsOneWidget);
    // Every source is listed, scrolling down the page.
    for (final c in credits) {
      await tester.scrollUntilVisible(find.text(c.name), 300);
      expect(find.text(c.name), findsOneWidget);
    }
    expect(find.textContaining('Licence:'), findsWidgets);
    // Flutter's licence page carries the sources' notices.
    final notices = await LicenseRegistry.licenses
        .where((l) => l.packages.any((p) => p.startsWith('Tahfeez:')))
        .length;
    expect(notices, credits.length);
  });
}
