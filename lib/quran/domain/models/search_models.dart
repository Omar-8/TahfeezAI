import 'package:freezed_annotation/freezed_annotation.dart';

import 'quran_location.dart';

part 'search_models.freezed.dart';

/// One search result, kind-specific per
/// `docs/reference/07_SEARCH_SPEC.md` §2's distinct result kinds — replaces
/// Milestone 1's placeholder generic `SearchHit` now that the underlying
/// data sources (Arabic index, translation index, chapter localizations,
/// quick-link parsing) actually exist.
@freezed
sealed class SearchHit with _$SearchHit {
  /// A canonical Arabic-text match. [matchedText] is the ayah's full
  /// canonical text in the searched script — never a normalized/derived
  /// copy — assembled from [QuranRepository.getWordsForAyah] the same way
  /// every other reader surface renders Quran text.
  const factory SearchHit.arabicText({
    required int ayahId,
    required int chapterNo,
    required int verseNo,
    required String matchedText,
  }) = ArabicTextSearchHit;

  /// A translation-text match.
  const factory SearchHit.translationText({
    required int chapterNo,
    required int verseNo,
    required String translationSlug,
    required String translationDisplayName,
    required String matchedText,
  }) = TranslationTextSearchHit;

  /// A chapter name/meaning match.
  const factory SearchHit.surah({
    required int surahNo,
    required String matchedName,
  }) = SurahSearchHit;

  /// A structured navigation reference recognized directly from the query's
  /// shape (`QuickLinkParser`) — resolves instantly, without any index
  /// lookup.
  const factory SearchHit.quickLink({
    required String label,
    required QuranLocation location,
  }) = QuickLinkSearchHit;
}

/// Which search domains and installed resources a query should run
/// against. `translationSlugs == null` means "search every installed
/// translation"; an empty set means "search no translations" (the user
/// explicitly deselected all of them), matching
/// `docs/reference/07_SEARCH_SPEC.md` §5's `SearchFilters` semantics.
@freezed
abstract class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    @Default(true) bool includeArabicText,
    @Default(true) bool includeSurahs,
    Set<String>? translationSlugs,
  }) = _SearchFilters;
}

/// Every domain's results for one query, kept separate (not one flat list)
/// so the search screen can render one labeled section per domain and hide
/// empty sections independently — per this milestone's "Surah matches;
/// Quran matches; translation matches" distinct-section UI requirement.
@freezed
abstract class SearchResults with _$SearchResults {
  const factory SearchResults({
    @Default([]) List<SearchHit> quickLinks,
    @Default([]) List<SearchHit> surahHits,
    @Default([]) List<SearchHit> arabicHits,
    @Default([]) List<SearchHit> translationHits,
  }) = _SearchResults;

  const SearchResults._();

  bool get isEmpty =>
      quickLinks.isEmpty &&
      surahHits.isEmpty &&
      arabicHits.isEmpty &&
      translationHits.isEmpty;
}

/// One past search query, for `SearchHistoryController`.
@freezed
abstract class SearchHistoryEntry with _$SearchHistoryEntry {
  const factory SearchHistoryEntry({
    required String query,
    required DateTime searchedAt,
  }) = _SearchHistoryEntry;
}

/// Resolves any [SearchHit] to the [QuranLocation] it should navigate to —
/// this milestone's "every result should resolve to `QuranLocation`"
/// requirement, satisfied in one place so no result-rendering widget needs
/// its own ad hoc navigation logic.
QuranLocation searchHitLocation(SearchHit hit) {
  return switch (hit) {
    ArabicTextSearchHit(:final chapterNo, :final verseNo) => QuranLocation.ayah(
      chapterNo,
      verseNo,
    ),
    TranslationTextSearchHit(:final chapterNo, :final verseNo) =>
      QuranLocation.ayah(chapterNo, verseNo),
    SurahSearchHit(:final surahNo) => QuranLocation.surah(surahNo),
    QuickLinkSearchHit(:final location) => location,
  };
}
