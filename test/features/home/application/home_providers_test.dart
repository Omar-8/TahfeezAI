import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/application/home_providers.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  group('dailyAyahSurahNoForDate', () {
    test('always returns a valid 1-114 chapter number', () {
      for (var i = 0; i < 400; i++) {
        final date = DateTime(2024, 1, 1).add(Duration(days: i));
        final surahNo = dailyAyahSurahNoForDate(date);
        expect(surahNo, inInclusiveRange(1, 114));
      }
    });

    test('is deterministic for the same calendar day', () {
      final a = dailyAyahSurahNoForDate(DateTime(2026, 3, 14, 9));
      final b = dailyAyahSurahNoForDate(DateTime(2026, 3, 14, 21));
      expect(a, b);
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

      test(
        'readHistoryPreview and outdatedResourceSummaries are empty',
        () async {
          expect(
            await container.read(readHistoryPreviewProvider.future),
            isEmpty,
          );
          expect(
            await container.read(outdatedResourceSummariesProvider.future),
            isEmpty,
          );
        },
      );
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
      expect(chapters.first.surah.surahNo, 1);
      expect(chapters.first.name, 'Test Chapter One');
    });
  });
}
