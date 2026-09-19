// Builds Tahfeez's production Quran dataset from the cached upstream
// sources (run `dart run tool/quran_data/fetch_sources.dart` first) and the
// vendored QUL files, writing:
//
//   assets/quran/quran_dataset.json          (canonical Tanzil text + metadata)
//   assets/quran/translations/en_rowwad.json
//   assets/quran/translations/de_rowwad.json
//   assets/quran/tafsir/ar_muyassar.json
//   assets/quran/mushaf/kfgqpc_v2.json       (real Mushaf/MushafLine/MushafToken data)
//   assets/quran/resource_manifest.json
//
// assets/quran/mushaf/kfgqpc_v2.json is deliberately NOT declared as a
// Flutter asset in pubspec.yaml (see docs/QURAN_DATA_PROVENANCE.md §7/§7a):
// QUL's redistribution terms for the layout and word-by-word resources are
// still unverified (SHIP_BLOCKED_LICENSE), so this file exists for local
// development, integrity testing, and validation, but is never bundled
// into a real app build until that license gate clears. No synthetic
// Mushaf content is ever substituted for the real files.
//
// Run with: dart run tool/quran_data/build_production_data.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/dataset_integrity.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

import 'src/mushaf_import.dart';
import 'src/mushaf_layout_source.dart';
import 'src/mushaf_wbw_source.dart';
import 'src/quranenc_source.dart';
import 'src/tanzil_source.dart';

const _toolVersion = '1.0.0';
const _cache = 'tool/quran_data/.cache';
const _outDir = 'assets/quran';

