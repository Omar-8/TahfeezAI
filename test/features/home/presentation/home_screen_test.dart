import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/theme/app_theme.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';
import 'package:tahfeez_ai/features/home/presentation/home_screen.dart';

import '../../../test_helpers/widget_test_overrides.dart';

void main() {
  Widget wrap({Locale locale = const Locale('en'), Brightness? brightness}) {
    return ProviderScope(
      overrides: tahfeezWidgetTestOverrides(),
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: const Scaffold(body: HomeScreen()),
      ),
    );
  }

  testWidgets('renders every section with the Quran dataset uninstalled', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The app's name heads the page, the salam below it.
    expect(find.text('TahfeezAI'), findsOneWidget);
    expect(
      find.text('Assalamu alaikum wa rahmatullahi wa barakatuh'),
      findsOneWidget,
    );

    // Section headers for every information-hierarchy item this milestone
    // requires (resource updates has no header -- it hides itself).
    expect(find.text('Daily Ayah'), findsOneWidget);
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Memorization'), findsOneWidget);
    expect(find.text('Featured Reading'), findsOneWidget);

    // No Quran dataset is installed in this test's (empty) in-memory
    // database, so every Quran-data-dependent section shows its honest
    // unavailable/empty state rather than fabricated content.
    expect(
      find.text(
        'This will appear automatically once a Quran dataset is added to the app.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your reading history will appear here once you start reading.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Featured passages will appear once a Quran dataset is installed.',
      ),
      findsOneWidget,
    );

    // Today's memorization: nothing memorized and no plan yet, with the
    // way into the Memorize tab.
    expect(find.byKey(const ValueKey('home-mem-empty')), findsOneWidget);
    expect(find.text('Open Memorize'), findsOneWidget);

    // No resource-update banner: `outdatedResourceSummariesProvider`
    // resolves to an empty list.
    expect(find.byType(TahfeezCard), findsWidgets);
  });

  testWidgets('renders correctly in an RTL (Arabic) locale', (tester) async {
    await tester.pumpWidget(wrap(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
    );
    expect(find.text('تحفيظ AI'), findsOneWidget);
    expect(find.text('آية اليوم'), findsOneWidget);
  });

  testWidgets('renders without error in dark mode', (tester) async {
    await tester.pumpWidget(wrap(brightness: Brightness.dark));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
