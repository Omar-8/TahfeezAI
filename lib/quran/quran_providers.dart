import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_connection.dart';
import 'data/quran_database.dart';
import 'data/repositories/drift_quran_repository.dart';
import 'domain/repositories/quran_repository.dart';

part 'quran_providers.g.dart';

/// The canonical Quran database connection, opened through the same
/// cross-platform helper the core app database uses
/// (`lib/core/database/database_connection.dart`) — see
/// `docs/ARCHITECTURE.md` §4 for why this is its own database rather than a
/// table added to the core one.
@Riverpod(keepAlive: true)
QuranDatabase quranDatabase(Ref ref) {
  final db = QuranDatabase(openConnection(databaseName: 'quran'));
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [QuranRepository]. UI and application code should depend on
/// this provider (or, in tests, override it), never construct
/// [DriftQuranRepository] directly.
@Riverpod(keepAlive: true)
QuranRepository quranRepository(Ref ref) {
  return DriftQuranRepository(ref.watch(quranDatabaseProvider));
}
