import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/navigation_models.dart';

import '../quran_test_fixtures.dart';

/// Counts every `SELECT` actually sent to SQLite, so tests can prove a
/// method issues a small, fixed number of queries regardless of how much
/// data it returns — this milestone's "do not query SQLite separately for
/// each visible word/verse" requirement, checked mechanically rather than
/// only by code review.
class CountingQueryInterceptor extends QueryInterceptor {
  int selectCount = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selectCount++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late CountingQueryInterceptor counter;
  late QuranDatabase db;
  late DriftQuranRepository repo;

  setUp(() async {
    counter = CountingQueryInterceptor();
    db = QuranDatabase(NativeDatabase.memory().interceptWith(counter));
    repo = DriftQuranRepository(db);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
  });

  tearDown(() => db.close());

  group('surahs', () {
    test('getAllSurahs returns all 114 in order', () async {
      final surahs = await repo.getAllSurahs();
      expect(surahs.length, 114);
      expect(surahs.first.surahNo, 1);
      expect(surahs.last.surahNo, 114);
    });

    test('getSurah returns the matching surah', () async {
      final surah = await repo.getSurah(1);
      expect(surah?.ayahCount, 7);
    });

    test('getSurah returns null for an unknown surah', () async {
      expect(await repo.getSurah(9999), isNull);
    });

    test('getSurahLocalization returns localized name/meaning', () async {
      final localization = await repo.getSurahLocalization(
        1,
        languageCode: 'en',
      );
      expect(localization?.name, 'Test Chapter One');
      expect(localization?.meaning, 'The First Test');
    });

    test('getAllSurahLocalizations returns every localized chapter for one language', () async {
      final localizations = await repo.getAllSurahLocalizations(
        languageCode: 'en',
      );
      // The synthetic fixture only localizes surah 1.
      expect(localizations, hasLength(1));
      expect(localizations.single.surahNo, 1);
      expect(localizations.single.name, 'Test Chapter One');
    });

    test(
      'getAllSurahLocalizations returns nothing for an uncovered language',
      () async {
        final localizations = await repo.getAllSurahLocalizations(
          languageCode: 'fr',
        );
        expect(localizations, isEmpty);
      },
    );
  });

  group('ayahs and words', () {
    test('getAyah resolves by chapter/verse', () async {
      final ayah = await repo.getAyah((chapterNo: 1, verseNo: 3));
      expect(ayah?.id, 1003);
    });

    test('getAyahByStableId resolves the same verse by id', () async {
      final ayah = await repo.getAyahByStableId(1003);
      expect(ayah?.chapterNo, 1);
      expect(ayah?.verseNo, 3);
    });

    test('getVerseRange returns verses in order', () async {
      final verses = await repo.getVerseRange((
        chapterNo: 1,
        fromVerseNo: 2,
        toVerseNo: 4,
      ));
      expect(verses.map((a) => a.verseNo), [2, 3, 4]);
    });

    test('getWordsForAyah returns words in index order', () async {
      final words = await repo.getWordsForAyah(
        1001,
        scriptCode: testScriptCode,
      );
      expect(words.map((w) => w.wordIndex), [0, 1]);
    });

    test('getVerseRangeWithWords batches ayahs and words together', () async {
      final result = await repo.getVerseRangeWithWords((
        chapterNo: 1,
        fromVerseNo: 1,
        toVerseNo: 7,
      ), scriptCode: testScriptCode);
      expect(result.length, 7);
      expect(result.every((r) => r.words.length == 2), isTrue);
      expect(result.first.ayah.verseNo, 1);
      expect(result.last.ayah.verseNo, 7);
    });

    test('getVerseRangeWithWords issues a fixed, small number of queries regardless of range size', () async {
      counter.selectCount = 0;
      await repo.getVerseRangeWithWords((
        chapterNo: 1,
        fromVerseNo: 1,
        toVerseNo: 7,
      ), scriptCode: testScriptCode);
      final sevenVerseCount = counter.selectCount;

      // A single-verse range should take the same number of queries as the
      // full 7-verse chapter — proving cost is independent of verse count,
      // not "one query per verse" (which this milestone explicitly forbids).
      counter.selectCount = 0;
      await repo.getVerseRangeWithWords((
        chapterNo: 1,
        fromVerseNo: 1,
        toVerseNo: 1,
      ), scriptCode: testScriptCode);
      final oneVerseCount = counter.selectCount;

      expect(sevenVerseCount, oneVerseCount);
      expect(sevenVerseCount, lessThanOrEqualTo(3));
    });
  });

  group('scripts', () {
    test('getAllScripts returns every installed script', () async {
      final scripts = await repo.getAllScripts();
      expect(scripts, hasLength(1));
      expect(scripts.single.code, testScriptCode);
    });
  });

