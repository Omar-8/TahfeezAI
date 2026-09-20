// Real Flutter/Skia regression for the Mushaf text-boldness feature: the
// REAL QCF V2 page fonts, REAL page data (assets/quran/mushaf/
// kfgqpc_v2.json), and the REAL production `buildMushafPageRenderModel`/
// `MushafPagePainter` pipeline (never a hand-rolled reimplementation) at
// all three shipped presets (Light 0.25 / Medium 0.30 / Bold 0.40), on the
// same representative pages the original stroke-width investigation used:
//   - page 42 (Ayat al-Kursi region -- dense diacritics, an ayah marker)
//   - page 106 (a Surah transition -- An-Nisa -> Al-Ma'idah)
//   - page 604 (the Mushaf's final page -- short lines, An-Nas)
//
// Two things are checked:
//   1. Numerically: line geometry (shaped width/height, paint offset,
//      token hit-rects) is byte-identical across Light/Medium/Bold for
//      every quranText line on all three pages -- the boldness preference
//      is a pure paint-layer change, never a layout one.
//   2. Visually: real renders at all three presets, both a 4x-zoomed
//      side-by-side comparison (to judge fine diacritic/mark cleanliness)
//      and one real, un-zoomed phone-width capture per preset (to catch
//      any gross clipping/reflow that only a realistic viewport would
//      reveal).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_page_layout_engine.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_text_boldness.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_painter.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_render_model.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/text_painter_word_measurer.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';

const _availableWidth = 340.0;
const _pages = [42, 106, 604];

