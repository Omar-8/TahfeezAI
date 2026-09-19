import 'package:drift/drift.dart';

import '../../domain/models/ayah_models.dart';
import '../../domain/models/dataset_metadata.dart';
import '../../domain/models/mushaf_models.dart';
import '../../domain/models/navigation_models.dart';
import '../../domain/models/surah_models.dart';
import '../../domain/models/quran_refs.dart';
import '../../domain/repositories/quran_repository.dart';
import '../quran_database.dart';
import '../quran_mappers.dart';

/// [QuranRepository] implementation backed by [QuranDatabase].
///
/// Every method here does a small, fixed number of queries regardless of
/// how much data it returns (see [getVerseRangeWithWords] and
/// [getWordsForLine] in particular) — batching across a whole verse range
/// or page in one or two queries, per this milestone's explicit "do not
/// query SQLite separately for each visible word/verse" requirement. This
/// class only ever reads; writing is [QuranDatasetImporter]'s job
/// (`lib/quran/data/import/`).
class DriftQuranRepository implements QuranRepository {
  DriftQuranRepository(this._db);

  final QuranDatabase _db;

  @override
  int get chapterCount => 114;

  // ---------------------------------------------------------------------
  // Surahs
  // ---------------------------------------------------------------------

  @override
  Future<List<Surah>> getAllSurahs() async {
    final rows = await (_db.select(
      _db.surahs,
    )..orderBy([(s) => OrderingTerm(expression: s.surahNo)])).get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<Surah?> getSurah(int surahNo) async {
    final row = await (_db.select(
      _db.surahs,
    )..where((s) => s.surahNo.equals(surahNo))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<SurahLocalization?> getSurahLocalization(
    int surahNo, {
    required String languageCode,
  }) async {
    final row =
        await (_db.select(_db.surahLocalizations)..where(
              (l) =>
                  l.surahNo.equals(surahNo) &
                  l.languageCode.equals(languageCode),
            ))
            .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<SurahLocalization>> getAllSurahLocalizations({
    required String languageCode,
  }) async {
    final rows =
        await (_db.select(_db.surahLocalizations)
              ..where((l) => l.languageCode.equals(languageCode))
              ..orderBy([(l) => OrderingTerm(expression: l.surahNo)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // ---------------------------------------------------------------------
  // Ayahs and words
  // ---------------------------------------------------------------------

  @override
  Future<Ayah?> getAyah(VerseRef verse) async {
    final row =
        await (_db.select(_db.ayahs)..where(
              (a) =>
                  a.chapterNo.equals(verse.chapterNo) &
                  a.verseNo.equals(verse.verseNo),
            ))
            .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<Ayah?> getAyahByStableId(int ayahId) async {
    final row = await (_db.select(
      _db.ayahs,
    )..where((a) => a.id.equals(ayahId))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<Ayah>> getVerseRange(VerseRangeRef range) async {
    final rows = await _selectVerseRangeRows(range);
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<AyahWord>> getWordsForAyah(
    int ayahId, {
    required String scriptCode,
  }) async {
    final script = await _getScriptRowByCode(scriptCode);
    if (script == null) return const [];

    final rows =
        await (_db.select(_db.ayahWords)
              ..where(
                (w) => w.ayahId.equals(ayahId) & w.scriptId.equals(script.id),
              )
              ..orderBy([(w) => OrderingTerm(expression: w.wordIndex)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<AyahWithWords>> getVerseRangeWithWords(
    VerseRangeRef range, {
    required String scriptCode,
  }) async {
    final script = await _getScriptRowByCode(scriptCode);
    if (script == null) return const [];

    // Query 1: every ayah in the range.
    final ayahRows = await _selectVerseRangeRows(range);
    if (ayahRows.isEmpty) return const [];

    // Query 2: every word for every one of those ayahs, in one round trip —
    // never one word query per verse.
    final ayahIds = ayahRows.map((a) => a.id).toList();
    final wordRows =
        await (_db.select(_db.ayahWords)
              ..where(
                (w) => w.ayahId.isIn(ayahIds) & w.scriptId.equals(script.id),
              )
              ..orderBy([(w) => OrderingTerm(expression: w.wordIndex)]))
            .get();

    final wordsByAyah = <int, List<AyahWord>>{};
    for (final row in wordRows) {
      wordsByAyah.putIfAbsent(row.ayahId, () => []).add(row.toDomain());
    }

    return ayahRows
        .map(
          (a) => AyahWithWords(
            ayah: a.toDomain(),
            words: wordsByAyah[a.id] ?? const [],
          ),
        )
        .toList();
  }

  Future<List<AyahRow>> _selectVerseRangeRows(VerseRangeRef range) {
    return (_db.select(_db.ayahs)
          ..where(
            (a) =>
                a.chapterNo.equals(range.chapterNo) &
                a.verseNo.isBetweenValues(range.fromVerseNo, range.toVerseNo),
          )
          ..orderBy([(a) => OrderingTerm(expression: a.verseNo)]))
        .get();
  }

  // ---------------------------------------------------------------------
  // Mushaf
  // ---------------------------------------------------------------------

  @override
  Future<Mushaf?> getMushaf({
    required String scriptCode,
    String? scriptVariantCode,
  }) async {
    final script = await _getScriptRowByCode(scriptCode);
    if (script == null) return null;

    int? variantId;
    if (scriptVariantCode != null) {
      final variant =
          await (_db.select(_db.quranScriptVariants)..where(
                (v) =>
                    v.scriptId.equals(script.id) &
                    v.code.equals(scriptVariantCode),
              ))
              .getSingleOrNull();
      if (variant == null) return null;
      variantId = variant.id;
    }

    final query = _db.select(_db.mushafs)
      ..where((m) => m.scriptId.equals(script.id));
    if (variantId != null) {
      // `!`, not flow promotion: `variantId` is captured by this closure, so
      // Dart cannot promote it from the enclosing `if (variantId != null)`.
      query.where((m) => m.scriptVariantId.equals(variantId!));
    } else {
      query.where((m) => m.scriptVariantId.isNull());
    }

    final row = await query.getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<Mushaf?> getMushafById(int mushafId) async {
    final row = await (_db.select(
      _db.mushafs,
    )..where((m) => m.id.equals(mushafId))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<MushafPage?> getPage({
    required int mushafId,
    required int pageNumber,
  }) async {
    final lines = await getPageLines(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    if (lines.isEmpty) return null;
    return MushafPage(mushafId: mushafId, pageNumber: pageNumber, lines: lines);
  }

  @override
  Future<List<MushafLine>> getPageLines({
    required int mushafId,
    required int pageNumber,
  }) async {
    final rows =
        await (_db.select(_db.mushafLines)
              ..where(
                (l) =>
                    l.mushafId.equals(mushafId) &
                    l.pageNumber.equals(pageNumber),
              )
              ..orderBy([(l) => OrderingTerm(expression: l.lineNumber)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<AyahWord>> getWordsForLine(
    MushafLine line, {
    required String scriptCode,
  }) async {
    final startAyahId = line.startAyahId;
    final endAyahId = line.endAyahId;
    final startWordIndex = line.startWordIndex;
    final endWordIndex = line.endWordIndex;
    if (startAyahId == null ||
        endAyahId == null ||
        startWordIndex == null ||
        endWordIndex == null) {
      return const [];
    }

    final script = await _getScriptRowByCode(scriptCode);
    if (script == null) return const [];

    // A line can span more than one ayah (a verse ending mid-line and the
    // next one starting on the same line); resolve the ayah ids spanned,
    // then trim the boundary ayahs down to the line's exact word range —
    // still just two queries no matter how many words/ayahs are involved.
    final ayahIds =
        (await (_db.select(_db.ayahs)
                  ..where((a) => a.id.isBetweenValues(startAyahId, endAyahId)))
                .get())
            .map((a) => a.id)
            .toSet();

    final wordRows =
        await (_db.select(_db.ayahWords)
              ..where(
                (w) => w.ayahId.isIn(ayahIds) & w.scriptId.equals(script.id),
              )
              ..orderBy([
                (w) => OrderingTerm(expression: w.ayahId),
                (w) => OrderingTerm(expression: w.wordIndex),
              ]))
            .get();

    return wordRows
        .where((w) {
          if (w.ayahId == startAyahId && w.wordIndex < startWordIndex) {
            return false;
          }
          if (w.ayahId == endAyahId && w.wordIndex > endWordIndex) {
            return false;
          }
          return true;
        })
        .map((r) => r.toDomain())
        .toList();
  }

  @override
  Future<List<AyahWord>> getWordsForPage({
    required int mushafId,
    required int pageNumber,
    required String scriptCode,
  }) async {
    final lines = await getPageLines(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );

    int? minAyahId;
    int? maxAyahId;
    for (final line in lines) {
      final start = line.startAyahId;
      final end = line.endAyahId;
      if (start == null || end == null) continue;
      minAyahId = minAyahId == null
          ? start
          : (start < minAyahId ? start : minAyahId);
      maxAyahId = maxAyahId == null ? end : (end > maxAyahId ? end : maxAyahId);
    }
    if (minAyahId == null || maxAyahId == null) return const [];
    final rangeStart = minAyahId;
    final rangeEnd = maxAyahId;

    final script = await _getScriptRowByCode(scriptCode);
    if (script == null) return const [];

    final ayahIds =
        (await (_db.select(
              _db.ayahs,
            )..where((a) => a.id.isBetweenValues(rangeStart, rangeEnd))).get())
            .map((a) => a.id)
            .toSet();

    final wordRows =
        await (_db.select(_db.ayahWords)
              ..where(
                (w) => w.ayahId.isIn(ayahIds) & w.scriptId.equals(script.id),
              )
              ..orderBy([
                (w) => OrderingTerm(expression: w.ayahId),
                (w) => OrderingTerm(expression: w.wordIndex),
              ]))
            .get();

    return wordRows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<int?> getPageForAyah({
    required int mushafId,
    required int ayahId,
  }) async {
    final row =
        await (_db.select(_db.mushafLines)
              ..where(
                (l) =>
                    l.mushafId.equals(mushafId) &
                    l.startAyahId.isSmallerOrEqualValue(ayahId) &
                    l.endAyahId.isBiggerOrEqualValue(ayahId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.pageNumber;
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  @override
  Future<int?> getJuzForVerse(VerseRef verse) async =>
      (await getAyah(verse))?.juzNo;

  @override
  Future<int?> getHizbForVerse(VerseRef verse) async =>
      (await getAyah(verse))?.hizbNo;

  @override
  Future<int?> getJuzForPage({
    required int mushafId,
    required int pageNumber,
  }) async {
    final lines = await getPageLines(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    for (final line in lines) {
      final ayahId = line.startAyahId;
      if (ayahId == null) continue;
      final ayah = await getAyahByStableId(ayahId);
      if (ayah != null) return ayah.juzNo;
    }
    return null;
  }

  @override
  Future<List<int>> getHizbsForPage({
    required int mushafId,
    required int pageNumber,
  }) async {
    final lines = await getPageLines(
      mushafId: mushafId,
      pageNumber: pageNumber,
    );
    final hizbs = <int>{};
    for (final line in lines) {
      final ayahId = line.startAyahId;
      if (ayahId == null) continue;
      final ayah = await getAyahByStableId(ayahId);
      if (ayah != null) hizbs.add(ayah.hizbNo);
    }
    final sorted = hizbs.toList()..sort();
    return sorted;
  }

  @override
  Future<Juz?> getJuz(int juzNo) async {
    final ranges = await _getNavigationRangesForUnit(
      NavigationUnitType.juz,
      juzNo,
    );
    if (ranges.isEmpty) return null;
    return Juz(juzNo: juzNo, ranges: ranges);
  }

  @override
  Future<Hizb?> getHizb(int hizbNo) async {
    final ranges = await _getNavigationRangesForUnit(
      NavigationUnitType.hizb,
      hizbNo,
    );
    if (ranges.isEmpty) return null;
    return Hizb(hizbNo: hizbNo, ranges: ranges);
  }

  Future<List<NavigationRange>> _getNavigationRangesForUnit(
    NavigationUnitType type,
    int unitNo,
  ) async {
    final rows =
        await (_db.select(_db.navigationRanges)
              ..where((r) => r.type.equalsValue(type) & r.unitNo.equals(unitNo))
              ..orderBy([(r) => OrderingTerm(expression: r.surahNo)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<List<NavigationRange>> getNavigationRanges(
    NavigationUnitType type,
  ) async {
    final rows =
        await (_db.select(_db.navigationRanges)
              ..where((r) => r.type.equalsValue(type))
              ..orderBy([
                (r) => OrderingTerm(expression: r.unitNo),
                (r) => OrderingTerm(expression: r.surahNo),
              ]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  @override
  bool isValidChapterNo(int chapterNo) =>
      chapterNo >= 1 && chapterNo <= chapterCount;

  @override
  Future<bool> isValidVerse(VerseRef verse) async {
    if (!isValidChapterNo(verse.chapterNo)) return false;
    final surah = await getSurah(verse.chapterNo);
    if (surah == null) return false;
    return verse.verseNo >= 1 && verse.verseNo <= surah.ayahCount;
  }

  @override
  Future<bool> isValidVerseRange(VerseRangeRef range) async {
    if (range.fromVerseNo > range.toVerseNo) return false;
    final surah = await getSurah(range.chapterNo);
    if (surah == null) return false;
    return range.fromVerseNo >= 1 && range.toVerseNo <= surah.ayahCount;
  }

  @override
  Future<bool> isValidPage({
    required int mushafId,
    required int pageNumber,
  }) async {
    final mushaf = await getMushafById(mushafId);
    if (mushaf == null) return false;
    return pageNumber >= 1 && pageNumber <= mushaf.pageCount;
  }

  // ---------------------------------------------------------------------
  // Dataset
  // ---------------------------------------------------------------------

  @override
  Future<DatasetMetadata?> getDatasetMetadata() async {
    final row = await (_db.select(
      _db.datasetMetadataEntries,
    )..where((m) => m.id.equals(0))).getSingleOrNull();
    return row?.toDomain();
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  Future<QuranScriptRow?> _getScriptRowByCode(String scriptCode) {
    return (_db.select(
      _db.quranScripts,
    )..where((s) => s.code.equals(scriptCode))).getSingleOrNull();
  }
}
