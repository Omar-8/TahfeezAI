import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Small generic key/value table for core, app-level state that does not
/// belong to any single feature domain (e.g. "has onboarding completed",
/// schema/bookkeeping flags).
///
/// This is intentionally **not** where Quran content, translations, or user
/// bookmarks/history live — per the architecture recorded in
/// `docs/ARCHITECTURE.md` (and validated against the reference app's own
/// multi-database split in `docs/reference/06_DATA_MODEL_SPEC.md`), those
/// get their own dedicated Drift databases in the Quran Data Engine
/// (Milestone 2) and User Data (Milestone 11) milestones, keeping immutable
/// canonical data physically separate from mutable user data from day one.
class KeyValueEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The core application database.
///
/// Opened via [openAppDatabase] (`database_connection.dart`), which resolves
/// the correct [QueryExecutor] for the current platform (native SQLite via
/// Dart's native-assets/FFI toolchain, or SQLite-WASM + a Web Worker on the
/// browser) through `package:drift_flutter`. Nothing in this class is
/// platform-specific — that is the point of the abstraction.
@DriftDatabase(tables: [KeyValueEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.connection);

  @override
  int get schemaVersion => 1;
}
