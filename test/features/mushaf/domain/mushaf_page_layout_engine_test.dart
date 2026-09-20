import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_word_measurer.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';

/// A deterministic fake: each character is exactly [charWidth] wide at
/// [MushafPageLayoutEngine.baseFontSize] (fontSize 1), scaling linearly
/// with font size -- enough to exercise the engine's scaling/justification
/// math without depending on real font shaping. Also counts calls, so
/// tests can prove the engine measures at line granularity, not per word
/// (`joinMushafLineText`'s separator is included in every measured
/// string's length, matching what a real line-level measurement call
/// actually receives).
class FakeWordMeasurer implements MushafWordMeasurer {
  FakeWordMeasurer({this.charWidth = 10});

  final double charWidth;
  int callCount = 0;

  @override
  double measure(String text, double fontSize, {String? fontFamily}) {
    callCount++;
    return text.length * charWidth * (fontSize / 28);
  }
}

MushafToken _token(int sourceTokenId, String text) => MushafToken(
  mushafId: 1,
  sourceTokenId: sourceTokenId,
  sequenceIndex: sourceTokenId - 1,
  tokenType: MushafTokenType.quranWord,
  displayText: text,
  surahNumber: 1,
  ayahNumber: 1,
  canonicalAyahId: 1001,
  canonicalWordIndex: sourceTokenId - 1,
);

MushafLine _textLine(int lineNumber, {bool isCentered = false}) => MushafLine(
  mushafId: 1,
  pageNumber: 1,
  lineNumber: lineNumber,
  lineType: MushafLineType.quranText,
  isCentered: isCentered,
  firstTokenId: 1,
  lastTokenId: 1,
);

