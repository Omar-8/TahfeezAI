/// Pure conversions between Drift row types (`quran_database.g.dart`) and
/// the Flutter/Drift-independent domain models in `lib/quran/domain/models/`.
///
/// Kept in one file, all one-directional (row -> domain; the reverse only
/// exists where the importer needs it), so `DriftQuranRepository` never has
/// to inline mapping logic — and so it is obvious at a glance that no
/// domain model ever leaks a Drift type.
library;

import '../domain/models/ayah_models.dart';
import '../domain/models/dataset_metadata.dart';
import '../domain/models/mushaf_models.dart';
import '../domain/models/navigation_models.dart';
import '../domain/models/script_models.dart';
import '../domain/models/surah_models.dart';
import 'quran_database.dart';

extension SurahRowMapper on SurahRow {
  Surah toDomain() => Surah(
    surahNo: surahNo,
    ayahCount: ayahCount,
    revelationOrder: revelationOrder,
    rukusCount: rukusCount,
    revelationType: revelationType,
  );
}

extension SurahLocalizationRowMapper on SurahLocalizationRow {
  SurahLocalization toDomain() => SurahLocalization(
    surahNo: surahNo,
    languageCode: languageCode,
    name: name,
    meaning: meaning,
  );
}

extension AyahRowMapper on AyahRow {
  Ayah toDomain() => Ayah(
    id: id,
    chapterNo: chapterNo,
    verseNo: verseNo,
    juzNo: juzNo,
    hizbNo: hizbNo,
    rubNo: rubNo,
    manzilNo: manzilNo,
    rukuNo: rukuNo,
    sajdah: sajdah,
  );
}

extension AyahWordRowMapper on AyahWordRow {
  AyahWord toDomain() => AyahWord(
    ayahId: ayahId,
    scriptId: scriptId,
    wordIndex: wordIndex,
    text: wordText,
  );
}

extension QuranScriptRowMapper on QuranScriptRow {
  QuranScript toDomain() =>
      QuranScript(id: id, code: code, displayName: displayName);
}

extension QuranScriptVariantRowMapper on QuranScriptVariantRow {
  QuranScriptVariant toDomain() => QuranScriptVariant(
    id: id,
    scriptId: scriptId,
    code: code,
    displayName: displayName,
  );
}

extension MushafRowMapper on MushafRow {
  Mushaf toDomain() => Mushaf(
    id: id,
    code: code,
    scriptId: scriptId,
    scriptVariantId: scriptVariantId,
    pageCount: pageCount,
    linesPerPage: linesPerPage,
  );
}

extension MushafLineRowMapper on MushafLineRow {
  MushafLine toDomain() => MushafLine(
    mushafId: mushafId,
    pageNumber: pageNumber,
    lineNumber: lineNumber,
    lineType: lineType,
    isCentered: isCentered,
    startAyahId: startAyahId,
    startWordIndex: startWordIndex,
    endAyahId: endAyahId,
    endWordIndex: endWordIndex,
    surahNo: surahNo,
  );
}

extension NavigationRangeRowMapper on NavigationRangeRow {
  NavigationRange toDomain() => NavigationRange(
    type: type,
    unitNo: unitNo,
    surahNo: surahNo,
    startAyahNo: startAyahNo,
    endAyahNo: endAyahNo,
  );
}

extension DatasetMetadataRowMapper on DatasetMetadataRow {
  DatasetMetadata toDomain() => DatasetMetadata(
    datasetVersion: datasetVersion,
    contentHash: contentHash,
    importedAt: importedAt,
  );
}
