import 'package:drift/drift.dart';

import 'tables/search_index_tables.dart';

part 'search_index_database.g.dart';

/// The search-index database: derived, normalized, fully rebuildable text
/// indexes for Arabic Quran text and installed translations.
///
/// Deliberately its own `@DriftDatabase` — see `docs/ARCHITECTURE.md` §4's
/// "Search index database | Derived, normalized, rebuildable text index |
/// Milestone 10" row. This database can be dropped and rebuilt from
/// canonical Quran text and installed translations with no data loss,
/// which is exactly the "index vs. canonical text" separation
/// `docs/CLEAN_ROOM_RULES.md` requires. Schema-only; all querying/mapping
/// logic lives in `DriftSearchRepository` (`lib/quran/data/repositories/`).
@DriftDatabase(
  tables: [ArabicSearchIndexEntries, TranslationSearchIndexEntries],
)
class SearchIndexDatabase extends _$SearchIndexDatabase {
  SearchIndexDatabase(super.connection);

  @override
  int get schemaVersion => 1;
}
