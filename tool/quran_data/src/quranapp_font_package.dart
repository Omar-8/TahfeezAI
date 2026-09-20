// Verifies the real, vendored quran_common.ttf/suracon.ttf fonts (from a
// local AlfaazPlus/QuranApp checkout, docs/QURAN_DATA_PROVENANCE.md
// §12/§13) and repackages them into Flutter assets plus generated,
// verified manifests. Never renames, subsets, re-encodes, or otherwise
// modifies a font file; never invents a glyph mapping — every codepoint
// this records is checked against the real file's own `cmap` table.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:tahfeez_ai/quran/domain/models/quranapp_special_font_models.dart';

import 'ttf_inspector.dart';

/// QuranApp's own Surah-glyph codepoint table
/// (`utils/quran/QuranGlyphs.kt`'s `Chapter.icons`, index 0 = the shared
/// prefix glyph, 1..114 = each Surah's calligraphic name) — recorded here
/// as the factual codepoint data needed to address `suracon.ttf`'s glyphs
/// (the same kind of "character map" data a font's own cmap or a keyboard
/// layout table is), not as copied Kotlin logic. Every value is
/// independently re-verified against the real vendored font's own `cmap`
/// by [buildSuraconGlyphManifest] before being trusted — a mismatch fails
/// the build rather than silently shipping.
const quranAppSuraconCodepoints = <int>[
  0xE903, // prefix
  0xE904, 0xE905, 0xE906, 0xE907, 0xE908, 0xE90B, 0xE90C, 0xE90D, 0xE90E,
  0xE90F, 0xE910, 0xE911, 0xE912, 0xE913, 0xE914, 0xE915, 0xE916, 0xE917,
  0xE918, 0xE919, 0xE91A, 0xE91B, 0xE91C, 0xE91D, 0xE91E, 0xE91F, 0xE920,
  0xE921, 0xE922, 0xE923, 0xE924, 0xE925, 0xE926, 0xE92E, 0xE92F, 0xE930,
  0xE931, 0xE909, 0xE90A, 0xE927, 0xE928, 0xE929, 0xE92A, 0xE92B, 0xE92C,
  0xE92D, 0xE932, 0xE902, 0xE933, 0xE934, 0xE935, 0xE936, 0xE937, 0xE938,
  0xE939, 0xE93A, 0xE93B, 0xE93C, 0xE900, 0xE901, 0xE941, 0xE942, 0xE943,
  0xE944, 0xE945, 0xE946, 0xE947, 0xE948, 0xE949, 0xE94A, 0xE94B, 0xE94C,
  0xE94D, 0xE94E, 0xE94F, 0xE950, 0xE951, 0xE952, 0xE93D, 0xE93E, 0xE93F,
  0xE940, 0xE953, 0xE954, 0xE955, 0xE956, 0xE957, 0xE958, 0xE959, 0xE95A,
  0xE95B, 0xE95C, 0xE95D, 0xE95E, 0xE95F, 0xE960, 0xE961, 0xE962, 0xE963,
  0xE964, 0xE965, 0xE966, 0xE967, 0xE968, 0xE969, 0xE96A, 0xE96B, 0xE96C,
  0xE96D, 0xE96E, 0xE96F, 0xE970, 0xE971, 0xE972,
];

/// The two fixed, pre-verified `quran_common.ttf` codepoints this project
/// actually uses (QuranApp's `QuranGlyphs.Special.TITLE_FRAME`/`BISMILLAH`)
/// — verified present in the real font's cmap, never assumed.
const quranCommonTitleFrameCodepoint = 0xE000;
const quranCommonBismillahCodepoint = 0xFDFD;

class QuranAppFontPackageResult<T> {
  const QuranAppFontPackageResult({this.manifest, required this.issues});
  final T? manifest;
  final List<String> issues;
}

QuranAppFontPackageResult<QuranCommonFontManifest>
buildQuranCommonFontManifest({
  required File fontFile,
  required String fontSource,
  required File outputFontFile,
}) {
  final issues = <String>[];
  final bytes = fontFile.readAsBytesSync();
  outputFontFile.parent.createSync(recursive: true);
  outputFontFile.writeAsBytesSync(bytes);

  final inspection = inspectTtf(outputFontFile);
  if (!inspection.isValidSfnt) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} is not a valid TTF/OTF file.'],
    );
  }
  final family = inspection.familyName;
  if (family == null) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} has no readable embedded family name.'],
    );
  }
  if (!inspection.cmap.containsKey(quranCommonTitleFrameCodepoint)) {
    issues.add(
      'U+${quranCommonTitleFrameCodepoint.toRadixString(16).toUpperCase()} '
      '(title frame) is not present in ${fontFile.path}\'s cmap.',
    );
  }
  if (!inspection.cmap.containsKey(quranCommonBismillahCodepoint)) {
    issues.add(
      'U+${quranCommonBismillahCodepoint.toRadixString(16).toUpperCase()} '
      '(Bismillah) is not present in ${fontFile.path}\'s cmap.',
    );
  }
  if (issues.isNotEmpty) {
    return QuranAppFontPackageResult(issues: issues);
  }

  return QuranAppFontPackageResult(
    manifest: QuranCommonFontManifest(
      schemaVersion: 1,
      assetPath:
          'assets/quran/fonts/quranapp/${outputFontFile.uri.pathSegments.last}',
      fontFamily: family,
      fontSource: fontSource,
      fontHash: sha256.convert(bytes).toString(),
      generatedAt: DateTime.now().toUtc(),
    ),
    issues: const [],
  );
}

