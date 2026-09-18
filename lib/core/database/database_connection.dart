import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Opens the core [AppDatabase] using the correct storage strategy for the
/// current platform.
///
/// - Native (Android/iOS): a real SQLite file named `tahfeez_app.sqlite`
///   under the app's application-support directory.
/// - Web: SQLite compiled to WebAssembly, running in a Web Worker, choosing
///   the best available browser storage backend (OPFS, falling back to
///   IndexedDB) — see `web/sqlite3.wasm` and `web/drift_worker.js`, vendored
///   from the `drift` package's own GitHub release so the web build has no
///   runtime dependency on an external CDN, consistent with this project's
///   offline-first requirement.
///
/// Every future Drift database Tahfeez adds (the immutable Quran database in
/// Milestone 2, the mutable user-data database in Milestone 11, and so on)
/// should open its connection through this same helper shape so the
/// native/web split is solved exactly once.
QueryExecutor openConnection({required String databaseName}) {
  return driftDatabase(
    name: databaseName,
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

AppDatabase openAppDatabase() {
  return AppDatabase(openConnection(databaseName: 'tahfeez_app'));
}
