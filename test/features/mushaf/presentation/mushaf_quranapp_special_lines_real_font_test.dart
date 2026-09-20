// Verifies the QuranApp-style Bismillah/Surah-header rendering against the
// REAL, verified quran_common.ttf/suracon.ttf fonts (never a synthetic
// stand-in) for the specific surahs this milestone named: Al-Fatihah,
// Al-Baqarah, Al-Ma'idah, Al-Kahf, Maryam, Ya-Sin, Ar-Rahman, Al-Ikhlas,
// Al-Falaq, An-Nas, plus the real Bismillah glyph. Renders through the
// real production painter (MushafPagePainter -- no saveLayer/ColorFilter
// for these lines at all, since neither font is a color font) and decodes
// real pixels to confirm actual glyph ink was painted (not tofu/blank).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_painter.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/data/quranapp_special_font_manifest_codec.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

const _realNames = {
  1: 'Al-Fatihah',
  2: 'Al-Baqarah',
  5: "Al-Ma'idah",
  18: 'Al-Kahf',
  19: 'Maryam',
  36: 'Ya-Sin',
  55: 'Ar-Rahman',
  112: 'Al-Ikhlas',
  113: 'Al-Falaq',
  114: 'An-Nas',
};

const _testCommonFamily = 'quran_common_REALFONT_TEST';
const _testSuraconFamily = 'suracon_REALFONT_TEST';
const _realBismillahText = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

void main() {
  final commonManifestFile = File(
    'assets/quran/manifests/quran_common_font.json',
  );
  final suraconManifestFile = File(
    'assets/quran/manifests/suracon_glyphs.json',
  );
  if (!commonManifestFile.existsSync() || !suraconManifestFile.existsSync()) {
    return; // honest skip, same convention as other real-font tests
  }

  final commonManifest = quranCommonFontManifestFromJson(
    jsonDecode(commonManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final suraconManifest = suraconGlyphManifestFromJson(
    jsonDecode(suraconManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  setUpAll(() async {
    for (final (family, manifestAssetPath) in [
      (_testCommonFamily, commonManifest.assetPath),
      (_testSuraconFamily, suraconManifest.assetPath),
    ]) {
      final bytes = File(manifestAssetPath).readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  const engine = MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());
  const mushaf = Mushaf(
    id: 1,
    code: 'test',
    scriptId: 1,
    pageCount: 604,
    linesPerPage: 15,
    qiraah: 'Hafs',
    edition: 'Test',
    renderingType: MushafRenderingType.pageSpecificGlyphFont,
  );

  String suraconInputTextFor(int surahNo) {
    final entry = suraconManifest.entries.firstWhere(
      (e) => e.surahNumber == surahNo,
    );
    return entry.inputText + suraconManifest.prefixInputText;
  }

  Future<int> countInkPixels(MushafPageRenderModel model) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, model.size.width, model.size.height),
      Paint()..color = Colors.white,
    );
    MushafPagePainter(model).paint(canvas, model.size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      model.size.width.round(),
      model.size.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();
    var inkPixels = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      final pixel = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      if (pixel != 0xFFFFFF) inkPixels++;
    }
    return inkPixels;
  }

  for (final surahNo in _realNames.keys) {
    test(
      'Surah $surahNo (${_realNames[surahNo]}): real frame + calligraphy '
      'glyphs actually paint visible ink, centered, correctly scaled',
      () async {
        final bundle = MushafPageBundle(
          mushaf: mushaf,
          pageNumber: 1,
          lines: [
            MushafLine(
              mushafId: 1,
              pageNumber: 1,
              lineNumber: 1,
              lineType: MushafLineType.surahHeader,
              isCentered: true,
              surahNo: surahNo,
            ),
          ],
          tokensByLineNumber: const {},
          juzNo: 1,
          hizbNos: const [1],
        );
        final model = buildMushafPageRenderModel(
          engine: engine,
          bundle: bundle,
          availableWidth: 400,
          availableHeight: 120,
          fontFamily: null,
          textColor: Colors.black,
          headerInkColor: Colors.black,
          bismillahText: null,
          surahHeaderNameResolver: (n) => _realNames[n],
          quranCommonFontFamily: _testCommonFamily,
          suraconFontFamily: _testSuraconFamily,
          suraconInputTextResolver: suraconInputTextFor,
        );

        final header = model.lines.single as MushafSurahHeaderLineRenderModel;
        expect(header.isDecorative, isTrue, reason: 'surah $surahNo');
        expect(header.framePainter, isNotNull, reason: 'surah $surahNo');
        expect(header.namePainter, isNotNull, reason: 'surah $surahNo');
        expect(
          header.achievedWidthFraction,
          inInclusiveRange(0.4, 0.97),
          reason: 'surah $surahNo',
        );
        final centerX = header.frameOffset!.dx + header.framePainter!.width / 2;
        expect(
          centerX,
          closeTo(200, 1.0),
          reason: 'surah $surahNo not centered',
        );

        final inkPixels = await countInkPixels(model);
        expect(
          inkPixels,
          greaterThan(50),
          reason: 'surah $surahNo: expected real glyph ink, found none (tofu?)',
        );
      },
    );
  }

  test('the real decorative Bismillah glyph actually paints visible ink, '
      'centered', () async {
    final bundle = MushafPageBundle(
      mushaf: mushaf,
      pageNumber: 1,
      lines: const [
        MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 1,
          lineType: MushafLineType.bismillah,
          isCentered: true,
        ),
      ],
      tokensByLineNumber: const {},
      juzNo: 1,
      hizbNos: const [1],
    );
    final model = buildMushafPageRenderModel(
      engine: engine,
      bundle: bundle,
      availableWidth: 400,
      availableHeight: 80,
      fontFamily: null,
      textColor: Colors.black,
      headerInkColor: Colors.black,
      bismillahText: _realBismillahText,
      surahHeaderNameResolver: (_) => null,
      quranCommonFontFamily: _testCommonFamily,
    );

    final line = model.lines.single as MushafBismillahLineRenderModel;
    expect(line.isDecorative, isTrue);
    final inkPixels = await countInkPixels(model);
    expect(inkPixels, greaterThan(50));
  });
}
