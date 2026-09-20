// Visual spot-checks for the monochrome Surah header, using the app's own
// real per-theme headerInk colors (MushafAppearanceColors) and the real
// verified QUL Surah Header font -- a representative subset (not the full
// 9-surah x 5-theme matrix) alongside the rigorous, non-visual
// pixel-decomposition proof in mushaf_surah_header_monochrome_test.dart,
// which does cover all 9 named surahs.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_painter.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/data/surah_header_glyph_manifest_codec.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/surah_header_glyph_models.dart';

const testFontFamily = 'QCF_SurahHeader_COLOR_GOLDEN_TEST';
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

void main() {
  final manifestFile = File('assets/quran/manifests/surah_header_glyphs.json');
  if (!manifestFile.existsSync()) {
    return; // honest skip, same as other real-font tests
  }

  final manifest = surahHeaderGlyphManifestFromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  setUpAll(() async {
    final fontFile = File(manifest.assetPath);
    final loader = FontLoader(testFontFamily)
      ..addFont(Future.value(ByteData.sublistView(fontFile.readAsBytesSync())));
    await loader.load();
  });

  SurahHeaderGlyphEntry glyphFor(int surahNo) {
    final entry = manifest.entries.firstWhere((e) => e.surahNumber == surahNo);
    return SurahHeaderGlyphEntry(
      surahNumber: surahNo,
      inputText: entry.inputText,
      fontFamily: testFontFamily,
    );
  }

  Widget headerPage({
    required int surahNo,
    required String name,
    required MushafAppearance appearance,
  }) {
    final colors = appearance.colors;
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
      availableWidth: 360,
      availableHeight: 140,
      fontFamily: null,
      textColor: colors.text,
      headerInkColor: colors.headerInk,
      bismillahText: null,
      surahHeaderNameResolver: (_) => name,
      surahHeaderGlyphResolver: (_) => glyphFor(surahNo),
    );
    return Container(
      color: colors.background,
      width: model.size.width,
      height: model.size.height,
      child: CustomPaint(painter: MushafPagePainter(model)),
    );
  }

  Future<void> expectHeaderGolden(
    WidgetTester tester,
    String goldenName,
    Widget page,
  ) async {
    await tester.pumpWidget(
      MaterialApp(debugShowCheckedModeBanner: false, home: Center(child: page)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CustomPaint).first,
      matchesGoldenFile('goldens/surah_header_monochrome_$goldenName.png'),
    );
  }

  testWidgets('Al-Fatihah, Light theme', (tester) async {
    await expectHeaderGolden(
      tester,
      'al_fatihah_light',
      headerPage(
        surahNo: 1,
        name: 'Al-Fatihah',
        appearance: MushafAppearance.light,
      ),
    );
  });

  testWidgets('Ya-Sin, Dark theme', (tester) async {
    await expectHeaderGolden(
      tester,
      'ya_sin_dark',
      headerPage(
        surahNo: 36,
        name: 'Ya-Sin',
        appearance: MushafAppearance.dark,
      ),
    );
  });

  testWidgets("Al-Ma'idah, Sepia theme", (tester) async {
    await expectHeaderGolden(
      tester,
      'al_maidah_sepia',
      headerPage(
        surahNo: 5,
        name: "Al-Ma'idah",
        appearance: MushafAppearance.sepia,
      ),
    );
  });
}
