/// Pure conversions between Drift row types (`translation_database.g.dart`)
/// and the Flutter/Drift-independent domain models in
/// `lib/quran/domain/models/translation_models.dart`, mirroring
/// `quran_mappers.dart`'s convention.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/quran_refs.dart';
import '../domain/models/translation_models.dart';
import 'translation_database.dart';

extension TranslationBookRowMapper on TranslationBookRow {
  TranslationBook toDomain() => TranslationBook(
    slug: slug,
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

extension TranslationBookDomainMapper on TranslationBook {
  TranslationBooksCompanion toCompanion() => TranslationBooksCompanion.insert(
    slug: slug,
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

extension TranslationVerseRowMapper on TranslationVerseRow {
  TranslationVerseText toDomain() => TranslationVerseText(
    slug: slug,
    chapterNo: chapterNo,
    verseNo: verseNo,
    text: verseText,
    footnotes: _decodeFootnotes(footnotesJson),
    crossReferences: _decodeCrossReferences(crossReferencesJson),
  );
}

extension TranslationVerseTextDomainMapper on TranslationVerseText {
  TranslationVersesCompanion toCompanion() => TranslationVersesCompanion.insert(
    slug: slug,
    chapterNo: chapterNo,
    verseNo: verseNo,
    verseText: text,
    footnotesJson: Value(_encodeFootnotes(footnotes)),
    crossReferencesJson: Value(_encodeCrossReferences(crossReferences)),
  );
}

String? _encodeFootnotes(List<TranslationFootnote> footnotes) {
  if (footnotes.isEmpty) return null;
  return jsonEncode([
    for (final f in footnotes) {'marker': f.marker, 'text': f.text},
  ]);
}

List<TranslationFootnote> _decodeFootnotes(String? json) {
  if (json == null) return const [];
  final decoded = jsonDecode(json) as List<Object?>;
  return [
    for (final entry in decoded)
      TranslationFootnote(
        marker: (entry as Map<String, Object?>)['marker']! as int,
        text: entry['text']! as String,
      ),
  ];
}

String? _encodeCrossReferences(List<VerseRef> refs) {
  if (refs.isEmpty) return null;
  return jsonEncode([
    for (final r in refs) {'chapterNo': r.chapterNo, 'verseNo': r.verseNo},
  ]);
}

List<VerseRef> _decodeCrossReferences(String? json) {
  if (json == null) return const [];
  final decoded = jsonDecode(json) as List<Object?>;
  return [
    for (final entry in decoded)
      (
        chapterNo: (entry as Map<String, Object?>)['chapterNo']! as int,
        verseNo: entry['verseNo']! as int,
      ),
  ];
}
