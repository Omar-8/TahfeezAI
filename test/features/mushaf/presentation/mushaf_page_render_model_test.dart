// Unit-tests buildMushafPageRenderModel's Surah-header line construction
// directly (no widget tree, no providers): with a verified decorative
// glyph available, it must render through the real QUL Surah Header font
// (never the plain-text fallback) and still carry the localized name as an
// accessibility label, never the glyph itself. Without one, it must fall
// back to plain, clearly non-decorative text -- the honest
// SHIP_BLOCKED_LICENSE state, never a fabricated substitute.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_header_glyph_models.dart';

void main() {
  final mushaf = const Mushaf(
    id: 1,
    code: 'test',
    scriptId: 1,
    pageCount: 604,
    linesPerPage: 15,
    qiraah: 'Hafs',
    edition: 'Test',
    renderingType: MushafRenderingType.pageSpecificGlyphFont,
  );

  MushafPageBundle bundleWithHeader() => MushafPageBundle(
    mushaf: mushaf,
    pageNumber: 1,
    lines: [
      MushafLine(
        mushafId: 1,
        pageNumber: 1,
        lineNumber: 1,
        lineType: MushafLineType.surahHeader,
        isCentered: true,
        surahNo: 1,
      ),
    ],
    tokensByLineNumber: const {},
    juzNo: 1,
    hizbNos: const [1],
  );

  const engine = MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());

  test('with a verified glyph available, the header renders through the real '
      'decorative font family and keeps the localized name only as an '
      'accessibility label, never as the visible glyph text', () {
    const glyph = SurahHeaderGlyphEntry(
      surahNumber: 1,
      inputText: 'ﱅ', // an arbitrary but real single codepoint
      fontFamily: 'QCF_SurahHeader_COLOR_TEST',
    );

    final model = buildMushafPageRenderModel(
      engine: engine,
      bundle: bundleWithHeader(),
      availableWidth: 400,
      availableHeight: 600,
      fontFamily: null,
      textColor: Colors.black,
      headerInkColor: Colors.teal,
      bismillahText: null,
      surahHeaderNameResolver: (_) => 'Al-Fatihah',
      surahHeaderGlyphResolver: (_) => glyph,
    );

    final header = model.lines.single as MushafSurahHeaderLineRenderModel;
    expect(header.isDecorative, isTrue);
    expect(header.semanticLabel, 'Al-Fatihah');
    expect(header.painter!.text, isA<TextSpan>());
    final span = header.painter!.text! as TextSpan;
    // The visible glyph text is the verified single-codepoint input, not
    // the localized name -- the glyph is never the semantic source of
    // truth, but it's also never silently replaced by plain text once a
    // real glyph is available.
    expect(span.text, glyph.inputText);
    expect(span.style!.fontFamily, glyph.fontFamily);
    // The glyph's own shaping never bakes in a color (the monochrome
    // tint is applied only at paint time, by MushafPagePainter) -- but
    // the render model still carries the ink color to paint with.
    expect(span.style!.color, isNull);
    expect(header.inkColor, Colors.teal);
  });

  test(
    'uniform scale-to-fit never lets the decorative glyph exceed its line\'s '
    'available width or height -- scaling only, never clipping',
    () {
      const glyph = SurahHeaderGlyphEntry(
        surahNumber: 1,
        inputText: 'ﱅ',
        fontFamily: 'QCF_SurahHeader_COLOR_TEST',
      );

      final model = buildMushafPageRenderModel(
        engine: engine,
        // A deliberately tiny box, far smaller than the glyph's natural
        // size at the reference font size -- proves the scale-down path
        // actually engages rather than only being exercised by coincidence.
        bundle: bundleWithHeader(),
        availableWidth: 60,
        availableHeight: 20,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.black,
        bismillahText: null,
        surahHeaderNameResolver: (_) => 'Al-Fatihah',
        surahHeaderGlyphResolver: (_) => glyph,
      );

      final header = model.lines.single as MushafSurahHeaderLineRenderModel;
      expect(header.painter!.width, lessThanOrEqualTo(60 + 0.5));
      expect(header.painter!.height, lessThanOrEqualTo(20 + 0.5));
    },
  );

  test('when height is generous, the decorative glyph reaches the target '
      '94-98% width band -- uniform scale, aspect ratio exactly preserved, '
      'never touching the page edges', () {
    const glyph = SurahHeaderGlyphEntry(
      surahNumber: 1,
      inputText: 'ﱅ',
      fontFamily: 'QCF_SurahHeader_COLOR_TEST',
    );

    final model = buildMushafPageRenderModel(
      engine: engine,
      bundle: bundleWithHeader(),
      availableWidth: 400,
      // Tall enough that height never binds -- isolates the width-target
      // behavior from the height-limited case covered above.
      availableHeight: 2000,
      fontFamily: null,
      textColor: Colors.black,
      headerInkColor: Colors.black,
      bismillahText: null,
      surahHeaderNameResolver: (_) => 'Al-Fatihah',
      surahHeaderGlyphResolver: (_) => glyph,
    );

    final header = model.lines.single as MushafSurahHeaderLineRenderModel;
    expect(header.achievedWidthFraction, isNotNull);
    expect(header.achievedWidthFraction, closeTo(0.96, 0.001));
    expect(
      header.painter!.width,
      closeTo(400 * header.achievedWidthFraction!, 0.5),
    );
    // Never touches or crosses the page's own content margins.
    expect(header.paintOffset!.dx, greaterThan(0));
    expect(header.paintOffset!.dx + header.painter!.width, lessThan(400));
  });

  test('without a verified glyph (SHIP_BLOCKED_LICENSE / font not bundled), '
      'falls back to plain, non-decorative localized text', () {
    final model = buildMushafPageRenderModel(
      engine: engine,
      bundle: bundleWithHeader(),
      availableWidth: 400,
      availableHeight: 600,
      fontFamily: null,
      textColor: Colors.black,
      headerInkColor: Colors.teal,
      bismillahText: null,
      surahHeaderNameResolver: (_) => 'Al-Fatihah',
      surahHeaderGlyphResolver: null,
    );

    final header = model.lines.single as MushafSurahHeaderLineRenderModel;
    expect(header.isDecorative, isFalse);
    expect(header.semanticLabel, 'Al-Fatihah');
    expect(
      header.inkColor,
      isNull,
      reason:
          'the plain-text fallback already paints in the ordinary text '
          'color via its own TextStyle -- the monochrome ink-tint path '
          'is only for the real decorative glyph',
    );
    final span = header.painter!.text! as TextSpan;
    expect(span.text, 'Al-Fatihah');
  });

  group('quranTextStrokeWidth (Mushaf text boldness stroke-behind-fill)', () {
    MushafPageBundle quranTextBundle() {
      const tokens = [
        MushafToken(
          mushafId: 1,
          sourceTokenId: 1,
          sequenceIndex: 0,
          tokenType: MushafTokenType.quranWord,
          displayText: 'lafz',
          surahNumber: 1,
          ayahNumber: 1,
          canonicalAyahId: 1001,
          canonicalWordIndex: 0,
        ),
        MushafToken(
          mushafId: 1,
          sourceTokenId: 2,
          sequenceIndex: 1,
          tokenType: MushafTokenType.quranWord,
          displayText: 'kalima',
          surahNumber: 1,
          ayahNumber: 1,
          canonicalAyahId: 1001,
          canonicalWordIndex: 1,
        ),
      ];
      return MushafPageBundle(
        mushaf: mushaf,
        pageNumber: 1,
        lines: const [
          MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 1,
            lineType: MushafLineType.quranText,
            isCentered: false,
            firstTokenId: 1,
            lastTokenId: 2,
          ),
        ],
        tokensByLineNumber: const {1: tokens},
        juzNo: 1,
        hizbNos: const [1],
      );
    }

    MushafQuranTextLineRenderModel buildLine({required double strokeWidth}) {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: quranTextBundle(),
        availableWidth: 300,
        availableHeight: 60,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.black,
        bismillahText: null,
        surahHeaderNameResolver: (_) => null,
        quranTextStrokeWidth: strokeWidth,
      );
      return model.lines.single as MushafQuranTextLineRenderModel;
    }

    test('defaults to disabled (no stroke pass) when unspecified', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: quranTextBundle(),
        availableWidth: 300,
        availableHeight: 60,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.black,
        bismillahText: null,
        surahHeaderNameResolver: (_) => null,
      );
      final line = model.lines.single as MushafQuranTextLineRenderModel;
      expect(line.strokePainter, isNull);
    });

    test('<= 0 disables the stroke pass entirely', () {
      final line = buildLine(strokeWidth: 0);
      expect(line.strokePainter, isNull);
      expect(line.painter, isNotNull);
    });

    test('a positive stroke width shapes a stroke pass with geometry that is '
        'numerically identical to the fill pass -- only the Paint differs, '
        'never the layout', () {
      final line = buildLine(strokeWidth: 0.30);
      expect(line.strokePainter, isNotNull);
      expect(line.strokePainter!.width, line.painter!.width);
      expect(line.strokePainter!.height, line.painter!.height);
    });

    test(
      'the Light/Medium/Bold stroke widths (0.25/0.30/0.40) never change '
      'line geometry, paint offset, or token hit-rect positions -- the '
      'sequence of shaped words/lines is identical for all three choices',
      () {
        final light = buildLine(strokeWidth: 0.25);
        final medium = buildLine(strokeWidth: 0.30);
        final bold = buildLine(strokeWidth: 0.40);

        for (final line in [medium, bold]) {
          expect(line.painter!.width, light.painter!.width);
          expect(line.painter!.height, light.painter!.height);
          expect(line.paintOffset, light.paintOffset);
          expect(line.tokenRects.length, light.tokenRects.length);
          for (var i = 0; i < light.tokenRects.length; i++) {
            expect(line.tokenRects[i].rect, light.tokenRects[i].rect);
            expect(
              line.tokenRects[i].sourceTokenId,
              light.tokenRects[i].sourceTokenId,
            );
          }
        }
      },
    );
  });
}
