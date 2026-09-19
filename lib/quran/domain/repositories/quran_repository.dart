import '../models/ayah_models.dart';
import '../models/dataset_metadata.dart';
import '../models/mushaf_models.dart';
import '../models/navigation_models.dart';
import '../models/script_models.dart';
import '../models/surah_models.dart';
import '../models/quran_refs.dart' show VerseRangeRef, VerseRef;

/// Read access to the **immutable** canonical Quran dataset: chapters,
/// verses, words, scripts, Mushaf pagination, and navigation units.
///
/// Implemented against Drift by `DriftQuranRepository`
/// (`lib/quran/data/repositories/drift_quran_repository.dart`). Per
/// `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules, this repository
/// exposes **no method that can mutate canonical text** — importing/
/// replacing the dataset is a separate concern
/// (`lib/quran/data/import/quran_dataset_importer.dart`), never part of the
/// read-only surface UI code depends on.
///
/// Every read method here is backed by local data only; per
/// `docs/PROJECT_BRIEF.md`'s offline-first requirement, none of them may
/// require network access to answer once the dataset is installed.
abstract class QuranRepository {
  // ---------------------------------------------------------------------
  // Surahs
  // ---------------------------------------------------------------------

  /// The Quran always has exactly 114 chapters — a constant, not a query.
  int get chapterCount => 114;

  Future<List<Surah>> getAllSurahs();

  Future<Surah?> getSurah(int surahNo);

  Future<SurahLocalization?> getSurahLocalization(
    int surahNo, {
    required String languageCode,
  });

  /// Every chapter's localization for one language, in a single query —
  /// the batch counterpart to [getSurahLocalization], for callers (e.g. the
  /// Quran index) that need every chapter's localized name at once and
  /// must not do it as 114 individual lookups.
  Future<List<SurahLocalization>> getAllSurahLocalizations({
    required String languageCode,
  });

  // ---------------------------------------------------------------------
  // Scripts
  // ---------------------------------------------------------------------

  /// Every installed [QuranScript], for a script picker (Milestone 8) to
  /// list — the running app may have zero, one, or several installed at
  /// once (a script "family" ships with, or is imported alongside, the
  /// Quran dataset itself; there is no separate script-only import path).
  Future<List<QuranScript>> getAllScripts();

  // ---------------------------------------------------------------------
  // Ayahs and words
  // ---------------------------------------------------------------------

  Future<Ayah?> getAyah(VerseRef verse);

  /// Looks up a verse by its stable id (`chapterNo * 1000 + verseNo`) rather
  /// than by chapter/verse — useful when a caller already holds an id from
  /// another record (e.g. a [MushafLine]'s `startAyahId`).
  Future<Ayah?> getAyahByStableId(int ayahId);

  Future<List<Ayah>> getVerseRange(VerseRangeRef range);

  Future<List<AyahWord>> getWordsForAyah(
    int ayahId, {
    required String scriptCode,
  });

  /// Loads every verse in [range] together with its words, in a small,
  /// fixed number of queries regardless of how many verses [range] spans —
  /// this is the method reader UI should use instead of calling
  /// [getVerseRange] and [getWordsForAyah] once per verse. See
  /// `docs/reference/06_DATA_MODEL_SPEC.md` §8 for why this batching
  /// matters, and this milestone's own "do not query SQLite separately for
  /// each visible word/verse" requirement.
  Future<List<AyahWithWords>> getVerseRangeWithWords(
    VerseRangeRef range, {
    required String scriptCode,
  });

  // ---------------------------------------------------------------------
  // Mushaf
  // ---------------------------------------------------------------------

  Future<Mushaf?> getMushaf({
    required String scriptCode,
    String? scriptVariantCode,
  });

  Future<Mushaf?> getMushafById(int mushafId);

  Future<MushafPage?> getPage({required int mushafId, required int pageNumber});

  Future<List<MushafLine>> getPageLines({
    required int mushafId,
    required int pageNumber,
  });

  Future<List<AyahWord>> getWordsForLine(
    MushafLine line, {
    required String scriptCode,
  });

  /// Every word for every line of one Mushaf page, in a small, fixed
  /// number of queries regardless of the page's line count — the batch
  /// counterpart to [getWordsForLine], for the Mushaf renderer (Milestone
  /// 7), which needs a whole page's words at once and must not query once
  /// per line (~15 queries for a standard 15-line page). Returned in
  /// (ayahId, wordIndex) order, unfiltered by any single line's word-index
  /// bounds — callers slice per line themselves using each
  /// [MushafLine.startWordIndex]/[MushafLine.endWordIndex], the same
  /// trimming [getWordsForLine] does internally for one line.
  Future<List<AyahWord>> getWordsForPage({
    required int mushafId,
    required int pageNumber,
    required String scriptCode,
  });

  /// The page number containing [ayahId] in [mushafId]'s pagination, or
  /// `null` if the ayah/mushaf combination is unknown.
  Future<int?> getPageForAyah({required int mushafId, required int ayahId});

  // ---------------------------------------------------------------------
  // Navigation (Juz/Hizb/Rub/Manzil)
  // ---------------------------------------------------------------------

  Future<int?> getJuzForVerse(VerseRef verse);

  Future<int?> getHizbForVerse(VerseRef verse);

  Future<int?> getJuzForPage({required int mushafId, required int pageNumber});

  /// A page can straddle more than one Hizb boundary, hence a list.
  Future<List<int>> getHizbsForPage({
    required int mushafId,
    required int pageNumber,
  });

  Future<Juz?> getJuz(int juzNo);

  Future<Hizb?> getHizb(int hizbNo);

  Future<List<NavigationRange>> getNavigationRanges(NavigationUnitType type);

  // ---------------------------------------------------------------------
  // Location validation
  // ---------------------------------------------------------------------

  bool isValidChapterNo(int chapterNo) =>
      chapterNo >= 1 && chapterNo <= chapterCount;

  Future<bool> isValidVerse(VerseRef verse);

  Future<bool> isValidVerseRange(VerseRangeRef range);

  Future<bool> isValidPage({required int mushafId, required int pageNumber});

  // ---------------------------------------------------------------------
  // Dataset
  // ---------------------------------------------------------------------

  Future<DatasetMetadata?> getDatasetMetadata();
}