Future<void> main() async {
  _requireFile('$_cache/tanzil_uthmani.txt', hint: 'fetch_sources.dart');
  _requireFile('$_cache/quran-data.xml', hint: 'fetch_sources.dart');

  stdout.writeln('Parsing Tanzil canonical text + metadata...');
  final tanzil = parseTanzilSource(
    textFile: File('$_cache/tanzil_uthmani.txt'),
    metadataFile: File('$_cache/quran-data.xml'),
  );

  const validator = DatasetIntegrityValidator();
  final report = validator.validate(tanzil.payload);
  if (!report.isValid) {
    stderr.writeln('Canonical dataset FAILED integrity validation:');
    for (final issue in report.errors) {
      stderr.writeln('  $issue');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Canonical dataset valid: ${tanzil.payload.surahs.length} surahs, '
    '${tanzil.payload.ayahs.length} ayahs, '
    '${tanzil.payload.ayahWords.length} words.',
  );

  Directory(_outDir).createSync(recursive: true);
  Directory('$_outDir/translations').createSync(recursive: true);
  Directory('$_outDir/tafsir').createSync(recursive: true);

  final packagedAssetHashes = <String, String>{};

  packagedAssetHashes['quran_dataset.json'] = _writeJson(
    '$_outDir/quran_dataset.json',
    quranDatasetPayloadToJson(tanzil.payload),
  );

  stdout.writeln('Parsing QuranEnc translations and tafsir...');
  final en = parseQuranEncTranslation(
    sqliteFile: File('$_cache/english_rwwad/english_rwwad.sqlite'),
    slug: 'en-rowwad',
    displayName: 'English Translation - Rowwad Translation Center',
    languageCode: 'en',
    author: 'Rowwad Translation Center',
    version: 1019, // QuranEnc key "english_rwwad" version 1.0.19
  );
  packagedAssetHashes['translations/en_rowwad.json'] = _writeJson(
    '$_outDir/translations/en_rowwad.json',
    {
      'book': translationBookToJson(en.book),
      'verses': en.verses.map(translationVerseToJson).toList(),
    },
  );

  final de = parseQuranEncTranslation(
    sqliteFile: File('$_cache/german_rwwad/german_rwwad.sqlite'),
    slug: 'de-rowwad',
    displayName: 'German Translation - Rowwad Translation Center',
    languageCode: 'de',
    author: 'Rowwad Translation Center',
    version: 1015, // QuranEnc key "german_rwwad" version 1.0.15
  );
  packagedAssetHashes['translations/de_rowwad.json'] = _writeJson(
    '$_outDir/translations/de_rowwad.json',
    {
      'book': translationBookToJson(de.book),
      'verses': de.verses.map(translationVerseToJson).toList(),
    },
  );

  final muyassar = parseQuranEncTafsir(
    sqliteFile: File('$_cache/arabic_moyassar/arabic_moyassar.sqlite'),
    tafsirId: 'ar-muyassar',
    displayName: 'التفسير الميسر (At-Tafsir Al-Muyassar)',
    languageCode: 'ar',
    author:
        'Compiled under the supervision of the King Fahd Complex for the '
        'Printing of the Holy Quran',
    version: 1,
  );
  packagedAssetHashes['tafsir/ar_muyassar.json'] = _writeJson(
    '$_outDir/tafsir/ar_muyassar.json',
    {
      'work': tafsirWorkToJson(muyassar.work),
      'verses': muyassar.verses.map(tafsirVerseToJson).toList(),
    },
  );

  stdout.writeln(
    'EN: ${en.verses.length} verses, DE: ${de.verses.length} verses, '
    'Tafsir: ${muyassar.verses.length} verses.',
  );

  // The Mushaf layer: real layout + real word-by-word data, combined and
  // classified through the same MushafTokenClassifier documented in
  // docs/QURAN_DATA_PROVENANCE.md §7c. Written to its own, non-bundled
  // asset (see the file-level doc comment) — the release gate (QUL
  // redistribution terms) is separate from whether the data itself is
  // correct, and this build fails loudly if the data is not.
  const mushafId = 1;
  String mushafStatus;
  QulLayoutInfo? mushafInfo;
  QulWordByWordInfo? wbwInfo;
  var mushafRowCounts = const <String, int>{};
  String? mushafDatasetHash;
  final qulLayoutZip = File('tool/quran_data/sources/qpc-v2-15-lines.db.zip');
  final qulWbwZip = File('tool/quran_data/sources/qpc-v2-word-by-word.db.zip');

  if (qulLayoutZip.existsSync() && qulWbwZip.existsSync()) {
    final layoutExtractDir = Directory('$_cache/qul_layout');
    layoutExtractDir.createSync(recursive: true);
    _unzip(qulLayoutZip, layoutExtractDir);
    final layoutSource = QulKfgqpcV2MushafDataSource(
      File('${layoutExtractDir.path}/qpc-v2-15-lines.db'),
    );
    mushafInfo = layoutSource.readInfo();

    final wbwExtractDir = Directory('$_cache/qul_wbw');
    wbwExtractDir.createSync(recursive: true);
    _unzip(qulWbwZip, wbwExtractDir);
    final tokenSource = QulKfgqpcV2WordByWordSource(
      File('${wbwExtractDir.path}/qpc-v2.db'),
    );
    wbwInfo = tokenSource.readInfo();

    final canonicalWordCountByAyahId = <int, int>{};
    for (final word in tanzil.payload.ayahWords) {
      canonicalWordCountByAyahId[word.ayahId] =
          (canonicalWordCountByAyahId[word.ayahId] ?? 0) + 1;
    }

    stdout.writeln('Importing Mushaf (layout + word-by-word)...');
    final mushafImport = await importMushaf(
      mushafId: mushafId,
      code: 'kfgqpc_v2',
      qiraah: 'Hafs',
      edition: 'Madinah / 1421H',
      scriptId: tanzil.payload.scripts.single.id,
      layoutSource: layoutSource,
      tokenSource: tokenSource,
      canonicalWordCountByAyahId: canonicalWordCountByAyahId,
    );

    if (mushafImport.classificationWarnings.isNotEmpty) {
      stderr.writeln(
        'Mushaf token classification produced '
        '${mushafImport.classificationWarnings.length} warning(s) — refusing '
        'to import an unresolved dataset:',
      );
      for (final w in mushafImport.classificationWarnings.take(20)) {
        stderr.writeln('  $w');
      }
      exitCode = 1;
      return;
    }

    // Validate the FULL dataset (canonical + Mushaf together) — this is
    // where a fabricated/invalid canonical mapping, a reversed token
    // range, or an unresolved line would be caught, per
    // DatasetIntegrityValidator's Mushaf-token checks.
    final fullPayload = QuranDatasetPayload(
      surahs: tanzil.payload.surahs,
      surahLocalizations: tanzil.payload.surahLocalizations,
      ayahs: tanzil.payload.ayahs,
      ayahWords: tanzil.payload.ayahWords,
      scripts: tanzil.payload.scripts,
      scriptVariants: tanzil.payload.scriptVariants,
      mushafs: [mushafImport.mushaf],
      mushafLines: mushafImport.lines,
      mushafTokens: mushafImport.tokens,
      navigationRanges: tanzil.payload.navigationRanges,
      metadata: tanzil.payload.metadata,
    );
    final fullReport = validator.validate(fullPayload);
    if (!fullReport.isValid) {
      stderr.writeln('Mushaf dataset FAILED integrity validation:');
      for (final issue in fullReport.errors.take(30)) {
        stderr.writeln('  $issue');
      }
      exitCode = 1;
      return;
    }

    final byType = <String, int>{};
    for (final t in mushafImport.tokens) {
      byType[t.tokenType.name] = (byType[t.tokenType.name] ?? 0) + 1;
    }
    mushafRowCounts = {
      'mushafs': 1,
      'mushafLines': mushafImport.lines.length,
      'mushafTokens': mushafImport.tokens.length,
      'quranWord': byType['quranWord'] ?? 0,
      'ayahMarker': byType['ayahMarker'] ?? 0,
      'otherMarker': byType['otherMarker'] ?? 0,
      'unknown': byType['unknown'] ?? 0,
    };
    stdout.writeln(
      'Mushaf import valid: ${mushafImport.lines.length} lines, '
      '${mushafImport.tokens.length} tokens '
      '(quranWord=${byType['quranWord']}, ayahMarker=${byType['ayahMarker']}).',
    );

    Directory('$_outDir/mushaf').createSync(recursive: true);
    mushafDatasetHash = _writeJson('$_outDir/mushaf/kfgqpc_v2.json', {
      'mushaf': mushafToJson(mushafImport.mushaf),
      'mushafLines': mushafImport.lines.map(mushafLineToJson).toList(),
      'mushafTokens': mushafImport.tokens.map(mushafTokenToJson).toList(),
    });

    mushafStatus = 'DATA_IMPORTED_SHIP_BLOCKED_LICENSE';
  } else {
    stdout.writeln(
      'QUL layout and/or word-by-word source missing — Mushaf layer skipped entirely.',
    );
    mushafStatus = 'SHIP_BLOCKED_MISSING_SOURCE';
  }

  final manifest = {
    'schemaVersion': 1,
    'buildDate': DateTime.now().toUtc().toIso8601String(),
    'canonicalQuranSource': 'Tanzil Project (tanzil.net)',
    'canonicalQuranVersion': 'Uthmani, Version 1.1',
    'canonicalQuranHash': tanzil.textContentHash,
    'canonicalMetadataSource': 'Tanzil Project quran-data.xml',
    'canonicalMetadataHash': tanzil.metadataContentHash,
    'mushafName': mushafInfo?.name ?? 'QCF V2 (1421H print)',
    'mushafEdition': 'KFGQPC V2',
    'mushafQirah': "Hafs 'an Asim",
    'mushafPages': mushafInfo?.pageCount ?? 604,
    'mushafLinesPerPage': mushafInfo?.linesPerPage ?? 15,
    'mushafLayoutDataHash': mushafInfo?.sourceHash,
    'mushafWordByWordDataHash': wbwInfo?.sourceHash,
    'mushafGeneratedDatasetHash': mushafDatasetHash,
    'mushafRowCounts': mushafRowCounts,
    'mushafFontStatus': 'SHIP_BLOCKED_LICENSE',
    'mushafStatus': mushafStatus,
    'mushafReleaseGate':
        'BLOCKED — QUL layout/word-by-word/font redistribution terms not '
        'independently verified (see docs/QURAN_DATA_PROVENANCE.md §7/§7a/§8). '
        'assets/quran/mushaf/kfgqpc_v2.json is generated for local '
        'development/testing only and is not declared as a Flutter asset.',
    'translationResources': [
      {
        'slug': en.book.slug,
        'resourceId': 'tahfeez.translation.en.rowwad',
        'quranEncKey': 'english_rwwad',
        'version': '1.0.19',
        'sourceHash': en.sourceHash,
        'ayahCount': en.verses.length,
      },
      {
        'slug': de.book.slug,
        'resourceId': 'tahfeez.translation.de.rowwad',
        'quranEncKey': 'german_rwwad',
        'version': '1.0.15',
        'sourceHash': de.sourceHash,
        'ayahCount': de.verses.length,
      },
    ],
    'tafsirResources': [
      {
        'id': muyassar.work.id,
        'resourceId': 'tahfeez.tafsir.ar.muyassar',
        'quranEncKey': 'arabic_moyassar',
        'version':
            'unversioned upstream (QuranEnc publishes no version number for '
            'this resource; tracked by sourceHash)',
        'sourceHash': muyassar.sourceHash,
        'ayahCount': muyassar.verses.length,
      },
    ],
    'toolVersion': _toolVersion,
    // The sha256 of each packaged asset file's own bytes, exactly as
    // shipped — verified at app startup before any asset is imported, so a
    // corrupted or tampered bundled file is refused rather than silently
    // imported. See lib/quran/data/import/bundled_dataset_seeder.dart.
    'packagedAssetHashes': packagedAssetHashes,
  };
  _writeJson('$_outDir/resource_manifest.json', manifest);

  stdout.writeln('Done. Assets written under $_outDir/.');
}

void _unzip(File zip, Directory destDir) {
  final result = Process.runSync('unzip', ['-o', zip.path, '-d', destDir.path]);
  if (result.exitCode != 0) {
    throw StateError('Failed to extract ${zip.path}: ${result.stderr}');
  }
}

void _requireFile(String path, {required String hint}) {
  if (!File(path).existsSync()) {
    stderr.writeln(
      'Missing $path — run `dart run tool/quran_data/$hint` first.',
    );
    exit(1);
  }
}

/// Writes [data] as indented JSON to [path] and returns the sha256 of the
/// exact bytes written, so callers can record it in the manifest.
String _writeJson(String path, Object data) {
  final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
  File(path).writeAsBytesSync(bytes);
  return sha256.convert(bytes).toString();
}
