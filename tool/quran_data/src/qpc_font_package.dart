// Verifies and repackages the real, vendored QPC V2 font package (604
// page-specific TTFs) into Flutter assets plus a generated,
// verified-not-assumed page->font manifest. Never renames, merges,
// subsets, re-encodes, or otherwise modifies a single font file — every
// byte copied into assets/quran/fonts/qpc_v2/ is identical to the upstream
// file. See docs/QURAN_DATA_PROVENANCE.md §8.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:tahfeez_ai/quran/domain/models/page_font_manifest_models.dart';

import 'ttf_inspector.dart';

class QpcFontPackageResult {
  const QpcFontPackageResult({required this.manifest, required this.issues});

  final PageFontManifest manifest;

  /// Non-empty means something about the real package did not match
  /// expectations (e.g. an embedded family name that disagrees with the
  /// filename's page number) — reported, never silently guessed past.
  final List<String> issues;
}

/// Reads every `pN.ttf` file from [extractedFontsDir] (the real, unmodified
/// QUL QPC V2 font package, already extracted from its zip — see
/// [extractQpcFontPackage]), verifies each one's embedded family name
/// against its filename's page number, copies the unmodified bytes to
/// [outputFontsDir], and returns a [PageFontManifest] describing the
/// result — built entirely from what the real files actually contain, not
/// from filename arithmetic assumed correct.
QpcFontPackageResult buildQpcFontPackage({
  required Directory extractedFontsDir,
  required String fontPackageSource,
  required String fontPackageHash,
  required Directory outputFontsDir,
  required int mushafId,
}) {
  outputFontsDir.createSync(recursive: true);

  final issues = <String>[];
  final entries = <PageFontManifestEntry>[];
  final seenPages = <int>{};
  final pageFilePattern = RegExp(r'^p(\d+)\.ttf$');

  for (final entity in extractedFontsDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final match = pageFilePattern.firstMatch(name);
    if (match == null) {
      issues.add('Unexpected entry in font package: $name');
      continue;
    }
    final pageNumber = int.parse(match.group(1)!);
    final bytes = entity.readAsBytesSync();

    if (!seenPages.add(pageNumber)) {
      issues.add('Duplicate page $pageNumber in font package ($name).');
      continue;
    }

    final outFile = File('${outputFontsDir.path}/p$pageNumber.ttf');
    outFile.writeAsBytesSync(bytes);

    final inspection = inspectTtf(outFile);
    if (!inspection.isValidSfnt) {
      issues.add('Page $pageNumber ($name) is not a valid TTF/OTF file.');
      continue;
    }
    final family = inspection.familyName;
    if (family == null) {
      issues.add('Page $pageNumber ($name) has no readable family name.');
      continue;
    }
    final expectedFamily = 'QCF2${pageNumber.toString().padLeft(3, '0')}';
    if (family != expectedFamily) {
      issues.add(
        'Page $pageNumber ($name): embedded family "$family" does '
        'not match the expected "$expectedFamily" for this page number — '
        'not trusting filename-to-page arithmetic blindly.',
      );
      continue;
    }

    entries.add(
      PageFontManifestEntry(
        mushafId: mushafId,
        pageNumber: pageNumber,
        assetPath: 'assets/quran/fonts/qpc_v2/p$pageNumber.ttf',
        fontFamily: family,
        sourceFile: name,
        fileHash: sha256.convert(bytes).toString(),
        fileSize: bytes.length,
      ),
    );
  }

  for (var page = 1; page <= 604; page++) {
    if (!seenPages.contains(page)) {
      issues.add('Page $page is missing from the font package entirely.');
    }
  }
  if (entries.length != 604) {
    issues.add(
      'Expected exactly 604 verified page fonts, got ${entries.length}.',
    );
  }

  entries.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

  final manifest = PageFontManifest(
    schemaVersion: 1,
    mushafId: mushafId,
    fontPackageSource: fontPackageSource,
    fontPackageHash: fontPackageHash,
    generatedAt: DateTime.now().toUtc(),
    entries: entries,
  );

  return QpcFontPackageResult(manifest: manifest, issues: issues);
}

/// Extracts [fontPackageZip] (the real "QPC V2 Font.ttf.bz2", actually a
/// zip — see docs/QURAN_DATA_PROVENANCE.md §8) into [destDir], returning
/// the zip's own SHA-256 for provenance.
String extractQpcFontPackage(File fontPackageZip, Directory destDir) {
  destDir.createSync(recursive: true);
  final result = Process.runSync('unzip', [
    '-o',
    fontPackageZip.path,
    '-d',
    destDir.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to extract ${fontPackageZip.path}: ${result.stderr}',
    );
  }
  return sha256.convert(fontPackageZip.readAsBytesSync()).toString();
}

Map<String, dynamic> pageFontManifestToJson(PageFontManifest m) => {
  'schemaVersion': m.schemaVersion,
  'mushafId': m.mushafId,
  'fontPackageSource': m.fontPackageSource,
  'fontPackageHash': m.fontPackageHash,
  'generatedAt': m.generatedAt.toIso8601String(),
  'entries': m.entries
      .map(
        (e) => {
          'mushafId': e.mushafId,
          'pageNumber': e.pageNumber,
          'assetPath': e.assetPath,
          'fontFamily': e.fontFamily,
          'sourceFile': e.sourceFile,
          'fileHash': e.fileHash,
          'fileSize': e.fileSize,
        },
      )
      .toList(),
};

String writePageFontManifest(PageFontManifest manifest, File outFile) {
  final bytes = utf8.encode(
    const JsonEncoder.withIndent('  ')
        .convert(pageFontManifestToJson(manifest)),
  );
  outFile.parent.createSync(recursive: true);
  outFile.writeAsBytesSync(bytes);
  return sha256.convert(bytes).toString();
}
