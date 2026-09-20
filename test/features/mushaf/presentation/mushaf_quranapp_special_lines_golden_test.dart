// Visual spot-checks for the QuranApp-style special-line rendering, using
// the app's own real per-theme colors (MushafAppearanceColors.headerInk/
// text) and the real vendored quran_common.ttf/suracon.ttf fonts -- a
// representative subset (not the full 10-surah x 5-theme matrix) alongside
// the rigorous, non-visual pixel/geometry proofs in
// mushaf_quranapp_special_lines_real_font_test.dart, which does cover all
// 10 named surahs.
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
import 'package:tahfeez_ai/quran/data/quranapp_special_font_manifest_codec.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';

const testCommonFamily = 'quran_common_GOLDEN_TEST';
const testSuraconFamily = 'suracon_GOLDEN_TEST';
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
const realBismillahText = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ';

void main() {
  final commonManifestFile = File(
    'assets/quran/manifests/quran_common_font.json',
  );
  final suraconManifestFile = File(
    'assets/quran/manifests/suracon_glyphs.json',
  );
  if (!commonManifestFile.existsSync() || !suraconManifestFile.existsSync()) {
    return; // honest skip, same as other real-font tests
  }

  final commonManifest = quranCommonFontManifestFromJson(
    jsonDecode(commonManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final suraconManifest = suraconGlyphManifestFromJson(
    jsonDecode(suraconManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  setUpAll(() async {
    for (final (family, assetPath) in [
      (testCommonFamily, commonManifest.assetPath),
      (testSuraconFamily, suraconManifest.assetPath),
    ]) {
      final bytes = File(assetPath).readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
  });

  String suraconInputTextFor(int surahNo) {
    final entry = suraconManifest.entries.firstWhere(
      (e) => e.surahNumber == surahNo,
    );
    return entry.inputText + suraconManifest.prefixInputText;
  }

  Widget specialLinesPage({
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
        const MushafLine(
          mushafId: 1,
          pageNumber: 1,
          lineNumber: 2,
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
      availableWidth: 360,
      availableHeight: 220,
      fontFamily: null,
      textColor: colors.text,
      headerInkColor: colors.headerInk,
      bismillahText: realBismillahText,
      surahHeaderNameResolver: (_) => name,
      quranCommonFontFamily: testCommonFamily,
      suraconFontFamily: testSuraconFamily,
      suraconInputTextResolver: suraconInputTextFor,
    );
    return Container(
      color: colors.background,
      width: model.size.width,
      height: model.size.height,
      child: CustomPaint(painter: MushafPagePainter(model)),
    );
  }

  Future<void> expectGolden(
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
      matchesGoldenFile('goldens/quranapp_special_lines_$goldenName.png'),
    );
  }

  testWidgets('Al-Fatihah, Light theme', (tester) async {
    await expectGolden(
      tester,
      'al_fatihah_light',
      specialLinesPage(
        surahNo: 1,
        name: 'Al-Fatihah',
        appearance: MushafAppearance.light,
      ),
    );
  });

  testWidgets('Ya-Sin, Dark theme', (tester) async {
    await expectGolden(
      tester,
      'ya_sin_dark',
      specialLinesPage(
        surahNo: 36,
        name: 'Ya-Sin',
        appearance: MushafAppearance.dark,
      ),
    );
  });

  testWidgets("Al-Ma'idah, Sepia theme", (tester) async {
    await expectGolden(
      tester,
      'al_maidah_sepia',
      specialLinesPage(
        surahNo: 5,
        name: "Al-Ma'idah",
        appearance: MushafAppearance.sepia,
      ),
    );
  });

  testWidgets('An-Nas, Black theme', (tester) async {
    await expectGolden(
      tester,
      'an_nas_black',
      specialLinesPage(
        surahNo: 114,
        name: 'An-Nas',
        appearance: MushafAppearance.black,
      ),
    );
  });

  testWidgets('Ar-Rahman, Warm theme', (tester) async {
    await expectGolden(
      tester,
      'ar_rahman_warm',
      specialLinesPage(
        surahNo: 55,
        name: 'Ar-Rahman',
        appearance: MushafAppearance.warm,
      ),
    );
  });
}
