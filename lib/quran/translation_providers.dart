import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_connection.dart';
import 'data/repositories/drift_translation_repository.dart';
import 'data/translation_database.dart';
import 'domain/repositories/translation_repository.dart';
import 'domain/translation_catalog.dart';

part 'translation_providers.g.dart';

/// The translation resource database connection, opened through the same
/// cross-platform helper the Quran database uses — see
/// `docs/ARCHITECTURE.md` §4 for why this is its own database.
@Riverpod(keepAlive: true)
TranslationDatabase translationDatabase(Ref ref) {
  final db = TranslationDatabase(openConnection(databaseName: 'translations'));
  ref.onDispose(db.close);
  return db;
}

/// The app-wide [TranslationRepository]. UI and application code should
/// depend on this provider (or, in tests, override it), never construct
/// [DriftTranslationRepository] directly.
@Riverpod(keepAlive: true)
TranslationRepository translationRepository(Ref ref) {
  return DriftTranslationRepository(ref.watch(translationDatabaseProvider));
}

/// The source of "translations available to install/update" — see
/// [TranslationCatalog]'s doc comment.
@Riverpod(keepAlive: true)
TranslationCatalog translationCatalog(Ref ref) => const NoTranslationCatalog();
