import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_word_measurer.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

/// A deterministic fake: each character is exactly [charWidth] wide at
/// [MushafPageLayoutEngine.baseFontSize] (fontSize 1), scaling linearly
/// with font size -- enough to exercise the engine's scaling/justification
/// math without depending on real font shaping.
class FakeWordMeasurer implements MushafWordMeasurer {
  const FakeWordMeasurer({this.charWidth = 10});

  final double charWidth;

  @override
  double measure(String text, double fontSize) =>
      text.length * charWidth * (fontSize / 28);
}

AyahWord _word(int ayahId, int index, String text) =>
    AyahWord(ayahId: ayahId, scriptId: 1, wordIndex: index, text: text);

MushafLine _textLine(int lineNumber, {bool isCentered = false}) => MushafLine(
  mushafId: 1,
  pageNumber: 1,
  lineNumber: lineNumber,
  lineType: MushafLineType.quranText,
  isCentered: isCentered,
  startAyahId: 1,
  startWordIndex: 0,
  endAyahId: 1,
  endWordIndex: 0,
);

void main() {
  final engine = MushafPageLayoutEngine(measurer: const FakeWordMeasurer());

  group('layoutLine', () {
    test('a line with no words produces an empty, zero-width layout', () {
      final line = MushafLine(
        mushafId: 1,
        pageNumber: 1,
        lineNumber: 1,
        lineType: MushafLineType.surahHeader,
        isCentered: true,
        surahNo: 2,
      );

      final layout = engine.layoutLine(
        line: line,
        words: const [],
        availableWidth: 300,
      );

      expect(layout.placements, isEmpty);
      expect(layout.lineWidth, 0);
      expect(layout.surahNo, 2);
      expect(layout.lineType, MushafLineType.surahHeader);
    });

    test('a justified line never exceeds the available width', () {
      final words = [for (var i = 0; i < 6; i++) _word(1, i, 'word$i')];

      final layout = engine.layoutLine(
        line: _textLine(1),
        words: words,
        availableWidth: 320,
      );

      expect(layout.lineWidth, lessThanOrEqualTo(320));
      expect(layout.placements, hasLength(6));
    });

    test('a justified line fills the available width when it can', () {
      final words = [for (var i = 0; i < 5; i++) _word(1, i, 'ab')];

      // Chosen close to the words' natural width (~132 at the base font
      // size) so the font scale needed stays within [minScale, maxScale]
      // and the spacing clamp never engages -- the "typical line" case
      // where justification should closely fill the box. A far larger
      // available width instead hits both clamps by design (see the
      // "font size is clamped" and "centered line" cases below) and would
      // *not* fully justify -- that is intentional, not a bug.
      final layout = engine.layoutLine(
        line: _textLine(1),
        words: words,
        availableWidth: 140,
      );

      expect(layout.lineWidth, closeTo(140, 1));
    });

    test('a centered line does not stretch to fill the available width', () {
      final words = [_word(1, 0, 'ab'), _word(1, 1, 'cd')];

      final layout = engine.layoutLine(
        line: _textLine(1, isCentered: true),
        words: words,
        availableWidth: 1000,
      );

      // A short centered line stays close to its natural width, not
      // stretched to fill 1000 units.
      expect(layout.lineWidth, lessThan(200));
    });

    test('font size is clamped within [minScale, maxScale] of the base', () {
      final engine = MushafPageLayoutEngine(
        measurer: const FakeWordMeasurer(),
        baseFontSize: 28,
        minScale: 0.7,
        maxScale: 1.4,
      );

      // An extremely long line, forced to shrink well past minScale
      // without the clamp.
      final manyWords = [for (var i = 0; i < 40; i++) _word(1, i, 'longword')];
      final shrunk = engine.layoutLine(
        line: _textLine(1),
        words: manyWords,
        availableWidth: 300,
      );
      expect(shrunk.fontSize, greaterThanOrEqualTo(28 * 0.7 - 0.001));

      // A single short word, which could otherwise scale up unboundedly
      // to fill a huge available width.
      final oneWord = [_word(1, 0, 'a')];
      final grown = engine.layoutLine(
        line: _textLine(1),
        words: oneWord,
        availableWidth: 5000,
      );
      expect(grown.fontSize, lessThanOrEqualTo(28 * 1.4 + 0.001));
    });

    test(
      'placements are in reading order with non-overlapping, increasing x',
      () {
        final words = [for (var i = 0; i < 4; i++) _word(1, i, 'w$i')];

        final layout = engine.layoutLine(
          line: _textLine(1),
          words: words,
          availableWidth: 300,
        );

        for (var i = 1; i < layout.placements.length; i++) {
          final previous = layout.placements[i - 1];
          final current = layout.placements[i];
          expect(current.x, greaterThanOrEqualTo(previous.x + previous.width));
          expect(current.wordIndex, previous.wordIndex + 1);
        }
      },
    );

    test('layout is deterministic for identical inputs', () {
      final words = [for (var i = 0; i < 5; i++) _word(2, i, 'kalima$i')];
      final line = _textLine(3);

      final first = engine.layoutLine(
        line: line,
        words: words,
        availableWidth: 350,
      );
      final second = engine.layoutLine(
        line: line,
        words: words,
        availableWidth: 350,
      );

      expect(first, second);
    });
  });

  group('layoutPage', () {
    test('produces one MushafLineLayout per input line, in order', () {
      final lines = [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.surahHeader,
          isCentered: true,
          surahNo: 1,
        ),
        const MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 2,
          lineType: MushafLineType.bismillah,
          isCentered: true,
        ),
        _textLine(3),
      ];

      final layout = engine.layoutPage(
        pageNumber: 1,
        lines: lines,
        wordsByLineNumber: {
          3: [_word(1, 0, 'lafz'), _word(1, 1, 'kalima')],
        },
        availableWidth: 300,
      );

      expect(layout.pageNumber, 1);
      expect(layout.lines, hasLength(3));
      expect(layout.lines.map((l) => l.lineNumber), [1, 2, 3]);
      expect(layout.lines[0].placements, isEmpty);
      expect(layout.lines[1].placements, isEmpty);
      expect(layout.lines[2].placements, hasLength(2));
    });
  });
}
