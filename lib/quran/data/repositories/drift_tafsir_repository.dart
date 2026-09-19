import 'package:drift/drift.dart';

import '../../../core/downloads/resource_integrity.dart';
import '../../domain/models/quran_refs.dart';
import '../../domain/models/tafsir_models.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../tafsir_database.dart';
import '../tafsir_mappers.dart';

/// [TafsirRepository] implementation backed by [TafsirDatabase]. Mirrors
/// [DriftTranslationRepository]'s checksum/format-version verification and
/// transactional-replace shape exactly.
class DriftTafsirRepository implements TafsirRepository {
  DriftTafsirRepository(this._db);

  final TafsirDatabase _db;

  @override
  Future<List<TafsirWork>> getInstalledTafsirs() async {
    final rows = await (_db.select(
      _db.tafsirWorks,
    )..orderBy([(w) => OrderingTerm(expression: w.displayName)])).get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<TafsirWork?> getInstalledTafsir(String tafsirId) async {
    final row = await (_db.select(
      _db.tafsirWorks,
    )..where((w) => w.id.equals(tafsirId))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> installTafsir(
    TafsirWork work,
    List<TafsirVerseText> verses,
  ) async {
    if (work.formatVersion != supportedTafsirFormatVersion) {
      throw ResourceFormatVersionException(
        resourceId: work.id,
        supportedFormatVersion: supportedTafsirFormatVersion,
        actualFormatVersion: work.formatVersion,
      );
    }
    final sorted = [...verses]
      ..sort((a, b) {
        final byChapter = a.chapterNo.compareTo(b.chapterNo);
        return byChapter != 0 ? byChapter : a.verseNo.compareTo(b.verseNo);
      });
    final actualChecksum = computeResourceChecksum([
      for (final v in sorted) '${v.chapterNo}:${v.verseNo}:${v.text}',
    ]);
    if (actualChecksum != work.checksum) {
      throw ResourceChecksumMismatchException(
        resourceId: work.id,
        expectedChecksum: work.checksum,
        actualChecksum: actualChecksum,
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.tafsirVerses,
      )..where((v) => v.tafsirId.equals(work.id))).go();
      await _db
          .into(_db.tafsirWorks)
          .insertOnConflictUpdate(work.toCompanion());
      await _db.batch((batch) {
        batch.insertAll(_db.tafsirVerses, sorted.map((v) => v.toCompanion()));
      });
    });
  }

  @override
  Future<void> deleteTafsir(String tafsirId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.tafsirVerses,
      )..where((v) => v.tafsirId.equals(tafsirId))).go();
      await (_db.delete(
        _db.tafsirWorks,
      )..where((w) => w.id.equals(tafsirId))).go();
    });
  }

  @override
  Future<TafsirVerseText?> getVerseText(
    VerseRef verse, {
    required String tafsirId,
  }) async {
    final row =
        await (_db.select(_db.tafsirVerses)..where(
              (v) =>
                  v.tafsirId.equals(tafsirId) &
                  v.chapterNo.equals(verse.chapterNo) &
                  v.verseNo.equals(verse.verseNo),
            ))
            .getSingleOrNull();
    return row?.toDomain();
  }
}
