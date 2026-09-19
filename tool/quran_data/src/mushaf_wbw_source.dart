// Reads QUL's KFGQPC V2 word-by-word export ("qpc-v2.db", from
// qpc-word-by-word.db.zip). Build-time-only tooling — QUL gates this
// download behind a required user login, so this cannot run as an in-app
// network fetch. The file is manually obtained and vendored at
// tool/quran_data/sources/qpc-v2-word-by-word.sqlite — see
// docs/QURAN_DATA_PROVENANCE.md.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tahfeez_ai/quran/domain/mushaf_token_source.dart';

class QulWordByWordInfo {
  const QulWordByWordInfo({required this.tokenCount, required this.sourceHash});

  final int tokenCount;
  final String sourceHash;
}

/// Reads QUL's `words` table (`id, location, surah, ayah, word, text`) into
/// [RawMushafToken]s — no classification performed here; that is
/// [MushafTokenClassifier]'s job (`lib/quran/domain/mushaf_token_classifier.dart`),
/// since deciding "real word vs. ayah marker" needs the canonical dataset
/// this reader has no access to.
class QulKfgqpcV2WordByWordSource implements MushafTokenSource {
  QulKfgqpcV2WordByWordSource(this.dbFile);

  final File dbFile;

  QulWordByWordInfo readInfo() {
    final bytes = dbFile.readAsBytesSync();
    final sourceHash = sha256.convert(bytes).toString();
    final db = sqlite3.open(dbFile.path);
    try {
      final count =
          db.select('SELECT COUNT(*) AS c FROM words').first['c'] as int;
      return QulWordByWordInfo(tokenCount: count, sourceHash: sourceHash);
    } finally {
      db.close();
    }
  }

  @override
  Future<List<RawMushafToken>> loadRawTokens() async {
    final db = sqlite3.open(dbFile.path);
    try {
      final rows = db.select(
        'SELECT id, surah, ayah, word, text FROM words ORDER BY id',
      );
      return rows
          .map(
            (row) => RawMushafToken(
              sourceTokenId: row['id'] as int,
              surahNumber: row['surah'] as int,
              ayahNumber: row['ayah'] as int,
              sourceWordPosition: row['word'] as int,
              displayText: row['text'] as String,
            ),
          )
          .toList();
    } finally {
      db.close();
    }
  }
}
