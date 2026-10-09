import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/features/reader/presentation/reader_screen.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/routing/quran_location_routing.dart';
import 'package:tahfeez_ai/features/quran/presentation/quran_index_screen.dart';
import 'package:tahfeez_ai/features/reader/application/reader_preferences_controller.dart';
import 'package:tahfeez_ai/features/reader/domain/reader_mode.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/domain/recitation_score.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

/// The Quran index navigates to `ReaderScreen`, which now defaults to
/// `ReaderMode.mushaf` (see `ReaderModePreferenceController`) — fixed to
/// verse-by-verse here since these tests assert verse-by-verse-specific
/// content (the chapter-info card, "Ayah 1:3", …), not Mushaf mode itself.
class _FixedReaderMode extends ReaderModePreferenceController {
  _FixedReaderMode(this._fixed);
  final ReaderMode _fixed;
  @override
  ReaderMode build() => _fixed;
}

void main() {
  Widget wrap(QuranDatabase db, {Map<int, SurahProgress> progress = const {}}) {
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
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        surahProgressProvider.overrideWith((ref) async => progress),
        readerModePreferenceControllerProvider.overrideWith(
          () => _FixedReaderMode(ReaderMode.verseByVerse),
        ),
      ],
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

    testWidgets('a surah worked on shows how much of it is memorized', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          db,
          progress: {
            1: SurahProgress(
              ayahs: 4,
              memorized: 3,
              latest: RecitationScore.of([
                AyahAttempt(
                  ayahId: 1001,
                  sessionId: 's',
                  at: DateTime(2026),
                  grade: AyahGrade.hard,
                  words: 10,
                  pronunciation: 1,
                ),
              ]),
            ),
          },
        ),
      );
      await tester.pumpAndSettle();
      // A ring around its number, the share memorized under it.
      expect(
        find.byKey(const ValueKey('section-card-progress')),
        findsOneWidget,
      );
      expect(find.text('75%'), findsOneWidget, reason: '3 of 4 memorized');
    });

    testWidgets('filters by revelation type via the filter sheet', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(db));
      await tester.pumpAndSettle();

      // The Meccan/Medinan/All choice now lives behind a filter button
      // beside the search bar, not as a permanent chip row.
      await tester.tap(find.byTooltip('Filter chapters'));
      await tester.pumpAndSettle();

      // Surah 1 is Meccan (odd), Surah 2 is Medinan (even) per the fixture.
      // The chip's own label includes a "(count)" suffix, so this matches
      // by prefix rather than the exact old "Medinan" string.
      await tester.tap(find.textContaining('Medinan ('));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1, 1)); // dismiss the sheet
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

      // Navigates to the real Reader, not a stub. (The reader is
      // Mushaf-only -- verse-by-verse mode is disabled -- so its body
      // isn't asserted here, only that the tap opened the Reader.)
      expect(find.byType(ReaderScreen), findsOneWidget);
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

      expect(find.byType(ReaderScreen), findsOneWidget);
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
