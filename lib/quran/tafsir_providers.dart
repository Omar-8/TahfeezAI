import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_connection.dart';
import 'data/repositories/drift_tafsir_repository.dart';
import 'data/tafsir_database.dart';
import 'domain/repositories/tafsir_repository.dart';
import 'domain/tafsir_catalog.dart';

part 'tafsir_providers.g.dart';

/// The tafsir resource database connection — mirrors
/// `translation_providers.dart`'s rationale.
@Riverpod(keepAlive: true)
TafsirDatabase tafsirDatabase(Ref ref) {
  final db = TafsirDatabase(openConnection(databaseName: 'tafsirs'));
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [TafsirRepository]. UI and application code should depend
/// on this provider (or, in tests, override it), never construct
/// [DriftTafsirRepository] directly.
@Riverpod(keepAlive: true)
TafsirRepository tafsirRepository(Ref ref) {
  return DriftTafsirRepository(ref.watch(tafsirDatabaseProvider));
}

/// The source of "tafsirs available to install/update" — see
/// [TafsirCatalog]'s doc comment.
@Riverpod(keepAlive: true)
TafsirCatalog tafsirCatalog(Ref ref) => const NoTafsirCatalog();
