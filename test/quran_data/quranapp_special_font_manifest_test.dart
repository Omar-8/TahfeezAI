// Validates the REAL generated quran_common.ttf/suracon.ttf manifests and
// the real font files they reference (assets/quran/manifests/
// quran_common_font.json, suracon_glyphs.json,
// assets/quran/fonts/quranapp/) — built by
// tool/quran_data/build_quranapp_special_fonts.dart from the real fonts
// vendored from a local AlfaazPlus/QuranApp checkout. Never synthetic:
// every assertion here is re-derived independently from the actual bytes
// on disk, not trusted from the generator that produced them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/quranapp_special_font_manifest_codec.dart';

import '../../tool/quran_data/src/ttf_inspector.dart';

void main() {
  final commonManifestFile = File(
    'assets/quran/manifests/quran_common_font.json',
  );
  final suraconManifestFile = File(
    'assets/quran/manifests/suracon_glyphs.json',
  );

  test('the generated manifests are present', () {
    expect(commonManifestFile.existsSync(), isTrue);
    expect(suraconManifestFile.existsSync(), isTrue);
  });

  final commonManifest = quranCommonFontManifestFromJson(
    jsonDecode(commonManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );
  final suraconManifest = suraconGlyphManifestFromJson(
    jsonDecode(suraconManifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  test('quran_common.ttf is a valid font whose real cmap resolves both '
      'U+E000 (title frame) and U+FDFD (Bismillah) -- re-verified directly '
      'from the font bytes, not trusted from the generator', () {
    final file = File(commonManifest.assetPath);
    expect(file.existsSync(), isTrue);
    final inspection = inspectTtf(file);
    expect(inspection.isValidSfnt, isTrue);
    expect(inspection.familyName, commonManifest.fontFamily);
    expect(inspection.cmap.containsKey(0xE000), isTrue);
    expect(inspection.cmap.containsKey(0xFDFD), isTrue);
  });

  test('suracon.ttf has exactly 114 verified surah glyph entries plus a '
      'verified prefix glyph, covering every surah 1..114 exactly once', () {
    expect(suraconManifest.entries, hasLength(114));
    final surahNumbers = suraconManifest.entries
        .map((e) => e.surahNumber)
        .toSet();
    expect(surahNumbers, hasLength(114));
    expect(surahNumbers, List.generate(114, (i) => i + 1).toSet());

    final file = File(suraconManifest.assetPath);
    final inspection = inspectTtf(file);
    expect(inspection.isValidSfnt, isTrue);
    expect(inspection.familyName, suraconManifest.fontFamily);

    expect(suraconManifest.prefixInputText.runes.length, 1);
    expect(
      inspection.cmap.containsKey(suraconManifest.prefixInputText.runes.first),
      isTrue,
      reason: 'prefix glyph must resolve in the real font cmap',
    );
    for (final entry in suraconManifest.entries) {
      expect(
        entry.inputText.runes.length,
        1,
        reason: 'surah ${entry.surahNumber}',
      );
      expect(
        inspection.cmap.containsKey(entry.inputText.runes.first),
        isTrue,
        reason: 'surah ${entry.surahNumber} must resolve in the real font cmap',
      );
    }

    // No two surahs (or the prefix) collide on the same codepoint.
    final allCodepoints = {
      suraconManifest.prefixInputText.runes.first,
      for (final e in suraconManifest.entries) e.inputText.runes.first,
    };
    expect(allCodepoints, hasLength(115));
  });

  test('neither font declares COLR/CPAL color tables -- both are ordinary '
      'outline fonts, confirming no saveLayer/ColorFilter is needed to '
      'render them monochrome (unlike the unused QUL color font)', () {
    final commonInspection = inspectTtf(File(commonManifest.assetPath));
    final suraconInspection = inspectTtf(File(suraconManifest.assetPath));
    expect(commonInspection.tableTags.contains('COLR'), isFalse);
    expect(commonInspection.tableTags.contains('CPAL'), isFalse);
    expect(suraconInspection.tableTags.contains('COLR'), isFalse);
    expect(suraconInspection.tableTags.contains('CPAL'), isFalse);
  });
}