/// Verifies a plain Unicode Quran-text font (no special codepoints to
/// check — unlike [buildQuranCommonFontManifest]/`buildSuraconGlyphManifest`,
/// this font is meant to render ordinary canonical Arabic text, not a
/// fixed set of private-use glyphs) and packages it the same way. Reuses
/// [QuranCommonFontManifest]'s shape (family/asset path/hash/source) since
/// that's all a plain text font's manifest needs.
QuranAppFontPackageResult<QuranCommonFontManifest> buildQuranTextFontManifest({
  required File fontFile,
  required String fontSource,
  required File outputFontFile,
  required String outputAssetDir,
}) {
  final bytes = fontFile.readAsBytesSync();
  outputFontFile.parent.createSync(recursive: true);
  outputFontFile.writeAsBytesSync(bytes);

  final inspection = inspectTtf(outputFontFile);
  if (!inspection.isValidSfnt) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} is not a valid TTF/OTF file.'],
    );
  }
  final family = inspection.familyName;
  if (family == null) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} has no readable embedded family name.'],
    );
  }

  return QuranAppFontPackageResult(
    manifest: QuranCommonFontManifest(
      schemaVersion: 1,
      assetPath: '$outputAssetDir/${outputFontFile.uri.pathSegments.last}',
      fontFamily: family,
      fontSource: fontSource,
      fontHash: sha256.convert(bytes).toString(),
      generatedAt: DateTime.now().toUtc(),
    ),
    issues: const [],
  );
}

QuranAppFontPackageResult<SuraconGlyphManifest> buildSuraconGlyphManifest({
  required File fontFile,
  required String fontSource,
  required File outputFontFile,
}) {
  final issues = <String>[];
  final bytes = fontFile.readAsBytesSync();
  outputFontFile.parent.createSync(recursive: true);
  outputFontFile.writeAsBytesSync(bytes);

  final inspection = inspectTtf(outputFontFile);
  if (!inspection.isValidSfnt) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} is not a valid TTF/OTF file.'],
    );
  }
  final family = inspection.familyName;
  if (family == null) {
    return QuranAppFontPackageResult(
      issues: ['${fontFile.path} has no readable embedded family name.'],
    );
  }

  if (quranAppSuraconCodepoints.length != 115) {
    issues.add(
      'Expected 115 codepoints (1 prefix + 114 surahs), got '
      '${quranAppSuraconCodepoints.length}.',
    );
    return QuranAppFontPackageResult(issues: issues);
  }

  final prefixCodepoint = quranAppSuraconCodepoints[0];
  if (!inspection.cmap.containsKey(prefixCodepoint)) {
    issues.add(
      'Prefix codepoint U+${prefixCodepoint.toRadixString(16).toUpperCase()} '
      'is not present in ${fontFile.path}\'s cmap.',
    );
  }

  final entries = <SuraconGlyphEntry>[];
  for (var surahNo = 1; surahNo <= 114; surahNo++) {
    final codepoint = quranAppSuraconCodepoints[surahNo];
    if (!inspection.cmap.containsKey(codepoint)) {
      issues.add(
        'Surah $surahNo: U+${codepoint.toRadixString(16).toUpperCase()} is '
        'not present in ${fontFile.path}\'s cmap.',
      );
      continue;
    }
    entries.add(
      SuraconGlyphEntry(
        surahNumber: surahNo,
        inputText: String.fromCharCode(codepoint),
      ),
    );
  }

  if (entries.length != 114) {
    issues.add(
      'Expected exactly 114 verified surah glyphs, got ${entries.length}.',
    );
  }
  if (issues.isNotEmpty) {
    return QuranAppFontPackageResult(issues: issues);
  }

  return QuranAppFontPackageResult(
    manifest: SuraconGlyphManifest(
      schemaVersion: 1,
      assetPath:
          'assets/quran/fonts/quranapp/${outputFontFile.uri.pathSegments.last}',
      fontFamily: family,
      fontSource: fontSource,
      fontHash: sha256.convert(bytes).toString(),
      prefixInputText: String.fromCharCode(prefixCodepoint),
      generatedAt: DateTime.now().toUtc(),
      entries: entries,
    ),
    issues: const [],
  );
}

Map<String, dynamic> quranCommonFontManifestToJson(QuranCommonFontManifest m) =>
    {
      'schemaVersion': m.schemaVersion,
      'assetPath': m.assetPath,
      'fontFamily': m.fontFamily,
      'fontSource': m.fontSource,
      'fontHash': m.fontHash,
      'generatedAt': m.generatedAt.toIso8601String(),
    };

Map<String, dynamic> suraconGlyphManifestToJson(SuraconGlyphManifest m) => {
  'schemaVersion': m.schemaVersion,
  'assetPath': m.assetPath,
  'fontFamily': m.fontFamily,
  'fontSource': m.fontSource,
  'fontHash': m.fontHash,
  'prefixInputText': m.prefixInputText,
  'generatedAt': m.generatedAt.toIso8601String(),
  'entries': m.entries
      .map((e) => {'surahNumber': e.surahNumber, 'inputText': e.inputText})
      .toList(),
};

String writeJsonManifest(Map<String, dynamic> json, File outFile) {
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(json));
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes);
  return sha256.convert(bytes).toString();
}
