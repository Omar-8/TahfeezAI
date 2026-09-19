import '../models/search_models.dart';

/// Unified, fully offline search across Arabic Quran text, installed
/// translations, and chapter names — Milestone 10.
///
/// Per `docs/CLEAN_ROOM_RULES.md` and `docs/reference/07_SEARCH_SPEC.md`
/// §3, search operates on a *derived, normalized* index
/// (`lib/quran/data/search_index_database.dart`) built from canonical
/// text — the canonical Quran/translation tables are never mutated by
/// indexing. Implemented against Drift by `DriftSearchRepository`
/// (`lib/quran/data/repositories/drift_search_repository.dart`).
abstract class SearchRepository {
  /// (Re)builds the Arabic-text search index for [scriptCode] from every
  /// currently installed ayah word in that script — an idempotent full
  /// replace, safe to call repeatedly.
  Future<void> indexQuranText({required String scriptCode});

  Future<bool> isQuranTextIndexed({required String scriptCode});

  /// (Re)builds one installed translation's search index from its
  /// currently installed verses.
  Future<void> indexTranslation(String slug);

  Future<bool> isTranslationIndexed(String slug);

  /// Drops [slug]'s search index — call when that translation itself is
  /// deleted, so no stale index ever outlives its source content.
  Future<void> removeTranslationIndex(String slug);

  /// Every domain's matches for [query], scoped by [filters]. Quick-link
  /// parsing is synchronous and always runs regardless of [filters]; the
  /// other domains are skipped entirely when [filters] excludes them (no
  /// query is even issued), and translation search is scoped to
  /// [SearchFilters.translationSlugs] when non-null.
  Future<SearchResults> search(
    String query, {
    required String scriptCode,
    required String languageCode,
    required SearchFilters filters,
    int limit = 50,
  });
}
