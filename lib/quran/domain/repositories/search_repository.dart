/// One search hit, kind left generic on purpose — Milestone 10 (Search)
/// introduces the full result-kind hierarchy (Arabic text, translation
/// text, chapter/alias, quick-link, reference-content — see
/// `docs/reference/07_SEARCH_SPEC.md` §2) as a proper sealed union once the
/// underlying data sources it unifies actually exist.
class SearchHit {
  const SearchHit({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// Unified search across Arabic Quran text, translations, and chapter
/// names/aliases.
///
/// Per `docs/CLEAN_ROOM_RULES.md` and
/// `docs/reference/07_SEARCH_SPEC.md` §3, search must operate on a
/// *derived, normalized* index built from canonical text — never on a
/// destructively-normalized copy of the canonical text itself. That
/// indexing strategy is implemented by the Search milestone (10); this
/// interface only fixes the query/result shape UI can be built against
/// earlier.
abstract class SearchRepository {
  Future<List<SearchHit>> search(String query);
}
