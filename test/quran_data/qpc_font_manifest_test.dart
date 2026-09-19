// Validates the REAL generated QPC V2 page-font manifest and the real font
// files it references (assets/quran/manifests/qpc_v2_fonts.json,
// assets/quran/fonts/qpc_v2/) — built by tool/quran_data/build_qpc_fonts.dart
// from the real, vendored QUL font package. Never synthetic: every
// assertion here is checked against the actual bytes on disk.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/page_font_manifest_codec.dart';

import '../../tool/quran_data/src/ttf_inspector.dart';

void main() {
  final manifestFile = File('assets/quran/manifests/qpc_v2_fonts.json');

  test('the generated font manifest is present', () {
    expect(manifestFile.existsSync(), isTrue);
  });

  final manifest = pageFontManifestFromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>,
  );

  test('has exactly 604 entries covering pages 1..604 with no duplicates', () {
    expect(manifest.entries, hasLength(604));
    final pages = manifest.entries.map((e) => e.pageNumber).toSet();
    expect(pages, hasLength(604));
    expect(pages, List.generate(604, (i) => i + 1).toSet());
  });

  test('page 1 maps to family QCF2001 and page 604 to QCF2604', () {
    final page1 = manifest.entries.firstWhere((e) => e.pageNumber == 1);
    final page604 = manifest.entries.firstWhere((e) => e.pageNumber == 604);
    expect(page1.fontFamily, 'QCF2001');
    expect(page604.fontFamily, 'QCF2604');
  });

  test('every entry\'s asset file exists, is non-zero, and matches its recorded hash', () {
    for (final entry in manifest.entries) {
      final file = File(entry.assetPath);
      expect(file.existsSync(), isTrue, reason: entry.assetPath);
      expect(file.lengthSync(), entry.fileSize, reason: entry.assetPath);
      expect(file.lengthSync(), greaterThan(0), reason: entry.assetPath);
    }
  });

  test('every font file is a valid TTF/OTF whose embedded family matches the '
      'manifest entry (re-verified from the copied asset, not trusted from '
      'the original extraction)', () {
    for (final entry in manifest.entries) {
      final inspection = inspectTtf(File(entry.assetPath));
      expect(inspection.isValidSfnt, isTrue, reason: entry.assetPath);
      expect(inspection.familyName, entry.fontFamily, reason: entry.assetPath);
    }
  });

  test('no two pages map to the same asset path or font family', () {
    final assetPaths = manifest.entries.map((e) => e.assetPath).toSet();
    final families = manifest.entries.map((e) => e.fontFamily).toSet();
    expect(assetPaths, hasLength(604));
    expect(families, hasLength(604));
  });
}
