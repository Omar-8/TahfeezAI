import 'package:drift/drift.dart';

// The enum imports below look unused: nothing in this file references
// RevelationType/SajdahType/MushafLineType/NavigationUnitType by name.
// They are required anyway. `quran_database.g.dart` is a `part of` this
// file, so it shares this file's imports rather than the table files'
// (Dart imports are not transitive) — and the generated code references
// these enums directly as `textEnum<T>()` type arguments. Removing these
// imports compiles the table files fine but breaks the generated part
// file with "isn't a type" errors.
// ignore: unused_import
import '../domain/models/ayah_models.dart';
// ignore: unused_import
import '../domain/models/mushaf_models.dart';
// ignore: unused_import
import '../domain/models/mushaf_token_models.dart';
// ignore: unused_import
import '../domain/models/navigation_models.dart';
// ignore: unused_import
import '../domain/models/surah_models.dart';
import 'tables/ayah_tables.dart';
import 'tables/dataset_metadata_table.dart';
import 'tables/mushaf_tables.dart';
import 'tables/navigation_tables.dart';
import 'tables/script_tables.dart';
import 'tables/surah_tables.dart';

part 'quran_database.g.dart';

/// The canonical, **immutable** Quran database: chapters, verses, words,
/// scripts, Mushaf pagination, and navigation ranges.
///
/// Deliberately its own `@DriftDatabase`, physically separate from the core
/// app database (Milestone 1) and from the future user-data database
/// (Milestone 11) — see `docs/ARCHITECTURE.md` §4. Nothing in this class
/// (or the tables it registers) may express mutable user state; if a
/// future milestone is tempted to add a "last read position" or "favorite"
/// column here, it belongs in the user database instead.
///
/// This class only declares schema — all querying/mapping logic lives in
/// `DriftQuranRepository` (`lib/quran/data/repositories/`), consistent with
/// Milestone 1's "database class = schema only" convention
/// (`lib/core/database/app_database.dart`).
@DriftDatabase(
  tables: [
    Surahs,
    SurahLocalizations,
    Ayahs,
    AyahWords,
    QuranScripts,
    QuranScriptVariants,
    Mushafs,
    MushafLines,
    MushafTokens,
    NavigationRanges,
    DatasetMetadataEntries,
  ],
)
class QuranDatabase extends _$QuranDatabase {
  QuranDatabase(super.connection);

  // Bump whenever a table or column is added/changed/removed above. Drift
  // only runs [migration] when this actually changes — leaving it stale
  // (as it was through the Milestone 9B/9C Mushaf-token work, which added
  // the MushafTokens table and new Mushafs/MushafLines columns without
  // bumping it) leaves an existing on-device database file exactly as it
  // was, so a device that already ran an older build never gets the new
  // schema and every import against it throws.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (Migrator m, int from, int to) async {
      // Every row in this database is derived from bundled assets and
      // re-seeded by BundledDatasetSeeder whenever its version marker
      // doesn't match — there is no user-generated data here to preserve
      // (that lives in the separate user database, see the class doc
      // comment above). So the correct migration for any schema change is
      // simply to drop and recreate every table and let the seeder
      // reimport from scratch, rather than hand-writing per-version
      // ALTER TABLE steps for content that gets fully overwritten anyway.
      for (final table in allTables) {
        await m.deleteTable(table.actualTableName);
      }
      await m.createAll();
    },
  );
}
