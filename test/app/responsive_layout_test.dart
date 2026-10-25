import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/fallback_localizations.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/features/listen/presentation/listen_sheet.dart';
import 'package:tahfeez_ai/features/memorize/presentation/mark_known_sheet.dart';
import 'package:tahfeez_ai/features/memorize/presentation/plan_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/memorization/application/memorization_progress.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

import '../test_helpers/widget_test_overrides.dart';

/// Every main screen, on a small phone up to a tablet, at normal and large
/// text, in English and Arabic: laid out without overflow or error, scrolled
/// through to the end.
void main() {
  /// Every layout error this test reports, with the widget it came from.
  final reported = <FlutterErrorDetails>[];
  void recordErrors() {
    reported.clear();
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      reported.add(details);
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Fails with what overflowed (the widget, where), not only that it did.
  void fits(WidgetTester tester, String reason) {
    final error = tester.takeException();
    if (error == null) return;
    final where = [
      for (final d in reported)
        d.toString().split('\n').where((l) => l.contains('file:///')).take(2),
    ].expand((l) => l).toSet().join('\n');
    fail('$reason: $error\n$where');
  }

  const sizes = {
    // A foldable's cover screen: the narrowest in use.
    'narrow phone': Size(280, 653),
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'tablet': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
    'desktop': Size(1440, 900),
  };
  // Every UI language: German, French and Russian run longest; Arabic,
  // Urdu and Persian right to left.
  const locales = [
    'en', 'ar', 'de', 'fr', 'tr', 'ur', 'id', 'es', 'ru', 'fa', 'bn', //
    'ms', 'ha', 'ckb', 'ps', 'sw', 'kk', 'uz', 'so', //
  ];
  const routes = [
    '/home',
    '/quran',
    '/quran/bookmarks',
    '/memorize',
    '/memorize/progress',
    '/settings',
    '/settings/about',
  ];

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    // Up to Android's largest text (200%).
    for (final scale in const [1.0, 1.5, 2.0]) {
      for (final locale in locales) {
        testWidgets('$name, text ×$scale, $locale: every main screen fits', (
          tester,
        ) async {
          recordErrors();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...tahfeezWidgetTestOverrides(),
                localeControllerProvider.overrideWithBuild(
                  (ref, _) => Locale(locale),
                ),
              ],
              child: const TahfeezApp(),
            ),
          );
          await tester.pumpAndSettle();
          final router = ProviderScope.containerOf(
            tester.element(find.byType(TahfeezApp)),
          ).read(appRouterProvider);
          for (final route in routes) {
            router.go(route);
            await tester.pumpAndSettle();
            fits(tester, '$route opens');
            // Down to the end of every scrollable on the screen.
            final scrollables = find.byType(Scrollable);
            for (var i = 0; i < scrollables.evaluate().length; i++) {
              final s = scrollables.at(i);
              final state = tester.state<ScrollableState>(s);
              if (state.position.axis != Axis.vertical) continue;
              for (
                var n = 0;
                n < 40 &&
                    state.position.pixels < state.position.maxScrollExtent;
                n++
              ) {
                await tester.drag(
                  s,
                  Offset(0, -size.height * 0.6),
                  warnIfMissed: false,
                );
                await tester.pumpAndSettle();
              }
              fits(tester, '$route scrolled');
            }
          }
        });
      }
    }
  }

  // The sheets with side-by-side choices, on the smallest phone with large
  // text, in English and Arabic.
  final names = [
    for (final n in const [1, 112, 113, 114])
      IndexedSurah(
        surah: Surah(
          surahNo: n,
          ayahCount: n == 1 ? 7 : 6,
          revelationOrder: n,
          rukusCount: 1,
          revelationType: RevelationType.meccan,
        ),
        arabicName: null,
        localizedName: 'Surah $n',
      ),
  ];
  final sheets = <String, Future<void> Function(BuildContext)>{
    'plan': (c) => showPlanSheet(c),
    'listen': (c) => showListenSheet(c),
    'mark what I know': (c) => showMarkKnownSheet(c),
  };
  for (final MapEntry(key: sheet, value: open) in sheets.entries) {
    for (final locale in locales) {
      testWidgets('small phone, text ×1.5, $locale: the $sheet sheet fits', (
        tester,
      ) async {
        recordErrors();
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.5;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...tahfeezWidgetTestOverrides(),
              indexedSurahsProvider.overrideWith((ref) async => names),
              juzAyahsProvider.overrideWith(
                (ref) async => {
                  30: [for (var a = 1; a <= 6; a++) 114000 + a],
                },
              ),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: const [
                ...AppLocalizations.localizationsDelegates,
                // As the app: Flutter's own strings for the languages it lacks.
                ...kFallbackLocalizationsDelegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => open(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        fits(tester, '$sheet opens');
        final scrollable = find.byType(Scrollable).last;
        for (var n = 0; n < 10; n++) {
          await tester.drag(
            scrollable,
            const Offset(0, -300),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
        }
        fits(tester, '$sheet scrolled');
      });
    }
  }
}
