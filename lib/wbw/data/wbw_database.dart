import 'package:drift/drift.dart';

import 'tables/wbw_tables.dart';

part 'wbw_database.g.dart';

/// The word-by-word resource database: installed WBW language packs and
/// their per-word translation/transliteration text.
///
/// Deliberately its own `@DriftDatabase`, physically separate from the
/// immutable canonical `QuranDatabase` — see `docs/ARCHITECTURE.md` §4's
/// "Resource metadata (translations/tafsir/WBW/audio/atlas)" row. WBW packs
/// are downloadable/optional and independently installable/removable at any
/// time, unlike canonical Quran data, which is only ever replaced wholesale
/// by `QuranDatasetImporter`. Nothing in this class may express canonical
/// Quran text or mutable per-user state; if a future milestone is tempted to
/// add a "last read position" or canonical Arabic text column here, it
/// belongs in the user database or the Quran database instead.
///
/// This class only declares schema — all querying/mapping logic lives in
/// `DriftWbwRepository` (`lib/wbw/data/repositories/`), consistent with the
/// Quran database's "database class = schema only" convention.
@DriftDatabase(tables: [WbwPacks, WbwWords])
class WbwDatabase extends _$WbwDatabase {
  WbwDatabase(super.connection);

  @override
  int get schemaVersion => 1;
}
