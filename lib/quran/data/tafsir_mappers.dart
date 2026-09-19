/// Pure conversions between Drift row types (`tafsir_database.g.dart`) and
/// the Flutter/Drift-independent domain models in
/// `lib/quran/domain/models/tafsir_models.dart`.
library;

import '../domain/models/tafsir_models.dart';
import 'tafsir_database.dart';

extension TafsirWorkRowMapper on TafsirWorkRow {
  TafsirWork toDomain() => TafsirWork(
    id: id,
    displayName: displayName,
    languageCode: languageCode,
    author: author,
    version: version,
    source: source,
    license: license,
    checksum: checksum,
    formatVersion: formatVersion,
  );
}

extension TafsirWorkDomainMapper on TafsirWork {
  TafsirWorksCompanion toCompanion() => TafsirWorksCompanion.insert(
    id: id,
    displayName: displayName,
    languageCode: languageCode,
    author: author,
    version: version,
    source: source,
    license: license,
    checksum: checksum,
    formatVersion: formatVersion,
  );
}

extension TafsirVerseRowMapper on TafsirVerseRow {
  TafsirVerseText toDomain() => TafsirVerseText(
    tafsirId: tafsirId,
    chapterNo: chapterNo,
    verseNo: verseNo,
    text: verseText,
  );
}

extension TafsirVerseTextDomainMapper on TafsirVerseText {
  TafsirVersesCompanion toCompanion() => TafsirVersesCompanion.insert(
    tafsirId: tafsirId,
    chapterNo: chapterNo,
    verseNo: verseNo,
    verseText: text,
  );
}
