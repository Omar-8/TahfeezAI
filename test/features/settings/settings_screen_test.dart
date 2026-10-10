import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
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

    // The language list: each with its flag.
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    for (final name in ['Deutsch', 'Français', 'Türkçe', 'اردو']) {
      expect(find.text(name), findsWidgets);
    }
    await tester.tap(find.text('العربية').last);
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), const Locale('ar'));
    expect(find.text('اللغة'), findsOneWidget); // "Language", now in Arabic
    expect(find.text('داكن'), findsOneWidget); // "Dark"

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-language')));
    await tester.pumpAndSettle();
    // Back to the system language.
    await tester.tap(find.text('لغة النظام').last);
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
    final about = find.byKey(const ValueKey('settings-about'));
    await tester.scrollUntilVisible(about, 200);
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    // The privacy essentials, then the sources.
    expect(find.byKey(const ValueKey('about-privacy')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('The Quran text'), 200);
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

  testWidgets('Reset all data asks first, then clears every setting but the '
      'installed Quran\'s marker', (tester) async {
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
    final storage = container.read(browserStorageProvider);
    await storage.setString('core.theme_mode', 'dark');
    await storage.setString('quran.dataset.seeded_version', 'v1');

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final reset = find.byKey(const ValueKey('settings-reset'));
    await tester.scrollUntilVisible(reset, 200);
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('Reset all data?'), findsOneWidget);

    // Cancel keeps everything.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await storage.getString('core.theme_mode'), 'dark');

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-reset-confirm')));
    await tester.pumpAndSettle();
    expect(await storage.getString('core.theme_mode'), isNull);
    expect(await storage.getString('quran.dataset.seeded_version'), 'v1');
    expect(
      find.text('All data reset. Reload the app to start fresh.'),
      findsOneWidget,
    );
  });
}
