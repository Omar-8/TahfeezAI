// The reader's title pressed (its surah and page): go to a surah and an
// ayah in it, or to a page — the reader replaced by the place chosen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/reader_jump_sheet.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_models.dart';

void main() {
  Future<GoRouter> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/quran/page/1/50',
      routes: [
        GoRoute(
          path: '/quran/page/:m/:p',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('page ${state.pathParameters['p']}'),
                TextButton(
                  onPressed: () => showReaderJumpSheet(
                    context,
                    mushafId: 1,
                    pageNumber: 50,
                    pageCount: 604,
                    surahNo: 3,
                  ),
                  child: const Text('title'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/quran/ayah/:c/:v',
          builder: (context, state) => Text(
            'ayah ${state.pathParameters['c']}:${state.pathParameters['v']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          indexedSurahsProvider.overrideWith(
            (ref) async => [
              for (final (n, name) in const [
                (1, 'Al-Fatiha'),
                (2, 'Al-Baqara'),
                (3, 'Aal-Imran'),
              ])
                IndexedSurah(
                  surah: Surah(
                    surahNo: n,
                    ayahCount: 7,
                    revelationOrder: n,
                    rukusCount: 1,
                    revelationType: RevelationType.meccan,
                  ),
                  arabicName: null,
                  localizedName: name,
                ),
            ],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('title'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a page: from the one being read, stepped, then gone to', (
    tester,
  ) async {
    final router = await open(tester);
    expect(find.text('Page 50'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jump-page-number-plus')));
    await tester.pumpAndSettle();
    expect(find.text('Page 51'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('jump-page')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/quran/page/1/51');
    expect(find.text('page 51'), findsOneWidget);
  });

  testWidgets('an ayah: the surah being read, an ayah stepped to', (
    tester,
  ) async {
    final router = await open(tester);
    expect(find.text('3. Aal-Imran'), findsWidgets);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('loop-jump-ayah-plus')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('jump-ayah')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/quran/ayah/3/3');
    expect(find.text('ayah 3:3'), findsOneWidget);
  });
}