  group('mushaf', () {
    test('getMushaf resolves by script code with no variant', () async {
      final mushaf = await repo.getMushaf(scriptCode: testScriptCode);
      expect(mushaf?.id, 1);
    });

    test('getPage returns lines in order', () async {
      final page = await repo.getPage(mushafId: 1, pageNumber: 1);
      expect(page, isNotNull);
      expect(page!.lines.map((l) => l.lineNumber), [1, 2, 3]);
      expect(page.lines.first.lineType, MushafLineType.surahHeader);
    });

    test('getPage returns null for a page with no lines', () async {
      expect(await repo.getPage(mushafId: 1, pageNumber: 2), isNull);
    });

    test('getLineTokens resolves tokens spanning multiple ayahs', () async {
      final lines = await repo.getPageLines(mushafId: 1, pageNumber: 1);
      final secondLine = lines.firstWhere((l) => l.lineNumber == 2);

      final tokens = await repo.getLineTokens(secondLine);

      // Line 2 spans ayah 1001..1004 (2 tokens each) => 8 tokens.
      expect(tokens.length, 8);
    });

    test('getPageForAyah finds the page containing a given ayah', () async {
      expect(await repo.getPageForAyah(mushafId: 1, ayahId: 1005), 1);
    });

    test('getPageTokens returns every token for every line on the page in one batch', () async {
      final tokens = await repo.getPageTokens(mushafId: 1, pageNumber: 1);

      // Line 1 (surahHeader) contributes no tokens; line 2 spans ayahs
      // 1001-1004 (2 tokens each = 8); line 3 spans ayahs 1005-1007 (2
      // tokens each = 6). 8 + 6 = 14.
      expect(tokens, hasLength(14));
      expect(tokens.map((t) => t.canonicalAyahId).toSet(), {
        1001,
        1002,
        1003,
        1004,
        1005,
        1006,
        1007,
      });
    });
  });

  group('navigation', () {
    test(
      'getJuzForVerse and getHizbForVerse read straight off the ayah',
      () async {
        expect(await repo.getJuzForVerse((chapterNo: 1, verseNo: 1)), 1);
        expect(await repo.getHizbForVerse((chapterNo: 1, verseNo: 1)), 1);
      },
    );

    test(
      'getJuzForPage/getHizbsForPage resolve via the page\'s lines',
      () async {
        expect(await repo.getJuzForPage(mushafId: 1, pageNumber: 1), 1);
        expect(await repo.getHizbsForPage(mushafId: 1, pageNumber: 1), [1]);
      },
    );

    test('getJuz aggregates every chapter segment for that Juz', () async {
      final juz = await repo.getJuz(1);
      expect(juz?.ranges, hasLength(1));
      expect(juz?.ranges.single.surahNo, 1);
    });

    test('getNavigationRanges returns every range of a given type', () async {
      final ranges = await repo.getNavigationRanges(NavigationUnitType.juz);
      expect(ranges, hasLength(1));
    });
  });

  group('validation', () {
    test('isValidChapterNo accepts 1..114 only', () {
      expect(repo.isValidChapterNo(1), isTrue);
      expect(repo.isValidChapterNo(114), isTrue);
      expect(repo.isValidChapterNo(0), isFalse);
      expect(repo.isValidChapterNo(115), isFalse);
    });

    test(
      'isValidVerse checks against the surah\'s actual ayah count',
      () async {
        expect(await repo.isValidVerse((chapterNo: 1, verseNo: 7)), isTrue);
        expect(await repo.isValidVerse((chapterNo: 1, verseNo: 8)), isFalse);
      },
    );

    test(
      'isValidVerseRange rejects a reversed or out-of-bounds range',
      () async {
        expect(
          await repo.isValidVerseRange((
            chapterNo: 1,
            fromVerseNo: 1,
            toVerseNo: 7,
          )),
          isTrue,
        );
        expect(
          await repo.isValidVerseRange((
            chapterNo: 1,
            fromVerseNo: 5,
            toVerseNo: 2,
          )),
          isFalse,
        );
        expect(
          await repo.isValidVerseRange((
            chapterNo: 1,
            fromVerseNo: 1,
            toVerseNo: 8,
          )),
          isFalse,
        );
      },
    );

    test(
      'isValidPage checks against the Mushaf\'s declared page count',
      () async {
        expect(await repo.isValidPage(mushafId: 1, pageNumber: 1), isTrue);
        expect(await repo.isValidPage(mushafId: 1, pageNumber: 2), isFalse);
      },
    );
  });

  test('getDatasetMetadata returns the imported metadata', () async {
    final metadata = await repo.getDatasetMetadata();
    expect(metadata?.datasetVersion, 'synthetic-test-fixture-1');
    expect(metadata?.contentHash, 'deadbeef');
  });
}
