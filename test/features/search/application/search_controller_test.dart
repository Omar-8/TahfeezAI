import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/search/application/search_controller.dart';
import 'package:tahfeez_ai/features/search/application/search_history_controller.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/search_index_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/search_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

void main() {
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup.read(browserStorageProvider).remove('search.history');
    cleanup.dispose();
  });

  ProviderContainer makeContainer() {
    final quranDb = QuranDatabase(NativeDatabase.memory());
    final translationDb = TranslationDatabase(NativeDatabase.memory());
    final indexDb = SearchIndexDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => quranDb),
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        searchIndexDatabaseProvider.overrideWith((ref) => indexDb),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(quranDb.close);
    addTearDown(translationDb.close);
    addTearDown(indexDb.close);
    return container;
  }

  test(
    'an empty query returns empty results without touching the index',
    () async {
      final container = makeContainer();
      final results = await container.read(
        searchControllerProvider('   ').future,
      );
      expect(results.isEmpty, isTrue);
    },
  );

  test('indexes the Arabic text on first search and returns hits', () async {
    final container = makeContainer();
    await const QuranDatasetImporter().import(
      container.read(quranDatabaseProvider),
      buildValidSyntheticPayload(),
    );

    final results = await container.read(
      searchControllerProvider('lafz').future,
    );

    expect(results.arabicHits, isNotEmpty);
    expect(
      await container
          .read(searchRepositoryProvider)
          .isQuranTextIndexed(scriptCode: testScriptCode),
      isTrue,
    );
  });

  test('recordInHistory adds the query to search history', () async {
    final container = makeContainer();
    await const QuranDatasetImporter().import(
      container.read(quranDatabaseProvider),
      buildValidSyntheticPayload(),
    );
    await container.read(searchControllerProvider('lafz').future);

    await container
        .read(searchControllerProvider('lafz').notifier)
        .recordInHistory();

    final history = container.read(searchHistoryControllerProvider);
    expect(history.map((e) => e.query), contains('lafz'));
  });
}
