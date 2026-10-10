import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  const sizes = {
    'small phone': Size(320, 568),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'tablet': Size(800, 1280),
  };
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
    for (final scale in const [1.0, 1.5]) {
      for (final locale in const ['en', 'ar', 'de', 'ur']) {
        testWidgets('$name, text ×$scale, $locale: every main screen fits', (
          tester,
        ) async {
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
            expect(tester.takeException(), isNull, reason: '$route opens');
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
              expect(tester.takeException(), isNull, reason: '$route scrolled');
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
    for (final locale in const ['en', 'ar', 'de', 'ur']) {
      testWidgets('small phone, text ×1.5, $locale: the $sheet sheet fits', (
        tester,
      ) async {
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        expect(tester.takeException(), isNull, reason: '$sheet opens');
        final scrollable = find.byType(Scrollable).last;
        for (var n = 0; n < 10; n++) {
          await tester.drag(
            scrollable,
            const Offset(0, -300),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '$sheet scrolled');
      });
    }
  }
}
