import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_connection.dart';
import 'data/repositories/drift_wbw_repository.dart';
import 'data/wbw_database.dart';
import 'domain/repositories/wbw_repository.dart';
import 'domain/wbw_pack_catalog.dart';

part 'wbw_providers.g.dart';

/// The WBW resource database connection, opened through the same
/// cross-platform helper the Quran database uses
/// (`lib/core/database/database_connection.dart`) — see
/// `docs/ARCHITECTURE.md` §4 for why this is its own database rather than a
/// table added to the canonical `QuranDatabase`.
@Riverpod(keepAlive: true)
WbwDatabase wbwDatabase(Ref ref) {
  final db = WbwDatabase(openConnection(databaseName: 'wbw_resources'));
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [WbwRepository]. UI and application code should depend on
/// this provider (or, in tests, override it), never construct
/// [DriftWbwRepository] directly.
@Riverpod(keepAlive: true)
WbwRepository wbwRepository(Ref ref) {
  return DriftWbwRepository(ref.watch(wbwDatabaseProvider));
}

/// The source of "packs available to install/update" — [NoWbwPackCatalog]
/// in production until Milestone 13 supplies a real manifest-backed one; see
/// [WbwPackCatalog]'s doc comment.
@Riverpod(keepAlive: true)
WbwPackCatalog wbwPackCatalog(Ref ref) => const NoWbwPackCatalog();
