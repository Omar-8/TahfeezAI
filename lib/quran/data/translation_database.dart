import 'package:drift/drift.dart';

import 'tables/translation_tables.dart';

part 'translation_database.g.dart';

/// The translation resource database: installed translation editions and
/// their per-verse text/footnotes.
///
/// Deliberately its own `@DriftDatabase`, physically separate from the
/// immutable canonical `QuranDatabase` — see `docs/ARCHITECTURE.md` §4's
/// "Resource metadata (translations/tafsir/WBW/audio/atlas)" row, and
/// `lib/wbw/data/wbw_database.dart`'s identical rationale for word-by-word
/// packs. Schema-only; all querying/mapping lives in
/// `DriftTranslationRepository` (`lib/quran/data/repositories/`).
@DriftDatabase(tables: [TranslationBooks, TranslationVerses])
class TranslationDatabase extends _$TranslationDatabase {
  TranslationDatabase(super.connection);

  @override
  int get schemaVersion => 1;
}
