// Builds the QPC Hafs display-word manifest for verse-by-verse mode:
//
//   assets/quran/quran_display/qpc_hafs_display_words.json
//
// Source: tool/quran_data/sources/qpc-hafs-word-by-word.db.zip (QUL's own
// "QPC Hafs" word-by-word export, manually vendored — see
// docs/QURAN_DATA_PROVENANCE.md §17). Never fetched over the network; QUL
// gates this download behind a required user login.
//
// This does NOT replace, alter, or re-derive canonical Quran text: the
// canonical dataset (tanzil_uthmani.txt via parseTanzilSource, the exact
// same source build_production_data.dart uses) is read fresh here purely
// to VALIDATE the QPC Hafs script against it — every canonical ayah's own
// word count is the ground truth an ayah's QPC Hafs reconstruction must
// match before it is trusted for display. An ayah that doesn't validate is
// excluded from the manifest, not silently included with mismatched or
// guessed text (see the one real exception this found: 37:130, where
// Tanzil and QPC segment the compound name "الياسين" into a different
// number of words — a genuine orthographic difference, not a data error).
//
// Run with: dart run tool/quran_data/build_qpc_hafs_display.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'src/tanzil_source.dart';

const _cache = 'tool/quran_data/.cache';
const _sourceZip = 'tool/quran_data/sources/qpc-hafs-word-by-word.db.zip';
const _outDir = 'assets/quran/quran_display';
const _outFile = '$_outDir/qpc_hafs_display_words.json';
const _schemaVersion = 1;

Future<void> main() async {
  final tanzilText = File('$_cache/tanzil_uthmani.txt');
  final tanzilMeta = File('$_cache/quran-data.xml');
  if (!tanzilText.existsSync() || !tanzilMeta.existsSync()) {
    stderr.writeln(
      'Missing cached Tanzil sources — run '
      '`dart run tool/quran_data/fetch_sources.dart` first.',
    );
    exit(1);
  }
  final sourceZip = File(_sourceZip);
  if (!sourceZip.existsSync()) {
    stderr.writeln(
      'Missing "$_sourceZip" — manually vendor QUL\'s QPC Hafs '
      'word-by-word export there (see docs/QURAN_DATA_PROVENANCE.md §17).',
    );
    exit(1);
  }

  stdout.writeln('Parsing canonical Tanzil text (validation ground truth)...');
  final tanzil = parseTanzilSource(
    textFile: tanzilText,
    metadataFile: tanzilMeta,
  );
  final canonicalWordsByAyah = <int, int>{};
  for (final word in tanzil.payload.ayahWords) {
    canonicalWordsByAyah[word.ayahId] =
        (canonicalWordsByAyah[word.ayahId] ?? 0) + 1;
  }
  stdout.writeln('Canonical dataset: ${canonicalWordsByAyah.length} ayahs.');

  stdout.writeln('Extracting and reading QPC Hafs word-by-word export...');
  final extractDir = Directory('$_cache/qpc_hafs_wbw');
  extractDir.createSync(recursive: true);
  final unzip = Process.runSync('unzip', [
    '-o',
    sourceZip.path,
    '-d',
    extractDir.path,
  ]);
  if (unzip.exitCode != 0) {
    stderr.writeln('Failed to extract $_sourceZip: ${unzip.stderr}');
    exit(1);
  }
  final dbFile = File('${extractDir.path}/qpc-hafs-word-by-word.db');
  final dbBytes = dbFile.readAsBytesSync();
  final sourceHash = sha256.convert(dbBytes).toString();

  final db = sqlite3.open(dbFile.path);
  final List<({int surah, int ayah, int word, String text})> rows;
  try {
    rows = db
        .select(
          'SELECT surah, ayah, word, text FROM words ORDER BY surah, ayah, word',
        )
        .map(
          (row) => (
            surah: row['surah'] as int,
            ayah: row['ayah'] as int,
            word: row['word'] as int,
            text: row['text'] as String,
          ),
        )
        .toList();
  } finally {
    db.close();
  }

  final qpcWordsByAyah = <int, List<String>>{};
  for (final row in rows) {
    final ayahId = row.surah * 1000 + row.ayah;
    (qpcWordsByAyah[ayahId] ??= []).add(row.text);
  }
  stdout.writeln(
    'QPC Hafs export: ${qpcWordsByAyah.length} ayahs, ${rows.length} words.',
  );

  // Validate every canonical ayah against its QPC Hafs reconstruction.
  // QPC's own word-by-word script counts the trailing ayah-end marker
  // (e.g. "٥") as its own extra "word" entry that Tanzil's word list does
  // not have — confirmed true for 6,235 of 6,236 ayahs by direct,
  // exhaustive comparison. An ayah only enters the manifest when its real
  // (marker-excluded) QPC word count matches Tanzil's own word count
  // exactly, so a caller can always zip canonical AyahWord[i] with this
  // manifest's word[i] and know they refer to the same word.
  final displayWords = <int, List<String>>{};
  final missingFromQpc = <int>[];
  final countMismatches = <int>[];
  for (final entry in canonicalWordsByAyah.entries) {
    final ayahId = entry.key;
    final canonicalCount = entry.value;
    final qpcWords = qpcWordsByAyah[ayahId];
    if (qpcWords == null) {
      missingFromQpc.add(ayahId);
      continue;
    }
    if (qpcWords.length != canonicalCount + 1) {
      countMismatches.add(ayahId);
      continue;
    }
    displayWords[ayahId] = qpcWords.sublist(0, canonicalCount);
  }

  stdout.writeln('Validation results:');
  stdout.writeln('  Imported (validated) ayahs: ${displayWords.length}');
  stdout.writeln(
    '  Missing from QPC Hafs export: ${missingFromQpc.length} $missingFromQpc',
  );
  stdout.writeln(
    '  Word-count mismatches (excluded, not guessed): '
    '${countMismatches.length} $countMismatches',
  );
  if (displayWords.length != canonicalWordsByAyah.length &&
      countMismatches.length > 5) {
    stderr.writeln(
      'More than 5 ayahs failed validation — this looks like a real data '
      'problem, not the single known 37:130 segmentation difference. '
      'Refusing to write a manifest.',
    );
    exit(1);
  }

  Directory(_outDir).createSync(recursive: true);
  final manifest = {
    'schemaVersion': _schemaVersion,
    'source': 'QUL QPC Hafs word-by-word export (qpc-hafs-word-by-word.db)',
    'sourceHash': sourceHash,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'importedAyahCount': displayWords.length,
    'excludedAyahIds': countMismatches,
    'words': {for (final e in displayWords.entries) e.key.toString(): e.value},
  };
  final outBytes = utf8.encode(
    const JsonEncoder.withIndent('  ').convert(manifest),
  );
  File(_outFile).writeAsBytesSync(outBytes);
  final outHash = sha256.convert(outBytes).toString();
  stdout.writeln('Wrote $_outFile (sha256 $outHash).');
}
