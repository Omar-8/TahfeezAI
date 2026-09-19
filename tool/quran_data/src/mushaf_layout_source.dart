// Reads QUL's KFGQPC V2 ("qpc-v2-15-lines.db") Mushaf layout export.
//
// This is build-time-only tooling: QUL gates this download behind a
// required user login and exposes no public API (verified by hand), so
// Tahfeez cannot fetch it automatically. The file is manually obtained and
// vendored at tool/quran_data/sources/qpc-v2-15-lines.db.zip — see
// docs/QURAN_DATA_PROVENANCE.md.
//
// This reader only produces a RawMushafLayout (page/line/type/centering/
// surah-header number + QUL's own word-id range per line) — it never
// resolves word ids to (ayah, wordIndex), because that requires a companion
// word/script dataset Tahfeez has not yet received. No synthetic data is
// substituted for that missing piece anywhere in this file.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tahfeez_ai/quran/domain/mushaf_data_source.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

class QulLayoutInfo {
  const QulLayoutInfo({
    required this.name,
    required this.pageCount,
    required this.linesPerPage,
    required this.fontName,
    required this.totalLines,
    required this.sourceHash,
  });

  final String name;
  final int pageCount;
  final int linesPerPage;
  final String fontName;
  final int totalLines;
  final String sourceHash;
}

class QulKfgqpcV2MushafDataSource implements MushafDataSource {
  QulKfgqpcV2MushafDataSource(this.dbFile);

  final File dbFile;

  QulLayoutInfo readInfo() {
    final bytes = dbFile.readAsBytesSync();
    final sourceHash = sha256.convert(bytes).toString();
    final db = sqlite3.open(dbFile.path);
    try {
      final row = db.select('SELECT * FROM info').first;
      final totalLines =
          db.select('SELECT COUNT(*) AS c FROM pages').first['c'] as int;
      return QulLayoutInfo(
        name: row['name'] as String,
        pageCount: row['number_of_pages'] as int,
        linesPerPage: row['lines_per_page'] as int,
        fontName: row['font_name'] as String,
        totalLines: totalLines,
        sourceHash: sourceHash,
      );
    } finally {
      db.close();
    }
  }

  @override
  Future<RawMushafLayout> loadRawLayout() async {
    final info = readInfo();
    final db = sqlite3.open(dbFile.path);
    try {
      final rows = db.select(
        'SELECT page_number, line_number, line_type, is_centered, '
        'first_word_id, last_word_id, surah_number FROM pages '
        'ORDER BY page_number, line_number',
      );

      final lines = rows.map((row) {
        final lineType = switch (row['line_type'] as String) {
          'surah_name' => MushafLineType.surahHeader,
          'basmallah' => MushafLineType.bismillah,
          'ayah' => MushafLineType.quranText,
          final other => throw StateError('Unknown QUL line_type "$other"'),
        };

        int? parseWordId(dynamic v) {
          if (v == null) return null;
          if (v is int) return v;
          if (v is String) return v.trim().isEmpty ? null : int.parse(v);
          return null;
        }

        int? parseSurahNo(dynamic v) {
          if (v == null) return null;
          if (v is int) return v == 0 ? null : v;
          if (v is String) return v.trim().isEmpty ? null : int.parse(v);
          return null;
        }

        return RawMushafLine(
          pageNumber: row['page_number'] as int,
          lineNumber: row['line_number'] as int,
          lineType: lineType,
          isCentered: (row['is_centered'] as int) != 0,
          surahNo: parseSurahNo(row['surah_number']),
          firstWordId: parseWordId(row['first_word_id']),
          lastWordId: parseWordId(row['last_word_id']),
        );
      }).toList();

      return RawMushafLayout(
        editionCode: 'qcf_v2_1421h',
        pageCount: info.pageCount,
        linesPerPage: info.linesPerPage,
        lines: lines,
      );
    } finally {
      db.close();
    }
  }
}

/// Structural validation of the real QUL layout file — checks the shape and
/// internal consistency of the *real* data (page count, line-type
/// enumeration, contiguous line numbering per page), independent of the
/// still-missing word-id resolution. Never invents content; only reports.
class QulLayoutValidationReport {
  const QulLayoutValidationReport(this.issues);

  final List<String> issues;

  bool get isValid => issues.isEmpty;
}

QulLayoutValidationReport validateQulLayout(RawMushafLayout layout) {
  final issues = <String>[];

  if (layout.pageCount != 604) {
    issues.add('Expected 604 pages, info table declares ${layout.pageCount}.');
  }

  final linesByPage = <int, List<RawMushafLine>>{};
  for (final line in layout.lines) {
    linesByPage.putIfAbsent(line.pageNumber, () => []).add(line);
  }

  if (linesByPage.length != layout.pageCount) {
    issues.add(
      'Expected ${layout.pageCount} distinct pages in the data, found '
      '${linesByPage.length}.',
    );
  }

  for (final entry in linesByPage.entries) {
    final lineNumbers = entry.value.map((l) => l.lineNumber).toList()..sort();
    final expected = List.generate(lineNumbers.length, (i) => i + 1);
    var contiguous = lineNumbers.length == expected.length;
    if (contiguous) {
      for (var i = 0; i < lineNumbers.length; i++) {
        if (lineNumbers[i] != expected[i]) {
          contiguous = false;
          break;
        }
      }
    }
    if (!contiguous) {
      issues.add(
        'Page ${entry.key} has non-contiguous line numbers $lineNumbers.',
      );
    }
  }

  for (final line in layout.lines) {
    if (line.lineType == MushafLineType.quranText &&
        (line.firstWordId == null || line.lastWordId == null)) {
      issues.add(
        'Page ${line.pageNumber} line ${line.lineNumber} is an ayah line '
        'but has no word-id range.',
      );
    }
    if (line.lineType != MushafLineType.quranText &&
        (line.firstWordId != null || line.lastWordId != null)) {
      issues.add(
        'Page ${line.pageNumber} line ${line.lineNumber} is a '
        '${line.lineType.name} line but unexpectedly has a word-id range.',
      );
    }
  }

  return QulLayoutValidationReport(issues);
}
