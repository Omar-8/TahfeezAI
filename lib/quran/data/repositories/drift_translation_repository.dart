import 'package:drift/drift.dart';

import '../../../core/downloads/resource_integrity.dart';
import '../../domain/models/quran_refs.dart';
import '../../domain/models/translation_models.dart';
import '../../domain/repositories/translation_repository.dart';
import '../translation_database.dart';
import '../translation_mappers.dart';

/// [TranslationRepository] implementation backed by [TranslationDatabase].
///
/// [installTranslation]/[deleteTranslation] are the only methods that write
/// — mirrors `DriftWbwRepository`'s "read-only outside its one designated
/// write path" shape (`lib/wbw/data/repositories/drift_wbw_repository.dart`).
class DriftTranslationRepository implements TranslationRepository {
  DriftTranslationRepository(this._db);

  final TranslationDatabase _db;

  @override
  Future<List<TranslationBook>> getInstalledTranslations() async {
    final rows = await (_db.select(
      _db.translationBooks,
    )..orderBy([(b) => OrderingTerm(expression: b.displayName)])).get();
    return rows.map((r) => r.toDomain()).toList();
  }

  @override
  Future<TranslationBook?> getInstalledTranslation(String slug) async {
    final row = await (_db.select(
      _db.translationBooks,
    )..where((b) => b.slug.equals(slug))).getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<void> installTranslation(
    TranslationBook book,
    List<TranslationVerseText> verses,
  ) async {
    if (book.formatVersion != supportedTranslationFormatVersion) {
      throw ResourceFormatVersionException(
        resourceId: book.slug,
        supportedFormatVersion: supportedTranslationFormatVersion,
        actualFormatVersion: book.formatVersion,
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
    if (actualChecksum != book.checksum) {
      throw ResourceChecksumMismatchException(
        resourceId: book.slug,
        expectedChecksum: book.checksum,
        actualChecksum: actualChecksum,
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.translationVerses,
      )..where((v) => v.slug.equals(book.slug))).go();
      await _db
          .into(_db.translationBooks)
          .insertOnConflictUpdate(book.toCompanion());
      await _db.batch((batch) {
        batch.insertAll(
          _db.translationVerses,
          sorted.map((v) => v.toCompanion()),
        );
      });
    });
  }

  @override
  Future<void> deleteTranslation(String slug) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.translationVerses,
      )..where((v) => v.slug.equals(slug))).go();
      await (_db.delete(
        _db.translationBooks,
      )..where((b) => b.slug.equals(slug))).go();
    });
  }

  @override
  Future<TranslationVerseText?> getVerseText(
    VerseRef verse, {
    required String slug,
  }) async {
    final row =
        await (_db.select(_db.translationVerses)..where(
              (v) =>
                  v.slug.equals(slug) &
                  v.chapterNo.equals(verse.chapterNo) &
                  v.verseNo.equals(verse.verseNo),
            ))
            .getSingleOrNull();
    return row?.toDomain();
  }

  @override
  Future<List<TranslationVerseText>> getVerseRangeText(
    VerseRangeRef range, {
    required String slug,
  }) async {
    final rows =
        await (_db.select(_db.translationVerses)
              ..where(
                (v) =>
                    v.slug.equals(slug) &
                    v.chapterNo.equals(range.chapterNo) &
                    v.verseNo.isBetweenValues(
                      range.fromVerseNo,
                      range.toVerseNo,
                    ),
              )
              ..orderBy([(v) => OrderingTerm(expression: v.verseNo)]))
            .get();
    return rows.map((r) => r.toDomain()).toList();
  }
}
