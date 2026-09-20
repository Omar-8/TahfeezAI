// Unit-tests buildMushafPageRenderModel's QuranApp-style Bismillah/Surah
// -header construction directly (no widget tree, no providers) -- the
// active mechanism (quran_common.ttf + suracon.ttf,
// docs/QURAN_DATA_PROVENANCE.md §12/§13), replacing the QUL COLR header
// this milestone stopped using in production (kept only as an unused
// development resource, still separately tested by
// mushaf_page_render_model_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

const _testCommonFamily = 'quran_common_TEST';
const _testSuraconFamily = 'suracon_TEST';
const _realBismillahText = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

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

  MushafPageBundle bundleWithLines(List<MushafLine> lines) => MushafPageBundle(
    mushaf: mushaf,
    pageNumber: 1,
    lines: lines,
    tokensByLineNumber: const {},
    juzNo: 1,
    hizbNos: const [1],
  );

  const engine = MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());

  group('Bismillah', () {
    MushafPageBundle bismillahBundle() => bundleWithLines([
      const MushafLine(
        mushafId: 1,
        pageNumber: 1,
        lineNumber: 1,
        lineType: MushafLineType.bismillah,
        isCentered: true,
      ),
    ]);

    test('with quran_common bundled, renders the real U+FDFD glyph -- never '
        'plain-text reconstruction from canonical Arabic, never a QPC page '
        'font, never a guessed QCF2BSML mapping -- while exposing the real '
        'canonical text (never the private-use codepoint) as an '
        'accessibility label', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: bismillahBundle(),
        availableWidth: 400,
        availableHeight: 600,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: _realBismillahText,
        surahHeaderNameResolver: (_) => null,
        quranCommonFontFamily: _testCommonFamily,
      );

      final line = model.lines.single as MushafBismillahLineRenderModel;
      expect(line.isDecorative, isTrue);
      final span = line.painter!.text! as TextSpan;
      expect(span.text, '﷽');
      expect(span.style!.fontFamily, _testCommonFamily);
      // The visible glyph is never the semantic source of truth.
      expect(line.semanticLabel, _realBismillahText);
      expect(line.semanticLabel, isNot(contains('﷽')));
    });

    test('never adds extra line height or exceeds the authoritative line box '
        '-- shrinks to fit instead', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: bismillahBundle(),
        // A deliberately tiny box, far smaller than the 36/28 reference
        // ratio would naturally produce.
        availableWidth: 50,
        availableHeight: 15,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: _realBismillahText,
        surahHeaderNameResolver: (_) => null,
        quranCommonFontFamily: _testCommonFamily,
      );

      final line = model.lines.single as MushafBismillahLineRenderModel;
      expect(line.height, 15, reason: 'the line\'s own box is never grown');
      expect(line.painter!.width, lessThanOrEqualTo(50 + 0.5));
      expect(line.painter!.height, lessThanOrEqualTo(15 + 0.5));
    });

    test('without quran_common bundled, falls back to plain text in the '
        'canonical Bismillah string (a clearly non-final dev fallback, '
        'never silently treated as production-equivalent)', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: bismillahBundle(),
        availableWidth: 400,
        availableHeight: 600,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: _realBismillahText,
        surahHeaderNameResolver: (_) => null,
        quranCommonFontFamily: null,
      );

      final line = model.lines.single as MushafBismillahLineRenderModel;
      expect(line.isDecorative, isFalse);
      final span = line.painter!.text! as TextSpan;
      expect(span.text, _realBismillahText);
    });

    test('Al-Fatihah 1:1 is never rendered through this mechanism -- only '
        'an explicit bismillah lineType is', () {
      // A quranText line (Al-Fatihah 1:1's real representation) must go
      // through the ordinary Quran-word path regardless of whether
      // quran_common is bundled -- proven structurally: MushafLineType
      // .quranText never reaches _buildBismillahLine at all (see the
      // dispatch switch in buildMushafPageRenderModel), so there is no
      // code path by which it could.
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: bundleWithLines([
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 1,
            lineType: MushafLineType.quranText,
            isCentered: false,
            firstTokenId: 1,
            lastTokenId: 1,
          ),
        ]),
        availableWidth: 400,
        availableHeight: 600,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: _realBismillahText,
        surahHeaderNameResolver: (_) => null,
        quranCommonFontFamily: _testCommonFamily,
      );
      expect(model.lines.single, isA<MushafQuranTextLineRenderModel>());
    });
  });

  group('Surah header', () {
    MushafPageBundle headerBundle() => bundleWithLines([
      const MushafLine(
        mushafId: 1,
        pageNumber: 1,
        lineNumber: 1,
        lineType: MushafLineType.surahHeader,
        isCentered: true,
        surahNo: 1,
      ),
    ]);

    test('with quran_common + suracon bundled, renders the frame (U+E000) '
        'with the verified Surah glyph + prefix overlaid -- never the QUL '
        'color-header artwork -- while exposing the localized name (never a '
        'private-use codepoint) as an accessibility label', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: headerBundle(),
        availableWidth: 400,
        availableHeight: 120,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: null,
        surahHeaderNameResolver: (_) => 'Al-Fatihah',
        quranCommonFontFamily: _testCommonFamily,
        suraconFontFamily: _testSuraconFamily,
        suraconInputTextResolver: (_) => '', // name + prefix
      );

      final header = model.lines.single as MushafSurahHeaderLineRenderModel;
      expect(header.isDecorative, isTrue);
      expect(header.semanticLabel, 'Al-Fatihah');
      expect(header.semanticLabel, isNot(contains('')));
      expect(header.semanticLabel, isNot(contains('')));

      expect(header.framePainter, isNotNull);
      final frameSpan = header.framePainter!.text! as TextSpan;
      expect(frameSpan.text, '');
      expect(frameSpan.style!.fontFamily, _testCommonFamily);
      expect(frameSpan.style!.color, Colors.teal);

      expect(header.namePainter, isNotNull);
      final nameSpan = header.namePainter!.text! as TextSpan;
      expect(nameSpan.text, '');
      expect(nameSpan.style!.fontFamily, _testSuraconFamily);

      // Never the old QUL mechanism's fields.
      expect(header.painter, isNull);

      // The name overlay gets a small downward nudge from the frame's own
      // vertical center -- much smaller than QuranApp's own 8dp-equivalent
      // shift (which compensates for *its* frame artwork's cavity sitting
      // above center, and doesn't apply to Tahfeez's `quran_common.ttf`
      // frame), but real ink measurement showed a shift of exactly 0 leans
      // the name slightly high (see `_surahHeaderNameVerticalShiftRatio`'s
      // doc comment).
      final frameCenterY =
          header.frameOffset!.dy + header.framePainter!.height / 2;
      final nameCenterY =
          header.nameOffset!.dy + header.namePainter!.height / 2;
      expect(nameCenterY, greaterThan(frameCenterY));
      // Small, not the old 8dp-equivalent lean: well under a quarter of
      // the frame's own rendered height.
      expect(
        nameCenterY - frameCenterY,
        lessThan(header.framePainter!.height * 0.25),
      );
    });

    test(
      'the frame is uniform-scaled toward the target width band without '
      'distorting its aspect ratio, and the name stays proportional to it',
      () {
        final model = buildMushafPageRenderModel(
          engine: engine,
          bundle: headerBundle(),
          availableWidth: 400,
          // Tall enough that height never binds.
          availableHeight: 2000,
          fontFamily: null,
          textColor: Colors.black,
          headerInkColor: Colors.teal,
          bismillahText: null,
          surahHeaderNameResolver: (_) => 'Al-Fatihah',
          quranCommonFontFamily: _testCommonFamily,
          suraconFontFamily: _testSuraconFamily,
          suraconInputTextResolver: (_) => '',
        );

        final header = model.lines.single as MushafSurahHeaderLineRenderModel;
        expect(header.achievedWidthFraction, isNotNull);
        expect(header.achievedWidthFraction, closeTo(0.96, 0.001));
        // Centered horizontally.
        final centerX = header.frameOffset!.dx + header.framePainter!.width / 2;
        expect(centerX, closeTo(200, 1.0));
      },
    );

    test('without quran_common/suracon bundled, falls back to plain '
        'localized text (a clearly non-final dev fallback)', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: headerBundle(),
        availableWidth: 400,
        availableHeight: 120,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: null,
        surahHeaderNameResolver: (_) => 'Al-Fatihah',
        quranCommonFontFamily: null,
        suraconFontFamily: null,
      );

      final header = model.lines.single as MushafSurahHeaderLineRenderModel;
      expect(header.isDecorative, isFalse);
      expect(header.framePainter, isNull);
      expect(header.namePainter, isNull);
      final span = header.painter!.text! as TextSpan;
      expect(span.text, 'Al-Fatihah');
    });

    test('a page with multiple Surah transitions: each header is '
        'independently decorative and correctly positioned on its own '
        'authoritative line, with the Bismillah between them untouched', () {
      final model = buildMushafPageRenderModel(
        engine: engine,
        bundle: bundleWithLines([
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 1,
            lineType: MushafLineType.surahHeader,
            isCentered: true,
            surahNo: 112, // Al-Ikhlas ends
          ),
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 2,
            lineType: MushafLineType.bismillah,
            isCentered: true,
          ),
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 3,
            lineType: MushafLineType.surahHeader,
            isCentered: true,
            surahNo: 113, // Al-Falaq begins
          ),
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 4,
            lineType: MushafLineType.bismillah,
            isCentered: true,
          ),
          const MushafLine(
            mushafId: 1,
            pageNumber: 1,
            lineNumber: 5,
            lineType: MushafLineType.surahHeader,
            isCentered: true,
            surahNo: 114, // An-Nas begins
          ),
        ]),
        availableWidth: 400,
        availableHeight: 600,
        fontFamily: null,
        textColor: Colors.black,
        headerInkColor: Colors.teal,
        bismillahText: _realBismillahText,
        surahHeaderNameResolver: (n) =>
            {112: 'Al-Ikhlas', 113: 'Al-Falaq', 114: 'An-Nas'}[n],
        quranCommonFontFamily: _testCommonFamily,
        suraconFontFamily: _testSuraconFamily,
        suraconInputTextResolver: (_) => '',
      );

      final headers = model.lines
          .whereType<MushafSurahHeaderLineRenderModel>()
          .toList();
      expect(headers, hasLength(3));
      for (final header in headers) {
        expect(header.isDecorative, isTrue);
        expect(header.framePainter, isNotNull);
        expect(header.namePainter, isNotNull);
      }
      // Each header stays on its own authoritative line, in order,
      // never sharing or drifting into a neighbor's slot.
      expect(headers[0].lineNumber, 1);
      expect(headers[1].lineNumber, 3);
      expect(headers[2].lineNumber, 5);
      expect(headers[0].top, lessThan(headers[1].top));
      expect(headers[1].top, lessThan(headers[2].top));

      final bismillahLines = model.lines
          .whereType<MushafBismillahLineRenderModel>()
          .toList();
      expect(bismillahLines, hasLength(2));
      for (final line in bismillahLines) {
        expect(line.isDecorative, isTrue);
      }
      expect(bismillahLines[0].top, greaterThan(headers[0].top));
      expect(bismillahLines[0].top, lessThan(headers[1].top));
      expect(bismillahLines[1].top, greaterThan(headers[1].top));
      expect(bismillahLines[1].top, lessThan(headers[2].top));
    });
  });
}
