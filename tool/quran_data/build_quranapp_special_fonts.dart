// Verifies the real, vendored quran_common.ttf/suracon.ttf/uthmanic_hafs.ttf
// fonts (from a local AlfaazPlus/QuranApp checkout — see
// docs/QURAN_DATA_PROVENANCE.md §14/§15/§16) and repackages them into
// Flutter assets plus generated, verified manifests:
//
//   assets/quran/fonts/quranapp/quran_common.ttf
//   assets/quran/fonts/quranapp/suracon.ttf
//   assets/quran/fonts/quranapp/uthmanic_hafs.ttf
//   assets/quran/manifests/quran_common_font.json
//   assets/quran/manifests/suracon_glyphs.json
//   assets/quran/manifests/uthmanic_hafs_font.json
//
// Never renames, subsets, re-encodes, or otherwise modifies a font file.
// Fails loudly (non-zero exit) if U+E000/U+FDFD are absent from
// quran_common.ttf's cmap, or if any of the 114 Surah glyphs (or the
// prefix glyph) is absent from suracon.ttf's cmap.
//
// Run with: dart run tool/quran_data/build_quranapp_special_fonts.dart
import 'dart:io';

import 'src/quranapp_font_package.dart';

const _quranCommonSource = 'tool/quran_data/sources/quran_common.ttf';
const _suraconSource = 'tool/quran_data/sources/suracon.ttf';
const _uthmanicHafsSource = 'tool/quran_data/sources/uthmanic_hafs.ttf';
const _quranCommonOut = 'assets/quran/fonts/quranapp/quran_common.ttf';
const _suraconOut = 'assets/quran/fonts/quranapp/suracon.ttf';
const _uthmanicHafsOut = 'assets/quran/fonts/quranapp/uthmanic_hafs.ttf';

void main() {
  final quranCommonFile = File(_quranCommonSource);
  final suraconFile = File(_suraconSource);
  final uthmanicHafsFile = File(_uthmanicHafsSource);
  if (!quranCommonFile.existsSync() ||
      !suraconFile.existsSync() ||
      !uthmanicHafsFile.existsSync()) {
    stderr.writeln(
      'Missing "$_quranCommonSource", "$_suraconSource", and/or '
      '"$_uthmanicHafsSource" — all must be manually vendored from a local '
      'AlfaazPlus/QuranApp checkout (see docs/QURAN_DATA_PROVENANCE.md '
      '§14/§15/§16).',
    );
    exit(1);
  }

  stdout.writeln("Verifying quran_common.ttf's U+E000/U+FDFD...");
  final commonResult = buildQuranCommonFontManifest(
    fontFile: quranCommonFile,
    fontSource:
        'AlfaazPlus/QuranApp app/src/main/res/font/quran_common.ttf '
        '(local checkout)',
    outputFontFile: File(_quranCommonOut),
  );
  if (commonResult.manifest == null) {
    stderr.writeln('quran_common.ttf verification FAILED:');
    for (final issue in commonResult.issues) {
      stderr.writeln('  $issue');
    }
    exit(1);
  }
  final commonHash = writeJsonManifest(
    quranCommonFontManifestToJson(commonResult.manifest!),
    File('assets/quran/manifests/quran_common_font.json'),
  );
  stdout.writeln('quran_common.ttf verified. Manifest hash: $commonHash');

  stdout.writeln('Verifying all 114 suracon.ttf surah glyphs + prefix...');
  final suraconResult = buildSuraconGlyphManifest(
    fontFile: suraconFile,
    fontSource:
        'AlfaazPlus/QuranApp app/src/main/res/font/suracon.ttf '
        '(local checkout)',
    outputFontFile: File(_suraconOut),
  );
  if (suraconResult.manifest == null) {
    stderr.writeln('suracon.ttf verification FAILED:');
    for (final issue in suraconResult.issues) {
      stderr.writeln('  $issue');
    }
    exit(1);
  }
  final suraconHash = writeJsonManifest(
    suraconGlyphManifestToJson(suraconResult.manifest!),
    File('assets/quran/manifests/suracon_glyphs.json'),
  );
  stdout.writeln(
    'Verified all ${suraconResult.manifest!.entries.length} surah glyphs. '
    'Manifest hash: $suraconHash',
  );

  stdout.writeln('Verifying uthmanic_hafs.ttf...');
  final uthmanicHafsResult = buildQuranTextFontManifest(
    fontFile: uthmanicHafsFile,
    fontSource:
        'AlfaazPlus/QuranApp app/src/main/res/font/uthmanic_hafs.ttf '
        '(local checkout)',
    outputFontFile: File(_uthmanicHafsOut),
    outputAssetDir: 'assets/quran/fonts/quranapp',
  );
  if (uthmanicHafsResult.manifest == null) {
    stderr.writeln('uthmanic_hafs.ttf verification FAILED:');
    for (final issue in uthmanicHafsResult.issues) {
      stderr.writeln('  $issue');
    }
    exit(1);
  }
  final uthmanicHafsHash = writeJsonManifest(
    quranCommonFontManifestToJson(uthmanicHafsResult.manifest!),
    File('assets/quran/manifests/uthmanic_hafs_font.json'),
  );
  stdout.writeln(
    'uthmanic_hafs.ttf verified. Manifest hash: $uthmanicHafsHash',
  );
  stdout.writeln('Done.');
}
