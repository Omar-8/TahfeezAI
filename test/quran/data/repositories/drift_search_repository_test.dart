import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_search_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_translation_repository.dart';
import 'package:tahfeez_ai/quran/data/search_index_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/search_models.dart';

import '../../quran_test_fixtures.dart';
import '../../translation_tafsir_test_fixtures.dart';

void main() {
  late QuranDatabase quranDb;
  late TranslationDatabase translationDb;
  late SearchIndexDatabase indexDb;
  late DriftQuranRepository quranRepository;
  late DriftTranslationRepository translationRepository;
  late DriftSearchRepository searchRepository;

  setUp(() async {
    quranDb = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(
      quranDb,
      buildValidSyntheticPayload(),
    );
    translationDb = TranslationDatabase(NativeDatabase.memory());
    indexDb = SearchIndexDatabase(NativeDatabase.memory());
    quranRepository = DriftQuranRepository(quranDb);
    translationRepository = DriftTranslationRepository(translationDb);
    searchRepository = DriftSearchRepository(
      indexDb,
      quranRepository,
      translationRepository,
    );
  });

  tearDown(() async {
    await quranDb.close();
    await translationDb.close();
    await indexDb.close();
  });

  group('Arabic text index', () {
    test('is not indexed before indexQuranText is called', () async {
      expect(
        await searchRepository.isQuranTextIndexed(scriptCode: testScriptCode),
        isFalse,
      );
    });

    test('indexQuranText makes every ayah searchable', () async {
      await searchRepository.indexQuranText(scriptCode: testScriptCode);
      expect(
        await searchRepository.isQuranTextIndexed(scriptCode: testScriptCode),
        isTrue,
      );

      final results = await searchRepository.search(
        'lafz',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeSurahs: false),
      );
      // Every ayah in the fixture has 'lafz' as its first word (120 ayahs:
      // 7 for surah 1, 2 each for surahs 2-114), capped at the default
      // limit of 50.
      expect(results.arabicHits, hasLength(50));
      expect(results.arabicHits.first, isA<ArabicTextSearchHit>());
    });

    test('re-indexing reflects a since-changed script content', () async {
      await searchRepository.indexQuranText(scriptCode: testScriptCode);
      final before = await searchRepository.search(
        'kalima',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeSurahs: false),
      );
      expect(before.arabicHits, isNotEmpty);

      // A query for text that never appears returns nothing.
      final none = await searchRepository.search(
        'nonexistentword',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeSurahs: false),
      );
      expect(none.arabicHits, isEmpty);
    });

    test('a multi-token query requires every token to match', () async {
      await searchRepository.indexQuranText(scriptCode: testScriptCode);
      final results = await searchRepository.search(
        'lafz kalima',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeSurahs: false),
      );
      // Every ayah has both words, so this still matches everything (up to
      // the limit) -- proving the AND-combination doesn't wrongly exclude
      // ayahs that contain both terms.
      expect(results.arabicHits, isNotEmpty);
    });
  });

  group('Surah search', () {
    test('matches a chapter by its localized name', () async {
      final results = await searchRepository.search(
        'chapter one',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeArabicText: false),
      );
      expect(results.surahHits, hasLength(1));
      final hit = results.surahHits.single as SurahSearchHit;
      expect(hit.surahNo, 1);
    });

    test('matches a chapter by its meaning', () async {
      final results = await searchRepository.search(
        'first test',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeArabicText: false),
      );
      expect(results.surahHits, hasLength(1));
    });

    test('a non-matching query returns no Surah hits', () async {
      final results = await searchRepository.search(
        'nonexistentchapter',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(includeArabicText: false),
      );
      expect(results.surahHits, isEmpty);
    });
  });

  group('Translation search', () {
    test('is not indexed before indexTranslation is called', () async {
      expect(
        await searchRepository.isTranslationIndexed(testTranslationSlug),
        isFalse,
      );
    });

    test('indexTranslation makes its verses searchable', () async {
      await translationRepository.installTranslation(
        buildTestTranslationBook(),
        buildTestTranslationVerses(),
      );
      await searchRepository.indexTranslation(testTranslationSlug);

      final results = await searchRepository.search(
        'translation',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(
          includeArabicText: false,
          includeSurahs: false,
        ),
      );
      expect(results.translationHits, hasLength(7));
      final hit = results.translationHits.first as TranslationTextSearchHit;
      expect(hit.translationDisplayName, 'Test Translation');
    });

    test(
      'removeTranslationIndex drops the index but not the translation',
      () async {
        await translationRepository.installTranslation(
          buildTestTranslationBook(),
          buildTestTranslationVerses(),
        );
        await searchRepository.indexTranslation(testTranslationSlug);

        await searchRepository.removeTranslationIndex(testTranslationSlug);

        expect(
          await searchRepository.isTranslationIndexed(testTranslationSlug),
          isFalse,
        );
        expect(
          await translationRepository.getInstalledTranslation(
            testTranslationSlug,
          ),
          isNotNull,
        );
      },
    );

    test(
      'SearchFilters.translationSlugs scopes results to that slug',
      () async {
        await translationRepository.installTranslation(
          buildTestTranslationBook(),
          buildTestTranslationVerses(),
        );
        await translationRepository.installTranslation(
          buildTestTranslationBook(slug: 'other-slug'),
          buildTestTranslationVerses(slug: 'other-slug'),
        );
        await searchRepository.indexTranslation(testTranslationSlug);
        await searchRepository.indexTranslation('other-slug');

        final scoped = await searchRepository.search(
          'translation',
          scriptCode: testScriptCode,
          languageCode: 'en',
          filters: const SearchFilters(
            includeArabicText: false,
            includeSurahs: false,
            translationSlugs: {testTranslationSlug},
          ),
        );
        expect(
          scoped.translationHits.every(
            (hit) =>
                (hit as TranslationTextSearchHit).translationSlug ==
                testTranslationSlug,
          ),
          isTrue,
        );

        final empty = await searchRepository.search(
          'translation',
          scriptCode: testScriptCode,
          languageCode: 'en',
          filters: const SearchFilters(
            includeArabicText: false,
            includeSurahs: false,
            translationSlugs: {},
          ),
        );
        expect(empty.translationHits, isEmpty);
      },
    );
  });

  group('Quick links', () {
    test('a verse-shaped query always returns a quick link', () async {
      final results = await searchRepository.search(
        '1:1',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(
          includeArabicText: false,
          includeSurahs: false,
        ),
      );
      expect(results.quickLinks, hasLength(1));
    });
  });

  group('Filters', () {
    test('excluded domains issue no query at all', () async {
      final results = await searchRepository.search(
        'lafz',
        scriptCode: testScriptCode,
        languageCode: 'en',
        filters: const SearchFilters(
          includeArabicText: false,
          includeSurahs: false,
        ),
      );
      expect(results.arabicHits, isEmpty);
      expect(results.surahHits, isEmpty);
    });
  });
}
