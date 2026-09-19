import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_line_layout.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_word_measurer.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

import 'mushaf_test_fixtures.dart';

/// A deterministic fake measurer (see
/// `test/features/mushaf/domain/mushaf_page_layout_engine_test.dart` for
/// the same pattern) — these are layout-invariant tests over *real* page/
/// line/word data loaded through the repository, not a test of the
/// measurer itself.
class _FakeMeasurer implements MushafWordMeasurer {
  const _FakeMeasurer();

  @override
  double measure(String text, double fontSize) =>
      text.length * 10 * (fontSize / 28);
}

void main() {
  late DriftQuranRepository repo;
  final engine = MushafPageLayoutEngine(measurer: const _FakeMeasurer());

  setUpAll(() async {
    final db = QuranDatabase(NativeDatabase.memory());
    await const QuranDatasetImporter().import(db, buildMushafTestPayload());
    repo = DriftQuranRepository(db);
  });

  Future<({List<MushafLineLayout> lines})> layoutFullPage(
    int pageNumber, {
    double width = 320,
  }) async {
    final lines = await repo.getPageLines(
      mushafId: mushafTestMushafId,
      pageNumber: pageNumber,
    );
    final pageWords = await repo.getWordsForPage(
      mushafId: mushafTestMushafId,
      pageNumber: pageNumber,
      scriptCode: mushafTestScriptCode,
    );
    final wordsByLine = <int, List<AyahWord>>{
      for (final line in lines) line.lineNumber: _trim(pageWords, line),
    };
    final layout = engine.layoutPage(
      pageNumber: pageNumber,
      lines: lines,
      wordsByLineNumber: wordsByLine,
      availableWidth: width,
    );
    return (lines: layout.lines);
  }

  group('Page 1 -- opening chapter (Al-Fatihah analog)', () {
    test('has the expected line count and structure', () async {
      final result = await layoutFullPage(1);
      expect(result.lines, hasLength(5));
      expect(result.lines[0].lineType, MushafLineType.surahHeader);
      expect(result.lines[1].lineType, MushafLineType.bismillah);
      expect(
        result.lines
            .sublist(2)
            .every((l) => l.lineType == MushafLineType.quranText),
        isTrue,
      );
    });

    test('the final line is centered and does not overflow', () async {
      final result = await layoutFullPage(1);
      final lastLine = result.lines.last;
      expect(lastLine.isCentered, isTrue);
      expect(lastLine.lineWidth, lessThanOrEqualTo(320));
    });

    test('no line overflows the available width', () async {
      final result = await layoutFullPage(1);
      for (final line in result.lines) {
        expect(line.lineWidth, lessThanOrEqualTo(320));
      }
    });
  });

  group('Page 2 -- beginning of a longer chapter', () {
    test('has a header, Bismillah, and three justified text lines', () async {
      final result = await layoutFullPage(2);
      expect(result.lines, hasLength(5));
      expect(result.lines[0].lineType, MushafLineType.surahHeader);
      expect(result.lines[1].lineType, MushafLineType.bismillah);
      for (final line in result.lines.sublist(2)) {
        expect(line.lineType, MushafLineType.quranText);
        expect(line.isCentered, isFalse);
      }
    });

    test('placements are deterministic across repeated layout calls', () async {
      final first = await layoutFullPage(2);
      final second = await layoutFullPage(2);
      expect(first.lines, second.lines);
    });
  });

  group('Page 3 -- a plain mid-chapter page', () {
    test('has no header or Bismillah, only text lines', () async {
      final result = await layoutFullPage(3);
      expect(result.lines, hasLength(3));
      expect(
        result.lines.every((l) => l.lineType == MushafLineType.quranText),
        isTrue,
      );
    });

    test('no line overflows and none unexpectedly wraps (single placement run each)', () async {
      final result = await layoutFullPage(3);
      for (final line in result.lines) {
        expect(line.lineWidth, lessThanOrEqualTo(320));
        // Placements strictly increase in x -- a single, non-wrapping run.
        for (var i = 1; i < line.placements.length; i++) {
          expect(
            line.placements[i].x,
            greaterThanOrEqualTo(
              line.placements[i - 1].x + line.placements[i - 1].width,
            ),
          );
        }
      }
    });
  });

  group('Page 4 -- a chapter transition', () {
    test(
      'ends one chapter (centered final line) and begins the next',
      () async {
        final result = await layoutFullPage(4);
        expect(result.lines, hasLength(5));
        expect(result.lines[0].lineType, MushafLineType.quranText);
        expect(result.lines[1].lineType, MushafLineType.quranText);
        expect(result.lines[1].isCentered, isTrue); // end of chapter 55.
        expect(result.lines[2].lineType, MushafLineType.surahHeader);
        expect(result.lines[2].surahNo, 56);
        expect(result.lines[3].lineType, MushafLineType.bismillah);
        expect(result.lines[4].lineType, MushafLineType.quranText);
      },
    );
  });

  group('Page 5 -- the final page', () {
    test('ends in a short, centered final line', () async {
      final result = await layoutFullPage(5);
      expect(result.lines, hasLength(3));
      expect(result.lines.last.isCentered, isTrue);
      expect(result.lines.last.lineWidth, lessThanOrEqualTo(320));
    });
  });
}

List<AyahWord> _trim(List<AyahWord> pageWords, MushafLine line) {
  final startAyahId = line.startAyahId;
  final endAyahId = line.endAyahId;
  final startWordIndex = line.startWordIndex;
  final endWordIndex = line.endWordIndex;
  if (startAyahId == null ||
      endAyahId == null ||
      startWordIndex == null ||
      endWordIndex == null) {
    return const [];
  }
  return pageWords.where((w) {
    if (w.ayahId < startAyahId || w.ayahId > endAyahId) return false;
    if (w.ayahId == startAyahId && w.wordIndex < startWordIndex) return false;
    if (w.ayahId == endAyahId && w.wordIndex > endWordIndex) return false;
    return true;
  }).toList();
}