void main() {
  group('layoutLine', () {
    final engine = MushafPageLayoutEngine(measurer: FakeWordMeasurer());

    test('a line with no tokens produces an empty, zero-width layout', () {
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
        tokens: const [],
        availableWidth: 300,
      );

      expect(layout.tokenCount, 0);
      expect(layout.lineWidth, 0);
      expect(layout.surahNo, 2);
      expect(layout.lineType, MushafLineType.surahHeader);
    });

    test('a justified line never exceeds the available width', () {
      final tokens = [for (var i = 0; i < 6; i++) _token(i + 1, 'word$i')];

      final layout = engine.layoutLine(
        line: _textLine(1),
        tokens: tokens,
        availableWidth: 320,
      );

      expect(layout.lineWidth, lessThanOrEqualTo(320));
      expect(layout.tokenCount, 6);
    });

    test('a justified line fills the available width when it can', () {
      final tokens = [for (var i = 0; i < 5; i++) _token(i + 1, 'ab')];

      // Chosen close to the tokens' natural width (~132 at the base font
      // size) so the font scale needed stays within [minScale, maxScale]
      // and the spacing clamp never engages -- the "typical line" case
      // where justification should closely fill the box. A far larger
      // available width instead hits both clamps by design (see the
      // "font size is clamped" and "centered line" cases below) and would
      // *not* fully justify -- that is intentional, not a bug.
      final layout = engine.layoutLine(
        line: _textLine(1),
        tokens: tokens,
        availableWidth: 140,
      );

      expect(layout.lineWidth, closeTo(140, 1));
    });

    test('a centered line does not stretch to fill the available width', () {
      final tokens = [_token(1, 'ab'), _token(2, 'cd')];

      final layout = engine.layoutLine(
        line: _textLine(1, isCentered: true),
        tokens: tokens,
        availableWidth: 1000,
      );

      // A short centered line stays close to its natural width, not
      // stretched to fill 1000 units -- it still gets the small *base*
      // inter-word gap (unaffected by how much room is available), just
      // never the *justified* spacing that would stretch it to fill the
      // line.
      expect(layout.lineWidth, lessThan(200));
    });

    test('font size is clamped within [minScale, maxScale] of the base', () {
      final engine = MushafPageLayoutEngine(
        measurer: FakeWordMeasurer(),
        baseFontSize: 28,
        minScale: 0.7,
        maxScale: 1.4,
      );

      // An extremely long line, forced to shrink well past minScale
      // without the clamp.
      final manyTokens = [
        for (var i = 0; i < 40; i++) _token(i + 1, 'longword'),
      ];
      final shrunk = engine.layoutLine(
        line: _textLine(1),
        tokens: manyTokens,
        availableWidth: 300,
      );
      expect(shrunk.fontSize, greaterThanOrEqualTo(28 * 0.7 - 0.001));

      // A single short token, which could otherwise scale up unboundedly
      // to fill a huge available width.
      final oneToken = [_token(1, 'a')];
      final grown = engine.layoutLine(
        line: _textLine(1),
        tokens: oneToken,
        availableWidth: 5000,
      );
      expect(grown.fontSize, lessThanOrEqualTo(28 * 1.4 + 0.001));
    });

    test('layout is deterministic for identical inputs', () {
      final tokens = [for (var i = 0; i < 5; i++) _token(i + 1, 'kalima$i')];
      final line = _textLine(3);

      final first = engine.layoutLine(
        line: line,
        tokens: tokens,
        availableWidth: 350,
      );
      final second = engine.layoutLine(
        line: line,
        tokens: tokens,
        availableWidth: 350,
      );

      expect(first, second);
    });

    test('measures a line a small, constant number of times regardless of '
        'word count -- a joined-text plus a bare-separator measurement for '
        'the natural-width/scale decision, then the same pair again at the '
        'final font size -- never once per token. A 100-token page '
        'measuring per word, twice each, was the exact per-word cost this '
        'line-level design replaces.', () {
      final measurer = FakeWordMeasurer();
      final engine = MushafPageLayoutEngine(measurer: measurer);
      final manyTokens = [
        for (var i = 0; i < 100; i++) _token(i + 1, 'kalima'),
      ];

      engine.layoutLine(
        line: _textLine(1),
        tokens: manyTokens,
        availableWidth: 400,
      );

      expect(measurer.callCount, 4);
    });
  });

  group('layoutPage', () {
    final engine = MushafPageLayoutEngine(measurer: FakeWordMeasurer());

    test('every line on a page shares one font size, even when natural line '
        'widths vary hugely (e.g. Al-Fatiha-style short vs. long ayat) — a '
        'real bug: per-line-independent scaling made short verses balloon '
        'toward maxScale while dense neighboring lines stayed near 1.0, so '
        'verses on the same page visibly rendered at different sizes', () {
      final lines = [
        _textLine(1), // one very short line: a single 2-letter word
        _textLine(2), // one very long line: many long words
      ];

      final layout = engine.layoutPage(
        pageNumber: 1,
        lines: lines,
        tokensByLineNumber: {
          1: [_token(1, 'ab')],
          2: [for (var i = 0; i < 20; i++) _token(i + 2, 'longwordhere')],
        },
        availableWidth: 400,
      );

      final fontSizes = layout.lines
          .where((l) => l.tokenCount > 0)
          .map((l) => l.fontSize)
          .toSet();
      expect(
        fontSizes,
        hasLength(1),
        reason: 'both lines must render at the exact same font size',
      );

      // Calibrated to the page's widest line (the binding constraint),
      // not the shortest — the short line must not blow up to maxScale.
      final longLineNaturalWidth = 12 * 10 * 20 + 8 * 19; // charWidth=10
      final expectedScale = (400 / longLineNaturalWidth).clamp(0.7, 1.4);
      expect(fontSizes.single, closeTo(28 * expectedScale, 0.01));
    });

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
        tokensByLineNumber: {
          3: [_token(1, 'lafz'), _token(2, 'kalima')],
        },
        availableWidth: 300,
      );

      expect(layout.pageNumber, 1);
      expect(layout.lines, hasLength(3));
      expect(layout.lines.map((l) => l.lineNumber), [1, 2, 3]);
      expect(layout.lines[0].tokenCount, 0);
      expect(layout.lines[1].tokenCount, 0);
      expect(layout.lines[2].tokenCount, 2);
    });

    test('measures each line a small, constant number of times regardless of '
        'word count -- the page-wide calibration scan plus each line\'s own '
        'final-size measurement, each a joined-text/bare-separator pair -- '
        'never once per token. A 15-line, 120-word page measures a small '
        'constant total under this design, not 240+.', () {
      final measurer = FakeWordMeasurer();
      final engine = MushafPageLayoutEngine(measurer: measurer);
      final lines = [for (var i = 1; i <= 15; i++) _textLine(i)];
      final tokensByLineNumber = {
        for (final line in lines)
          line.lineNumber: [
            for (var i = 0; i < 8; i++)
              _token(line.lineNumber * 100 + i, 'kalima'),
          ],
      };

      engine.layoutPage(
        pageNumber: 1,
        lines: lines,
        tokensByLineNumber: tokensByLineNumber,
        availableWidth: 400,
      );

      // A joined+separator pair per line for the page-wide calibration
      // scan (15 lines * 2 = 30), plus the same pair again per line
      // inside `layoutLine`'s own spacing decision (15 * 2 = 30) = 60
      // total -- never proportional to the 120 total tokens on the page
      // (which, measured per word twice each as an earlier design did,
      // would have been 240+).
      expect(measurer.callCount, 60);
    });
  });
}
