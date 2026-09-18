import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
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
}
