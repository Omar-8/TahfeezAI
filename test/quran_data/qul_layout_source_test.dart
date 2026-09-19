// Structural validation of the REAL, user-provided QUL KFGQPC V2 layout
// file vendored at tool/quran_data/sources/qpc-v2-15-lines.db.zip. This
// checks the actual file's shape (604 pages, 15 lines/page, line-type
// enumeration) every time `flutter test` runs, so the vendored resource
// can never silently regress or be swapped for something structurally
// different. It never resolves or fabricates word-level content — the
// companion word dataset needed for that has not been supplied (see
// docs/QURAN_DATA_PROVENANCE.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/quran_data/src/mushaf_layout_source.dart';

void main() {
  final zip = File(
    p.join('tool', 'quran_data', 'sources', 'qpc-v2-15-lines.db.zip'),
  );

  test('the vendored QUL layout source file is present', () {
    expect(
      zip.existsSync(),
      isTrue,
      reason: 'tool/quran_data/sources/qpc-v2-15-lines.db.zip is missing',
    );
  });

  test('the real QUL layout is structurally valid', () async {
    final tempDir = Directory.systemTemp.createTempSync('qul_layout_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final result = Process.runSync('unzip', [
      '-o',
      zip.path,
      '-d',
      tempDir.path,
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final source = QulKfgqpcV2MushafDataSource(
      File(p.join(tempDir.path, 'qpc-v2-15-lines.db')),
    );
    final info = source.readInfo();
    expect(info.pageCount, 604);
    expect(info.linesPerPage, 15);

    final layout = await source.loadRawLayout();
    final report = validateQulLayout(layout);
    expect(report.isValid, isTrue, reason: report.issues.join('\n'));

    final byType = <String, int>{};
    for (final l in layout.lines) {
      byType[l.lineType.name] = (byType[l.lineType.name] ?? 0) + 1;
    }
    // 114 surahs each get a header; every surah except Al-Fatiha and
    // At-Tawbah gets a separate Bismillah line (112).
    expect(byType['surahHeader'], 114);
    expect(byType['bismillah'], 112);
  });
}
