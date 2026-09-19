// Verifies the real, vendored QPC V2 font package (604 page-specific TTFs)
// and repackages it into Flutter assets plus a generated, verified page->
// font manifest:
//
//   assets/quran/fonts/qpc_v2/p1.ttf .. p604.ttf   (unmodified font bytes)
//   assets/quran/manifests/qpc_v2_fonts.json       (generated manifest)
//
// Never renames, merges, subsets, re-encodes, or otherwise modifies a font
// file. Fails loudly (non-zero exit) if any page is missing, duplicated, or
// has an embedded family name that disagrees with its expected page
// number — see docs/QURAN_DATA_PROVENANCE.md §8.
//
// Run with: dart run tool/quran_data/build_qpc_fonts.dart
import 'dart:io';

import 'src/qpc_font_package.dart';

const _mushafId = 1;
const _sourceZip = 'tool/quran_data/sources/QPC V2 Font.ttf.bz2';
const _cache = 'tool/quran_data/.cache/qpc_fonts_extract';
const _outputFontsDir = 'assets/quran/fonts/qpc_v2';
const _manifestPath = 'assets/quran/manifests/qpc_v2_fonts.json';

void main() {
  final zip = File(_sourceZip);
  if (!zip.existsSync()) {
    stderr.writeln(
      'Missing "$_sourceZip" — the QPC V2 font package must be manually '
      'obtained from QUL and placed at this path (see '
      'docs/QURAN_DATA_PROVENANCE.md §8). Not fetched automatically: QUL '
      'gates this download behind a required user login.',
    );
    exit(1);
  }

  stdout.writeln('Extracting font package...');
  final extractDir = Directory(_cache);
  final packageHash = extractQpcFontPackage(zip, extractDir);
  stdout.writeln('Package hash: $packageHash');

  stdout.writeln(
    'Verifying all 604 pages (this reads every font\'s embedded '
    'name table, not filename arithmetic)...',
  );
  final result = buildQpcFontPackage(
    extractedFontsDir: extractDir,
    fontPackageSource: 'QUL QPC V2 Font package ($_sourceZip)',
    fontPackageHash: packageHash,
    outputFontsDir: Directory(_outputFontsDir),
    mushafId: _mushafId,
  );

  if (result.issues.isNotEmpty) {
    stderr.writeln('Font package verification FAILED:');
    for (final issue in result.issues) {
      stderr.writeln('  $issue');
    }
    exit(1);
  }

  final manifestHash = writePageFontManifest(
    result.manifest,
    File(_manifestPath),
  );

  stdout.writeln(
    'Verified all ${result.manifest.entries.length} pages. '
    'Manifest hash: $manifestHash',
  );
  stdout.writeln('Done. Fonts written under $_outputFontsDir/.');
}
