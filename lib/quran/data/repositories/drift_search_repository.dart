import 'package:drift/drift.dart';

import '../../domain/models/search_models.dart';
import '../../domain/quick_link_parser.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../domain/search_normalizer.dart';
import '../search_index_database.dart';

/// [SearchRepository] implementation. Composes [QuranRepository] and
/// [TranslationRepository] (rather than reaching into `QuranDatabase`/
/// `TranslationDatabase` directly) to build the derived index in
/// [SearchIndexDatabase] — the same "compose across independent stores in
/// application/data code" pattern `docs/ARCHITECTURE.md` §4a documents,
/// since canonical Quran data, translation data, and the search index are
/// three physically separate databases with no foreign-key relationship.
class DriftSearchRepository implements SearchRepository {
  DriftSearchRepository(
    this._indexDb,
    this._quranRepository,
    this._translationRepository, {
    this._normalizer = const SearchNormalizer(),
    this._quickLinkParser = const QuickLinkParser(),
  });

  final SearchIndexDatabase _indexDb;
  final QuranRepository _quranRepository;
  final TranslationRepository _translationRepository;
  final SearchNormalizer _normalizer;
  final QuickLinkParser _quickLinkParser;

  @override
  Future<void> indexQuranText({required String scriptCode}) async {
    final words = await _quranRepository.getAllWordsForScript(scriptCode);

    // One canonical text blob per ayah, in reading order — matches every
    // other surface's "join a verse's words with a space" convention
    // (e.g. `VerseBlock._arabicText`).
    final textByAyah = <int, List<String>>{};
    for (final word in words) {
      textByAyah.putIfAbsent(word.ayahId, () => []).add(word.text);
    }

    await _indexDb.transaction(() async {
      await (_indexDb.delete(
        _indexDb.arabicSearchIndexEntries,
      )..where((e) => e.scriptCode.equals(scriptCode))).go();
      await _indexDb.batch((batch) {
        batch.insertAll(_indexDb.arabicSearchIndexEntries, [
          for (final entry in textByAyah.entries)
            ArabicSearchIndexEntriesCompanion.insert(
              ayahId: entry.key,
              scriptCode: scriptCode,
              chapterNo: entry.key ~/ 1000,
              verseNo: entry.key % 1000,
              normalizedText: _normalizer.normalizeArabic(
                entry.value.join(' '),
              ),
            ),
        ]);
      });
    });
  }

