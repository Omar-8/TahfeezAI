import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_connection.dart';
import 'data/repositories/drift_search_repository.dart';
import 'data/search_index_database.dart';
import 'domain/repositories/search_repository.dart';
import 'quran_providers.dart';
import 'translation_providers.dart';

part 'search_providers.g.dart';

/// The search-index database connection — mirrors
/// `translation_providers.dart`'s rationale.
@Riverpod(keepAlive: true)
SearchIndexDatabase searchIndexDatabase(Ref ref) {
  final db = SearchIndexDatabase(openConnection(databaseName: 'search_index'));
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [SearchRepository]. UI and application code should depend
/// on this provider (or, in tests, override it), never construct
/// [DriftSearchRepository] directly.
@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) {
  return DriftSearchRepository(
    ref.watch(searchIndexDatabaseProvider),
    ref.watch(quranRepositoryProvider),
    ref.watch(translationRepositoryProvider),
  );
}