void main() {
  final datasetFile = File('assets/quran/mushaf/kfgqpc_v2.json');
  if (!datasetFile.existsSync()) {
    // Honest skip: the real, license-gated Mushaf dataset isn't present in
    // this environment (never committed to git) -- same convention as
    // every other real-Mushaf-data test in this suite.
    return;
  }

  final raw =
      jsonDecode(datasetFile.readAsStringSync()) as Map<String, dynamic>;
  final allLines = (raw['mushafLines'] as List)
      .cast<Map<String, dynamic>>()
      .map(mushafLineFromJson)
      .toList();
  final allTokens = (raw['mushafTokens'] as List)
      .cast<Map<String, dynamic>>()
      .map(mushafTokenFromJson)
      .toList();

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
  const engine = MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());

  final loadedFamilies = <int, String>{};
  Future<String> loadPageFont(int page) async {
    final cached = loadedFamilies[page];
    if (cached != null) return cached;
    final family = 'QCF2${page}_BOLDNESS_TEST';
    final bytes = File('assets/quran/fonts/qpc_v2/p$page.ttf')
        .readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    loadedFamilies[page] = family;
    return family;
  }

  MushafPageBundle bundleForPage(int page) {
    final lines = allLines.where((l) => l.pageNumber == page).toList();
    final tokensByLine = <int, List<MushafToken>>{
      for (final line in lines)
        line.lineNumber: line.firstTokenId == null
            ? const []
            : allTokens
                  .where(
                    (t) =>
                        t.sourceTokenId >= line.firstTokenId! &&
                        t.sourceTokenId <= line.lastTokenId!,
                  )
                  .toList(),
    };
    return MushafPageBundle(
      mushaf: mushaf,
      pageNumber: page,
      lines: lines,
      tokensByLineNumber: tokensByLine,
      juzNo: null,
      hizbNos: const [],
    );
  }

  MushafPageRenderModel renderPage(
    int page,
    String family, {
    required double strokeWidth,
    double availableHeight = 600,
  }) {
    return buildMushafPageRenderModel(
      engine: engine,
      bundle: bundleForPage(page),
      availableWidth: _availableWidth,
      availableHeight: availableHeight,
      fontFamily: family,
      textColor: Colors.black,
      headerInkColor: Colors.black,
      bismillahText: null,
      surahHeaderNameResolver: (_) => null,
      quranTextStrokeWidth: strokeWidth,
    );
  }

  group('layout invariance across Light/Medium/Bold (real pages)', () {
    for (final page in _pages) {
      test(
        'page $page: geometry is identical across all three presets',
        () async {
          final family = await loadPageFont(page);
          final light = renderPage(
            page,
            family,
            strokeWidth: strokeWidthForMushafBoldness(MushafTextBoldness.light),
          );
          final medium = renderPage(
            page,
            family,
            strokeWidth: strokeWidthForMushafBoldness(
              MushafTextBoldness.medium,
            ),
          );
          final bold = renderPage(
            page,
            family,
            strokeWidth: strokeWidthForMushafBoldness(MushafTextBoldness.bold),
          );

          expect(medium.lines.length, light.lines.length);
          expect(bold.lines.length, light.lines.length);

          for (var i = 0; i < light.lines.length; i++) {
            final lightLine = light.lines[i];
            final mediumLine = medium.lines[i];
            final boldLine = bold.lines[i];
            if (lightLine is! MushafQuranTextLineRenderModel) continue;
            mediumLine as MushafQuranTextLineRenderModel;
            boldLine as MushafQuranTextLineRenderModel;

            for (final other in [mediumLine, boldLine]) {
              expect(other.top, lightLine.top, reason: 'page $page line $i');
              expect(
                other.height,
                lightLine.height,
                reason: 'page $page line $i',
              );
              expect(
                other.paintOffset,
                lightLine.paintOffset,
                reason: 'page $page line $i',
              );
              if (lightLine.painter == null) {
                expect(other.painter, isNull, reason: 'page $page line $i');
                continue;
              }
              expect(
                other.painter!.width,
                lightLine.painter!.width,
                reason: 'page $page line $i',
              );
              expect(
                other.painter!.height,
                lightLine.painter!.height,
                reason: 'page $page line $i',
              );
              expect(
                other.tokenRects.length,
                lightLine.tokenRects.length,
                reason: 'page $page line $i',
              );
              for (var t = 0; t < lightLine.tokenRects.length; t++) {
                expect(
                  other.tokenRects[t].rect,
                  lightLine.tokenRects[t].rect,
                  reason: 'page $page line $i token $t',
                );
              }
              // No clipping: the shaped line never exceeds the page's own
              // available width, at any of the three presets.
              expect(
                other.painter!.width,
                lessThanOrEqualTo(_availableWidth + 0.5),
                reason: 'page $page line $i',
              );
            }
          }
        },
      );
    }
  });

  testWidgets(
    '4x-zoomed visual comparison across Light/Medium/Bold for all three '
    'representative pages -- inspect for clean diacritics/marks',
    (tester) async {
      const zoom = 4.0;
      final blocks = <Widget>[];

      for (final page in _pages) {
        final family = await loadPageFont(page);
        final row = <Widget>[
          Text(
            'Page $page',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ];
        for (final boldness in MushafTextBoldness.values) {
          final model = renderPage(
            page,
            family,
            strokeWidth: strokeWidthForMushafBoldness(boldness),
            availableHeight: 15 * 40.0,
          );
          row.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${boldness.label} (stroke '
                    '${strokeWidthForMushafBoldness(boldness)})',
                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                  SizedBox(
                    width: model.size.width * zoom,
                    height: model.size.height * zoom,
                    child: Transform.scale(
                      scale: zoom,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: model.size.width,
                        height: model.size.height,
                        child: RepaintBoundary(
                          child: CustomPaint(painter: MushafPagePainter(model)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        blocks.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: row,
            ),
          ),
        );
      }

      await tester.binding.setSurfaceSize(const Size(1500, 13000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: blocks,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/mushaf_text_boldness_zoomed_comparison.png'),
      );
    },
  );

  testWidgets(
    'a real, un-zoomed phone-width render at each preset shows no gross '
    'clipping/reflow/glyph-fallback',
    (tester) async {
      final family = await loadPageFont(42);

      for (final boldness in MushafTextBoldness.values) {
        final model = renderPage(
          42,
          family,
          strokeWidth: strokeWidthForMushafBoldness(boldness),
          availableHeight: 700,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: SizedBox(
                width: _availableWidth,
                height: 700,
                child: CustomPaint(painter: MushafPagePainter(model)),
              ),
            ),
          ),
        );
        await tester.pump();

        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/mushaf_text_boldness_phone_${boldness.name}.png',
          ),
        );
      }
    },
  );
}
