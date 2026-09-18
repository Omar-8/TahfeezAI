import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_theme_families.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';

void main() {
  testWidgets(
    'renders the foundation demo screen and reacts to theme/locale changes',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: TahfeezApp()));
      await tester.pumpAndSettle();

      // English by default: the LTR foundation-demo copy is visible.
      expect(find.text('Foundation preview'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Foundation preview'))),
        TextDirection.ltr,
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TahfeezApp)),
      );

      // Switching to Arabic flips the ambient text direction to RTL, proving
      // the RTL foundation is live end-to-end (locale -> MaterialApp -> app
      // bar) rather than only theoretically supported.
      await container
          .read(localeControllerProvider.notifier)
          .setLocale(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(find.text('معاينة الأساس'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('معاينة الأساس'))),
        TextDirection.rtl,
      );

      // Dark mode applies without needing a different widget tree.
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, ThemeMode.dark);
    },
  );

  testWidgets('switching the color family changes the resolved theme', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TahfeezApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );

    final emeraldPrimary = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .colorScheme
        .primary;

    await container
        .read(themeFamilyControllerProvider.notifier)
        .setFamily(TahfeezThemeFamily.burgundy);
    await tester.pumpAndSettle();

    final burgundyPrimary = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .theme!
        .colorScheme
        .primary;
    expect(burgundyPrimary, isNot(emeraldPrimary));
  });

  testWidgets('the dynamic-color preference can be toggled without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: TahfeezApp()));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );

    // No dynamic scheme is available in the test environment, so this
    // exercises the "requested but unavailable -> falls back to the
    // selected family" path rather than a real OS palette.
    await container
        .read(dynamicColorPreferenceControllerProvider.notifier)
        .setEnabled(true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TahfeezApp), findsOneWidget);
  });

  testWidgets(
    'the "open component gallery" button navigates to the gallery route',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: TahfeezApp()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Open component gallery'));
      await tester.tap(find.text('Open component gallery'));

      // Not pumpAndSettle(): the gallery screen this navigates to
      // permanently shows an indeterminate CircularProgressIndicator (by
      // design -- see ComponentGalleryScreen's loading-state demo), which
      // schedules a new frame forever and would make pumpAndSettle time out.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Component gallery'), findsOneWidget);
    },
  );
}
