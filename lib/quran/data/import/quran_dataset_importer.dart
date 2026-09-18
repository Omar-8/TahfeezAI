import 'package:drift/drift.dart';

import '../../domain/dataset_integrity.dart';
import '../../domain/quran_dataset_payload.dart';
import '../quran_database.dart';
import 'dataset_integrity_exception.dart';

/// Writes a validated [QuranDatasetPayload] into a [QuranDatabase].
///
/// This is the **only** place in Tahfeez that writes to the canonical Quran
/// database's content tables — `DriftQuranRepository` is read-only. Import
/// is intentionally the seam described in [QuranDatasetPayload]'s doc
/// comment: replacing the Quran dataset means constructing a different
/// payload and importing it, never touching [QuranRepository] or its
/// implementation.
///
/// Every import validates first ([DatasetIntegrityValidator]) and refuses
/// to write anything if the payload has errors, per this milestone's
/// Definition of Done ("integrity tests fail loudly when data is
/// incomplete or inconsistent") — this makes that guarantee hold not just
/// in tests, but for any real import path built on top of this class later.
class QuranDatasetImporter {
  // Not an initializing formal on purpose: that would make the public
  // parameter label `_validator` (matching the private field), which reads
  // oddly at call sites — `validator:` is a clearer public API.
  const QuranDatasetImporter({
    DatasetIntegrityValidator validator = const DatasetIntegrityValidator(),
  })
    // ignore: prefer_initializing_formals
    : _validator = validator;

  final DatasetIntegrityValidator _validator;

  /// Validates [payload] and, if valid, replaces the database's content
  /// with it inside one transaction (so a failure partway through never
  /// leaves the database half-imported). Throws [DatasetIntegrityException]
  /// without writing anything if [payload] fails validation.
  Future<DatasetIntegrityReport> import(
    QuranDatabase db,
    QuranDatasetPayload payload,
  ) async {
    final report = _validator.validate(payload);
    if (!report.isValid) {
      throw DatasetIntegrityException(report);
    }

    await db.transaction(() async {
      // Deleted in dependency order (children before parents) so foreign
      // keys never momentarily point at a deleted row mid-import.
      await db.delete(db.mushafLines).go();
      await db.delete(db.mushafs).go();
      await db.delete(db.quranScriptVariants).go();
      await db.delete(db.quranScripts).go();
      await db.delete(db.navigationRanges).go();
      await db.delete(db.ayahWords).go();
      await db.delete(db.ayahs).go();
      await db.delete(db.surahLocalizations).go();
      await db.delete(db.surahs).go();
      await db.delete(db.datasetMetadataEntries).go();

      await db.batch((batch) {
        batch.insertAll(
          db.surahs,
          payload.surahs.map(
            (s) => SurahsCompanion.insert(
              surahNo: Value(s.surahNo),
              ayahCount: s.ayahCount,
              revelationOrder: s.revelationOrder,
              rukusCount: s.rukusCount,
              revelationType: s.revelationType,
            ),
          ),
        );

        batch.insertAll(
          db.surahLocalizations,
          payload.surahLocalizations.map(
            (l) => SurahLocalizationsCompanion.insert(
              surahNo: l.surahNo,
              languageCode: l.languageCode,
              name: l.name,
              meaning: Value(l.meaning),
            ),
          ),
        );

        batch.insertAll(
          db.ayahs,
          payload.ayahs.map(
            (a) => AyahsCompanion.insert(
              id: Value(a.id),
              chapterNo: a.chapterNo,
              verseNo: a.verseNo,
              juzNo: a.juzNo,
              hizbNo: a.hizbNo,
              rubNo: a.rubNo,
              manzilNo: a.manzilNo,
              rukuNo: a.rukuNo,
              sajdah: Value(a.sajdah),
            ),
          ),
        );

        batch.insertAll(
          db.quranScripts,
          payload.scripts.map(
            (s) => QuranScriptsCompanion.insert(
              id: Value(s.id),
              code: s.code,
              displayName: s.displayName,
            ),
          ),
        );

        batch.insertAll(
          db.quranScriptVariants,
          payload.scriptVariants.map(
            (v) => QuranScriptVariantsCompanion.insert(
              id: Value(v.id),
              scriptId: v.scriptId,
              code: v.code,
              displayName: v.displayName,
            ),
          ),
        );

        batch.insertAll(
          db.ayahWords,
          payload.ayahWords.map(
            (w) => AyahWordsCompanion.insert(
              ayahId: w.ayahId,
              scriptId: w.scriptId,
              wordIndex: w.wordIndex,
              wordText: w.text,
            ),
          ),
        );

        batch.insertAll(
          db.mushafs,
          payload.mushafs.map(
            (m) => MushafsCompanion.insert(
              id: Value(m.id),
              code: m.code,
              scriptId: m.scriptId,
              scriptVariantId: Value(m.scriptVariantId),
              pageCount: m.pageCount,
              linesPerPage: m.linesPerPage,
            ),
          ),
        );

        batch.insertAll(
          db.mushafLines,
          payload.mushafLines.map(
            (l) => MushafLinesCompanion.insert(
              mushafId: l.mushafId,
              pageNumber: l.pageNumber,
              lineNumber: l.lineNumber,
              lineType: l.lineType,
              isCentered: l.isCentered,
              startAyahId: Value(l.startAyahId),
              startWordIndex: Value(l.startWordIndex),
              endAyahId: Value(l.endAyahId),
              endWordIndex: Value(l.endWordIndex),
              surahNo: Value(l.surahNo),
            ),
          ),
        );

        batch.insertAll(
          db.navigationRanges,
          payload.navigationRanges.map(
            (r) => NavigationRangesCompanion.insert(
              type: r.type,
              unitNo: r.unitNo,
              surahNo: r.surahNo,
              startAyahNo: r.startAyahNo,
              endAyahNo: r.endAyahNo,
            ),
          ),
        );

        batch.insert(
          db.datasetMetadataEntries,
          DatasetMetadataEntriesCompanion.insert(
            id: const Value(0),
            datasetVersion: payload.metadata.datasetVersion,
            contentHash: payload.metadata.contentHash,
            importedAt: payload.metadata.importedAt,
          ),
        );
      });
    });

    return report;
  }
}
