// Verifies the real, vendored QUL Surah Header color font and its official
// ligature/JSON mapping, and repackages them into a Flutter asset plus a
// generated, verified surahNumber->glyph manifest:
//
//   assets/quran/fonts/qcf_surah_header/QCF_SurahHeader_COLOR-Regular.ttf
//   assets/quran/manifests/surah_header_glyphs.json
//
// Never renames, subsets, re-encodes, or otherwise modifies the font file.
// Fails loudly (non-zero exit) if any of the 114 surahs is missing from the
// ligature JSON or resolves to a codepoint absent from the font's own cmap
// table — see docs/QURAN_DATA_PROVENANCE.md.
//
// Run with: dart run tool/quran_data/build_surah_header_font.dart
import 'dart:io';

import 'src/surah_header_font_package.dart';

const _sourceZip =
    'tool/quran_data/sources/QCF_SurahHeader_COLOR-Regular.ttf.zip';
const _ligatureZip = 'tool/quran_data/sources/ligatures.json.zip';
const _cache = 'tool/quran_data/.cache/surah_header_extract';
const _outputFontFile =
    'assets/quran/fonts/qcf_surah_header/QCF_SurahHeader_COLOR-Regular.ttf';
const _manifestPath = 'assets/quran/manifests/surah_header_glyphs.json';

void main() {
  final fontZip = File(_sourceZip);
  final ligatureZip = File(_ligatureZip);
  if (!fontZip.existsSync() || !ligatureZip.existsSync()) {
    stderr.writeln(
      'Missing "$_sourceZip" and/or "$_ligatureZip" — both must be manually '
      'obtained from QUL and placed at these paths (see '
      'docs/QURAN_DATA_PROVENANCE.md).',
    );
    exit(1);
  }

  final extractDir = Directory(_cache)..createSync(recursive: true);
  _unzip(fontZip, extractDir);
  _unzip(ligatureZip, extractDir);

  final fontFile = File('${extractDir.path}/QCF_SurahHeader_COLOR-Regular.ttf');
  final ligatureFile = File('${extractDir.path}/ligatures.json');
  if (!fontFile.existsSync() || !ligatureFile.existsSync()) {
    stderr.writeln(
      'Extracted archives did not contain the expected filenames '
      '(QCF_SurahHeader_COLOR-Regular.ttf, ligatures.json).',
    );
    exit(1);
  }

  stdout.writeln(
    'Verifying all 114 surah header glyphs against the real font\'s cmap '
    'table...',
  );
  final result = buildSurahHeaderFontPackage(
    fontFile: fontFile,
    fontSource: 'QUL Surah Header color font ($_sourceZip)',
    ligatureJsonFile: ligatureFile,
    ligatureMappingSource: 'QUL Surah Header ligature JSON ($_ligatureZip)',
    outputFontFile: File(_outputFontFile),
  );

  if (result.manifest == null) {
    stderr.writeln('Surah header font verification FAILED:');
    for (final issue in result.issues) {
      stderr.writeln('  $issue');
    }
    exit(1);
  }

  final manifestHash = writeSurahHeaderGlyphManifest(
    result.manifest!,
    File(_manifestPath),
  );

  stdout.writeln(
    'Verified all ${result.manifest!.entries.length} surah header glyphs. '
    'Manifest hash: $manifestHash',
  );
  stdout.writeln('Done. Font written to $_outputFontFile.');
}

void _unzip(File zip, Directory destDir) {
  final result = Process.runSync('unzip', ['-o', zip.path, '-d', destDir.path]);
  if (result.exitCode != 0) {
    throw StateError('Failed to extract ${zip.path}: ${result.stderr}');
  }
}
