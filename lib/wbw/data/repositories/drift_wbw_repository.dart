import 'package:drift/drift.dart';

import '../../domain/models/wbw_models.dart';
import '../../domain/repositories/wbw_repository.dart';
import '../wbw_database.dart';
import '../wbw_mappers.dart';

/// [WbwRepository] implementation backed by [WbwDatabase].
///
/// [installPack]/[deletePack] are the only methods that write — every other
/// method only reads, mirroring `DriftQuranRepository`'s "read-only outside
/// its one designated write path" shape (there, `QuranDatasetImporter`; here,
/// installing/deleting a whole pack atomically rather than word-by-word).
class DriftWbwRepository implements WbwRepository {
  DriftWbwRepository(this._db);

  final WbwDatabase _db;

  @override
  Future<List<WbwLanguagePack>> getInstalledPacks() async {
    final rows = await (_db.select(
      _db.wbwPacks,
    )..orderBy([(p) => OrderingTerm(expression: p.displayName)])).get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<WbwLanguagePack?> getInstalledPack(String packId) async {
    final row = await (_db.select(
      _db.wbwPacks,
    )..where((p) => p.id.equals(packId))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> installPack(
    WbwLanguagePack pack,
    List<WbwWordEntry> words,
  ) async {
    await _db.transaction(() async {
      // A re-install/update must not leave stale words from a previous
      // version's now-removed entries behind — delete before re-inserting,
      // the same "replace, don't merge" shape `QuranDatasetImporter` uses.
      await (_db.delete(
        _db.wbwWords,
      )..where((w) => w.packId.equals(pack.id))).go();
      await _db.into(_db.wbwPacks).insertOnConflictUpdate(pack.toCompanion());
      await _db.batch((batch) {
        batch.insertAll(_db.wbwWords, words.map((w) => w.toCompanion()));
      });
    });
  }

  @override
  Future<void> deletePack(String packId) async {
    await _db.transaction(() async {
      // Deleted explicitly rather than relying solely on the schema's
      // `onDelete: KeyAction.cascade` — SQLite only enforces cascades when
      // foreign-key enforcement is turned on for the connection, which this
      // database does not otherwise depend on.
      await (_db.delete(
        _db.wbwWords,
      )..where((w) => w.packId.equals(packId))).go();
      await (_db.delete(_db.wbwPacks)..where((p) => p.id.equals(packId))).go();
    });
  }

  @override
  Future<WbwWordEntry?> getWord({
    required String packId,
    required int ayahId,
    required int wordIndex,
  }) async {
    final row =
        await (_db.select(_db.wbwWords)..where(
              (w) =>
                  w.packId.equals(packId) &
                  w.ayahId.equals(ayahId) &
                  w.wordIndex.equals(wordIndex),
            ))
            .getSingleOrNull();
    return row?.toDomain();
  }
}
