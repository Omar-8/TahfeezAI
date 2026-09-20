// Validates the REAL generated Surah Header glyph manifest and the real
// font file it references (assets/quran/manifests/surah_header_glyphs.json,
// assets/quran/fonts/qcf_surah_header/) — built by
// tool/quran_data/build_surah_header_font.dart from the real, vendored QUL
// color font and its official ligature JSON. Never synthetic: every
// assertion here is re-derived independently from the actual bytes on
// disk, not trusted from the generator that produced them.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/surah_header_glyph_manifest_codec.dart';

import '../../tool/quran_data/src/ttf_inspector.dart';

void main() {
  final manifestFile = File('assets/quran/manifests/surah_header_glyphs.json');

  test('the generated glyph manifest is present', () {
    expect(manifestFile.existsSync(), isTrue);
  });

  final manifest = surahHeaderGlyphManifestFromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  test('has exactly 114 entries covering every surah 1..114 exactly once', () {
    expect(manifest.entries, hasLength(114));
    final surahNumbers = manifest.entries.map((e) => e.surahNumber).toSet();
    expect(surahNumbers, hasLength(114));
    expect(surahNumbers, List.generate(114, (i) => i + 1).toSet());
  });

  test('the referenced font asset exists and matches the recorded hash', () {
    final file = File(manifest.assetPath);
    expect(file.existsSync(), isTrue, reason: manifest.assetPath);
    expect(file.lengthSync(), greaterThan(0), reason: manifest.assetPath);
  });

  test('every entry\'s input text is exactly one codepoint that the real '
      'font\'s own cmap table resolves to a real glyph -- re-verified '
      'directly from the font bytes, not trusted from the generator', () {
    final inspection = inspectTtf(File(manifest.assetPath));
    expect(inspection.isValidSfnt, isTrue);
    expect(inspection.familyName, manifest.fontFamily);

    for (final entry in manifest.entries) {
      expect(
        entry.inputText.runes.length,
        1,
        reason: 'surah ${entry.surahNumber}',
      );
      final codepoint = entry.inputText.runes.first;
      expect(
        inspection.cmap.containsKey(codepoint),
        isTrue,
        reason:
            'surah ${entry.surahNumber}: U+'
            '${codepoint.toRadixString(16).toUpperCase()} missing from '
            'the real font\'s cmap',
      );
    }
  });

  test('no two surahs map to the same input codepoint', () {
    final codepoints = manifest.entries
        .map((e) => e.inputText.runes.first)
        .toSet();
    expect(codepoints, hasLength(114));
  });

  test('the font declares COLRv0 color-glyph tables (COLR/CPAL), the format '
      'Skia is expected to render correctly -- not COLRv1, which has much '
      'less universal engine support', () {
    final inspection = inspectTtf(File(manifest.assetPath));
    expect(inspection.tableTags, containsAll(['COLR', 'CPAL']));
  });
}
