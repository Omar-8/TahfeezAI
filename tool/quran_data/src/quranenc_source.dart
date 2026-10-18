// Parses QuranEnc's downloadable sqlite exports (translations and the
// Al-Muyassar tafsir, all sharing the same `translations(sura, aya,
// translation, footnotes)` table shape) into Tahfeez's TranslationBook/
// TafsirWork domain models.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tahfeez_ai/core/downloads/resource_integrity.dart';
import 'package:tahfeez_ai/quran/domain/models/tafsir_models.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';

/// One `[n] text` footnote entry parsed out of a QuranEnc footnotes blob.
/// Markers are scoped per-verse (QuranEnc restarts numbering per surah, but
/// each row's own footnotes/text are already scoped to one verse, so no
/// cross-verse marker collision is possible).
final _footnoteEntryPattern = RegExp(
  r'\[(\d+)\]\s*(.*?)(?=(?:\s*\[\d+\])|$)',
  dotAll: true,
);

List<TranslationFootnote> _parseFootnotes(String? blob) {
  if (blob == null || blob.trim().isEmpty) return const [];
  return _footnoteEntryPattern
      .allMatches(blob)
      .map(
        (m) => TranslationFootnote(
          marker: int.parse(m.group(1)!),
          text: m.group(2)!.trim(),
        ),
      )
      .where((f) => f.text.isNotEmpty)
      .toList();
}

class QuranEncTranslationResult {
  const QuranEncTranslationResult({
    required this.book,
    required this.verses,
    required this.sourceHash,
  });

  final TranslationBook book;
  final List<TranslationVerseText> verses;
  final String sourceHash;
}

/// Parses one QuranEnc translation sqlite export.
///
/// [slug] is Tahfeez's own stable identifier for this resource (e.g.
/// `'en-rowwad'`), independent of QuranEnc's own `key` naming.
QuranEncTranslationResult parseQuranEncTranslation({
  required File sqliteFile,
  required String slug,
  required String displayName,
  required String languageCode,
  required String author,
  required int version,
}) {
  final bytes = sqliteFile.readAsBytesSync();
  final sourceHash = sha256.convert(bytes).toString();

  final byPath = sqlite3.open(sqliteFile.path);
  try {
    final rows = byPath.select(
      'SELECT sura, aya, translation, footnotes FROM translations ORDER BY sura, aya',
    );
    final verses = <TranslationVerseText>[];
    for (final row in rows) {
      verses.add(
        TranslationVerseText(
          slug: slug,
          chapterNo: row['sura'] as int,
          verseNo: row['aya'] as int,
          text: (row['translation'] as String).trim(),
          footnotes: _parseFootnotes(row['footnotes'] as String?),
        ),
      );
    }

    final checksum = computeResourceChecksum([
      for (final v in verses) '${v.chapterNo}:${v.verseNo}:${v.text}',
    ]);

    final book = TranslationBook(
      slug: slug,
      displayName: displayName,
      languageCode: languageCode,
      author: author,
      version: version,
      source: 'QuranEnc.com',
      license:
          'QuranEnc Terms and Policies (see docs/QURAN_DATA_PROVENANCE.md)',
      checksum: checksum,
    );

    return QuranEncTranslationResult(
      book: book,
      verses: verses,
      sourceHash: sourceHash,
    );
  } finally {
    byPath.close();
  }
}

class QuranEncTafsirResult {
  const QuranEncTafsirResult({
    required this.work,
    required this.verses,
    required this.sourceHash,
  });

  final TafsirWork work;
  final List<TafsirVerseText> verses;
  final String sourceHash;
}

/// Parses QuranEnc's Al-Muyassar tafsir sqlite export (same table shape as a
/// translation export, but the `translation` column holds tafsir
/// commentary, and there is no separate footnotes model on [TafsirVerseText]).
///
/// [fromFootnotes]: a translation's own footnotes as its tafsir (Junagarhi's Urdu
/// carries Ahsan-ul-Bayan as footnotes); an ayah without any has no row.
QuranEncTafsirResult parseQuranEncTafsir({
  required File sqliteFile,
  required String tafsirId,
  required String displayName,
  required String languageCode,
  required String author,
  required int version,
  Set<String> leaveOut = const {},
  bool fromFootnotes = false,
  String source = 'QuranEnc.com',
}) {
  final bytes = sqliteFile.readAsBytesSync();
  final sourceHash = sha256.convert(bytes).toString();

  final db = sqlite3.open(sqliteFile.path);
  try {
    final rows = db.select(
      fromFootnotes
          ? 'SELECT sura, aya, footnotes AS translation FROM translations ORDER BY sura, aya'
          : 'SELECT sura, aya, translation FROM translations ORDER BY sura, aya',
    );
    final verses = <TafsirVerseText>[];
    for (final row in rows) {
      // An ayah the source leaves empty because the entry before covers
      // it too: no row at all, rather than an empty one. Only while empty:
      // if the source fills it in, it is kept (and the build's check fails).
      if ((fromFootnotes ||
              leaveOut.contains('${row['sura']}:${row['aya']}')) &&
          '${row['translation'] ?? ''}'.trim().isEmpty) {
        continue;
      }
      verses.add(
        TafsirVerseText(
          tafsirId: tafsirId,
          chapterNo: row['sura'] as int,
          verseNo: row['aya'] as int,
          text: (row['translation'] as String).trim(),
        ),
      );
    }

    final checksum = computeResourceChecksum([
      for (final v in verses) '${v.chapterNo}:${v.verseNo}:${v.text}',
    ]);

    final work = TafsirWork(
      id: tafsirId,
      displayName: displayName,
      languageCode: languageCode,
      author: author,
      version: version,
      source: source,
      license:
          'QuranEnc Terms and Policies (see docs/QURAN_DATA_PROVENANCE.md)',
      checksum: checksum,
    );

    return QuranEncTafsirResult(
      work: work,
      verses: verses,
      sourceHash: sourceHash,
    );
  } finally {
    db.close();
  }
}
