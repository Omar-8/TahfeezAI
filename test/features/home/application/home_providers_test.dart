import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/application/home_providers.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_session.dart';
import 'package:tahfeez_ai/quran/application/quran_dataset_status.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  group('dailyAyahVerseForDate', () {
    test('always one of the curated references', () {
      for (var i = 0; i < 400; i++) {
        final date = DateTime(2024, 1, 1).add(Duration(days: i));
        expect(dailyAyahReferences, contains(dailyAyahVerseForDate(date)));
      }
    });

    test('is deterministic for the same calendar day, new the next', () {
      final a = dailyAyahVerseForDate(DateTime(2026, 3, 14, 9));
      final b = dailyAyahVerseForDate(DateTime(2026, 3, 14, 21));
      final c = dailyAyahVerseForDate(DateTime(2026, 3, 15, 9));
      expect(a, b);
      expect(c, isNot(a));
    });
  });

  group('featuredOrderFor', () {
    test('Al-Kahf first on a Friday', () {
      final order = featuredOrderFor(DateTime(2026, 10, 9, 12)); // a Friday
      expect(order.first, (18, FeaturedOccasion.friday));
      expect({
        for (final (n, _) in order) n,
      }, featuredReadingSurahNumbers.toSet());
    });

    test('Al-Mulk first in the evening', () {
      final order = featuredOrderFor(DateTime(2026, 10, 7, 21)); // Wednesday
      expect(order.first, (67, FeaturedOccasion.night));
    });

    test('the listed order otherwise', () {
      final order = featuredOrderFor(DateTime(2026, 10, 7, 10));
      expect([for (final (n, _) in order) n], featuredReadingSurahNumbers);
    });
  });

  group('summarizeSessions', () {
    RecitationSession session(DateTime at, int minutes) => RecitationSession(
      id: '$at',
      startedAt: at,
      duration: Duration(minutes: minutes),
    );

    test('the three latest, and this week\'s sessions and minutes', () {
      final now = DateTime(2026, 10, 5, 12);
      final summary = summarizeSessions([
        session(DateTime(2026, 9, 20), 30), // more than a week ago
        session(DateTime(2026, 10, 1), 5),
        session(DateTime(2026, 10, 4), 7),
        session(DateTime(2026, 10, 5, 9), 3),
      ], now);
      expect(summary.recent.map((s) => s.startedAt.day), [5, 4, 1]);
      expect(summary.weekSessions, 3);
      expect(summary.weekMinutes, 15);
    });

    test('nothing yet', () {
      final summary = summarizeSessions(const [], DateTime(2026, 10, 5));
      expect(summary.recent, isEmpty);
      expect(summary.weekSessions, 0);
    });
  });

  group(
    'Home data providers against an empty (uninstalled) Quran database',
    () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer(
          overrides: [
            quranDatabaseProvider.overrideWith(
              (ref) => QuranDatabase(NativeDatabase.memory()),
            ),
          ],
        );
      });

      tearDown(() => container.dispose());

      test('hasInstalledQuranDataset is false', () async {
        final installed = await container.read(
          hasInstalledQuranDatasetProvider.future,
        );
        expect(installed, isFalse);
      });

      test('dailyAyah is null (unavailable-resource state)', () async {
        final ayah = await container.read(dailyAyahProvider.future);
        expect(ayah, isNull);
      });

      test('featuredReadingChapters is empty', () async {
        final chapters = await container.read(
          featuredReadingChaptersProvider.future,
        );
        expect(chapters, isEmpty);
      });

      test('outdatedResourceSummaries is empty', () async {
        expect(
          await container.read(outdatedResourceSummariesProvider.future),
          isEmpty,
        );
      });
    },
  );

  group('Home data providers against an installed Quran dataset', () {
    late QuranDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = QuranDatabase(NativeDatabase.memory());
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      container = ProviderContainer(
        overrides: [quranDatabaseProvider.overrideWith((ref) => db)],
      );
    });

    tearDown(() => container.dispose());

    test('hasInstalledQuranDataset is true', () async {
      final installed = await container.read(
        hasInstalledQuranDatasetProvider.future,
      );
      expect(installed, isTrue);
    });

    test('featuredReadingChapters resolves the surahs that exist', () async {
      final chapters = await container.read(
        featuredReadingChaptersProvider.future,
      );
      // Every entry in `featuredReadingSurahNumbers` (1, 18, 36, 55, 67) is
      // within the synthetic fixture's 114 surahs, so all resolve.
      expect(chapters, hasLength(featuredReadingSurahNumbers.length));
      // Today's order may bring Al-Kahf or Al-Mulk first (featuredOrderFor).
      final first = chapters.firstWhere((c) => c.surah.surahNo == 1);
      expect(first.name, 'Test Chapter One');
    });
  });
}
