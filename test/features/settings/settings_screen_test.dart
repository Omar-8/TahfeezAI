import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';

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
    Finder quranTheme(String name) => find.descendant(
      of: find.byKey(const ValueKey('settings-quran-theme')),
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

    // The Quran page's theme is its own: sepia pages in a black app.
    final before = container.read(mushafAppearanceControllerProvider);
    await tester.ensureVisible(quranTheme('Sepia'));
    await tester.tap(quranTheme('Sepia'));
    await tester.pumpAndSettle();
    expect(before, isNot(MushafAppearance.sepia));
    expect(
      container.read(mushafAppearanceControllerProvider),
      MushafAppearance.sepia,
    );
    expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    expect(container.read(appSurfaceToneProvider), AppSurfaceTone.black);

    // Warm: a light theme again.
    await tester.tap(appTheme('Warm'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeControllerProvider), ThemeMode.light);
    expect(
      Theme.of(tester.element(find.text('Language'))).colorScheme.surface,
      const Color(0xFFFBF1DE),
    );

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), const Locale('ar'));
    expect(find.text('اللغة'), findsOneWidget); // "Language", now in Arabic
    expect(find.text('داكن'), findsNWidgets(2)); // "Dark", for both themes

    await tester.tap(find.text('لغة النظام')); // back to the system language
    await tester.pumpAndSettle();
    expect(container.read(localeControllerProvider), isNull);
  });
}
