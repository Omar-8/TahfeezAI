import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/quran_location_routing.dart';
import 'package:tahfeez_ai/features/quran/presentation/quran_index_screen.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  Widget wrap(QuranDatabase db) {
    final router = GoRouter(
      initialLocation: '/quran',
      routes: [
        GoRoute(
          path: '/quran',
          builder: (context, state) => const QuranIndexScreen(),
          routes: quranLocationRoutes(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [quranDatabaseProvider.overrideWith((ref) => db)],
      child: MaterialApp.router(
        routerConfig: router,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('shows an unavailable state on the Surah tab with no dataset', (
    tester,
  ) async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(wrap(db));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This will appear automatically once a Quran dataset is added to the app.',
      ),
      findsOneWidget,
    );
  });

  group('with an installed synthetic dataset', () {
    late QuranDatabase db;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
    });

    tearDown(() => db.close());

    testWidgets('lists chapters and filters by search text', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      expect(find.text('Test Chapter One'), findsOneWidget);
      expect(find.text('Surah 2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();

      expect(find.text('Test Chapter One'), findsOneWidget);
      expect(find.text('Surah 2'), findsNothing);
    });

    testWidgets('filters by revelation type', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // Surah 1 is Meccan (odd), Surah 2 is Medinan (even) per the fixture.
      await tester.tap(find.text('Medinan'));
      await tester.pumpAndSettle();

      expect(find.text('Test Chapter One'), findsNothing);
      expect(find.text('Surah 2'), findsOneWidget);
    });

    testWidgets('tapping a chapter navigates to its QuranLocation', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Chapter One'));
      await tester.pumpAndSettle();

      // Navigates to the real Reader (Milestone 6), not a stub: its app
      // bar shows the location and its chapter-info card shows the real
      // chapter name loaded from the (synthetic) dataset.
      expect(find.text('Surah 1'), findsOneWidget);
      expect(find.text('Test Chapter One'), findsOneWidget);
    });

    testWidgets('the Juz tab lists the fixture\'s one Juz', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Juz'));
      await tester.pumpAndSettle();

      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('Starts at Surah 1, Ayah 1'), findsOneWidget);
    });

    testWidgets('the Hizb tab lists the fixture\'s one Hizb', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hizb'));
      await tester.pumpAndSettle();

      expect(find.text('Hizb 1'), findsOneWidget);
    });

    testWidgets('Go to Ayah validates and navigates to a valid verse', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Go to Ayah'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('goToAyahChapterField')),
        '1',
      );
      await tester.enterText(find.byKey(const Key('goToAyahVerseField')), '3');
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Ayah 1:3'), findsOneWidget);
    });

    testWidgets('Go to Ayah rejects an out-of-range verse', (tester) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Go to Ayah'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('goToAyahChapterField')),
        '1',
      );
      await tester.enterText(
        find.byKey(const Key('goToAyahVerseField')),
        '999',
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(
        find.text('That chapter/verse combination is invalid.'),
        findsOneWidget,
      );
    });
  });
}
