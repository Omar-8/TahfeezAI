// Verifies the real, vendored QUL Surah Header color font and its official
// ligature/JSON mapping, then repackages them into a Flutter asset plus a
// generated, verified surahNumber->glyph manifest. Never renames, subsets,
// re-encodes, or otherwise modifies the font file; never invents a glyph
// mapping — every entry traces back to QUL's own ligature JSON, checked
// against the font's real `cmap` table. See docs/QURAN_DATA_PROVENANCE.md.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:tahfeez_ai/quran/domain/models/surah_header_glyph_models.dart';

import 'ttf_inspector.dart';

class SurahHeaderFontPackageResult {
  const SurahHeaderFontPackageResult({
    required this.manifest,
    required this.issues,
  });

  final SurahHeaderGlyphManifest? manifest;

  /// Non-empty means something about the real font or ligature mapping did
  /// not match expectations — reported, never silently guessed past. A
  /// non-empty list means [manifest] is `null`: an incomplete or
  /// unverifiable mapping is never shipped partially.
  final List<String> issues;
}

/// Verifies [fontFile] (the real, unmodified QUL Surah Header font) against
/// [ligatureJson] (QUL's own official surah-N -> glyph-string mapping),
/// requiring all 114 Surah numbers to be present, each mapping to exactly
/// one Unicode codepoint that the font's own `cmap` table actually
/// resolves to a real glyph — never assuming a codepoint scheme (e.g.
/// private-use-area) without checking the real file.
SurahHeaderFontPackageResult buildSurahHeaderFontPackage({
  required File fontFile,
  required String fontSource,
  required File ligatureJsonFile,
  required String ligatureMappingSource,
  required File outputFontFile,
}) {
  final issues = <String>[];
  final fontBytes = fontFile.readAsBytesSync();

  outputFontFile.parent.createSync(recursive: true);
  outputFontFile.writeAsBytesSync(fontBytes);

  final inspection = inspectTtf(outputFontFile);
  if (!inspection.isValidSfnt) {
    return SurahHeaderFontPackageResult(
      manifest: null,
      issues: ['${fontFile.path} is not a valid TTF/OTF file.'],
    );
  }
  final family = inspection.familyName;
  if (family == null) {
    return SurahHeaderFontPackageResult(
      manifest: null,
      issues: ['${fontFile.path} has no readable embedded family name.'],
    );
  }

  final ligatures =
      jsonDecode(ligatureJsonFile.readAsStringSync()) as Map<String, dynamic>;

  final entries = <SurahHeaderGlyphEntry>[];
  for (var surahNo = 1; surahNo <= 114; surahNo++) {
    final key = 'surah-$surahNo';
    final raw = ligatures[key];
    if (raw is! String) {
      issues.add('$key: missing from ${ligatureJsonFile.path}.');
      continue;
    }
    // QUL pads every entry but the last with a trailing space (a layout
    // spacer, not part of the glyph input) — stripped here, never altering
    // the glyph codepoint itself.
    final inputText = raw.trim();
    if (inputText.runes.length != 1) {
      issues.add(
        '$key: expected exactly one Unicode codepoint, got '
        '${inputText.runes.length} (raw: ${jsonEncode(raw)}).',
      );
      continue;
    }
    final codepoint = inputText.runes.first;
    if (!inspection.cmap.containsKey(codepoint)) {
      issues.add(
        '$key: U+${codepoint.toRadixString(16).toUpperCase()} is not '
        'present in ${fontFile.path}\'s cmap table — this font cannot '
        'render this surah\'s header.',
      );
      continue;
    }
    entries.add(
      SurahHeaderGlyphEntry(
        surahNumber: surahNo,
        inputText: inputText,
        fontFamily: family,
      ),
    );
  }

  if (entries.length != 114) {
    issues.add(
      'Expected exactly 114 verified surah header glyphs, got '
      '${entries.length}.',
    );
  }

  if (issues.isNotEmpty) {
    return SurahHeaderFontPackageResult(manifest: null, issues: issues);
  }

  final manifest = SurahHeaderGlyphManifest(
    schemaVersion: 1,
    assetPath:
        'assets/quran/fonts/qcf_surah_header/${outputFontFile.uri.pathSegments.last}',
    fontFamily: family,
    fontSource: fontSource,
    fontHash: sha256.convert(fontBytes).toString(),
    ligatureMappingSource: ligatureMappingSource,
    ligatureMappingHash: sha256
        .convert(ligatureJsonFile.readAsBytesSync())
        .toString(),
    generatedAt: DateTime.now().toUtc(),
    entries: entries,
  );

  return SurahHeaderFontPackageResult(manifest: manifest, issues: const []);
}

Map<String, dynamic> surahHeaderGlyphManifestToJson(
  SurahHeaderGlyphManifest m,
) => {
  'schemaVersion': m.schemaVersion,
  'assetPath': m.assetPath,
  'fontFamily': m.fontFamily,
  'fontSource': m.fontSource,
  'fontHash': m.fontHash,
  'ligatureMappingSource': m.ligatureMappingSource,
  'ligatureMappingHash': m.ligatureMappingHash,
  'generatedAt': m.generatedAt.toIso8601String(),
  'entries': m.entries
      .map(
        (e) => {
          'surahNumber': e.surahNumber,
          'inputText': e.inputText,
          'fontFamily': e.fontFamily,
        },
      )
      .toList(),
};

String writeSurahHeaderGlyphManifest(
  SurahHeaderGlyphManifest manifest,
  File outFile,
) {
  final bytes = utf8.encode(
    const JsonEncoder.withIndent('  ')
        .convert(surahHeaderGlyphManifestToJson(manifest)),
  );
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes);
  return sha256.convert(bytes).toString();
}