  @override
  Future<bool> isQuranTextIndexed({required String scriptCode}) async {
    final row =
        await (_indexDb.select(_indexDb.arabicSearchIndexEntries)
              ..where((e) => e.scriptCode.equals(scriptCode))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> indexTranslation(String slug) async {
    final verses = await _translationRepository.getAllVerseText(slug);

    await _indexDb.transaction(() async {
      await (_indexDb.delete(
        _indexDb.translationSearchIndexEntries,
      )..where((e) => e.slug.equals(slug))).go();
      await _indexDb.batch((batch) {
        batch.insertAll(_indexDb.translationSearchIndexEntries, [
          for (final verse in verses)
            TranslationSearchIndexEntriesCompanion.insert(
              slug: slug,
              chapterNo: verse.chapterNo,
              verseNo: verse.verseNo,
              normalizedText: _normalizer.normalizeLatin(verse.text),
            ),
        ]);
      });
    });
  }

  @override
  Future<bool> isTranslationIndexed(String slug) async {
    final row =
        await (_indexDb.select(_indexDb.translationSearchIndexEntries)
              ..where((e) => e.slug.equals(slug))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> removeTranslationIndex(String slug) async {
    await (_indexDb.delete(
      _indexDb.translationSearchIndexEntries,
    )..where((e) => e.slug.equals(slug))).go();
  }

  @override
  Future<SearchResults> search(
    String query, {
    required String scriptCode,
    required String languageCode,
    required SearchFilters filters,
    int limit = 50,
  }) async {
    final quickLinks = [
      for (final link in _quickLinkParser.parse(query))
        SearchHit.quickLink(label: link.label, location: link.location),
    ];

    final surahHits = filters.includeSurahs
        ? await _searchSurahs(query, languageCode: languageCode, limit: limit)
        : const <SearchHit>[];

    final arabicHits = filters.includeArabicText
        ? await _searchArabicText(query, scriptCode: scriptCode, limit: limit)
        : const <SearchHit>[];

    final translationHits = await _searchTranslations(
      query,
      slugs: filters.translationSlugs,
      limit: limit,
    );

    return SearchResults(
      quickLinks: quickLinks,
      surahHits: surahHits,
      arabicHits: arabicHits,
      translationHits: translationHits,
    );
  }

  Future<List<SearchHit>> _searchSurahs(
    String query, {
    required String languageCode,
    required int limit,
  }) async {
    final tokens = _normalizer.tokenize(query, arabicScript: false);
    if (tokens.isEmpty) return const [];

    final localizations = await _quranRepository.getAllSurahLocalizations(
      languageCode: languageCode,
    );
    final hits = <SearchHit>[];
    for (final localization in localizations) {
      final normalizedName = _normalizer.normalizeLatin(localization.name);
      final normalizedMeaning = localization.meaning == null
          ? ''
          : _normalizer.normalizeLatin(localization.meaning!);
      final matchesAllTokens = tokens.every(
        (token) =>
            normalizedName.contains(token) || normalizedMeaning.contains(token),
      );
      if (matchesAllTokens) {
        hits.add(
          SearchHit.surah(
            surahNo: localization.surahNo,
            matchedName: localization.name,
          ),
        );
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }

  Future<List<SearchHit>> _searchArabicText(
    String query, {
    required String scriptCode,
    required int limit,
  }) async {
    final tokens = _normalizer.tokenize(query, arabicScript: true);
    if (tokens.isEmpty) return const [];

    var select = _indexDb.select(_indexDb.arabicSearchIndexEntries)
      ..where((e) => e.scriptCode.equals(scriptCode));
    for (final token in tokens) {
      select = select..where((e) => e.normalizedText.like('%$token%'));
    }
    final rows = await (select..limit(limit)).get();

    final hits = <SearchHit>[];
    for (final row in rows) {
      final words = await _quranRepository.getWordsForAyah(
        row.ayahId,
        scriptCode: scriptCode,
      );
      hits.add(
        SearchHit.arabicText(
          ayahId: row.ayahId,
          chapterNo: row.chapterNo,
          verseNo: row.verseNo,
          matchedText: words.map((w) => w.text).join(' '),
        ),
      );
    }
    return hits;
  }

  Future<List<SearchHit>> _searchTranslations(
    String query, {
    required Set<String>? slugs,
    required int limit,
  }) async {
    final tokens = _normalizer.tokenize(query, arabicScript: false);
    if (tokens.isEmpty) return const [];
    if (slugs != null && slugs.isEmpty) return const [];

    var select = _indexDb.select(_indexDb.translationSearchIndexEntries);
    if (slugs != null) {
      select = select..where((e) => e.slug.isIn(slugs));
    }
    for (final token in tokens) {
      select = select..where((e) => e.normalizedText.like('%$token%'));
    }
    final rows = await (select..limit(limit)).get();

    final hits = <SearchHit>[];
    final bookNameCache = <String, String>{};
    for (final row in rows) {
      var displayName = bookNameCache[row.slug];
      if (displayName == null) {
        final book = await _translationRepository.getInstalledTranslation(
          row.slug,
        );
        displayName = book?.displayName ?? row.slug;
        bookNameCache[row.slug] = displayName;
      }
      final verse = await _translationRepository.getVerseText((
        chapterNo: row.chapterNo,
        verseNo: row.verseNo,
      ), slug: row.slug);
      hits.add(
        SearchHit.translationText(
          chapterNo: row.chapterNo,
          verseNo: row.verseNo,
          translationSlug: row.slug,
          translationDisplayName: displayName,
          matchedText: verse?.text ?? '',
        ),
      );
    }
    return hits;
  }
}
