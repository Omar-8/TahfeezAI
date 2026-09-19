// Builds Tahfeez's bundled production Quran dataset from the cached upstream
// sources (run `dart run tool/quran_data/fetch_sources.dart` first) and the
// vendored QUL layout file, writing:
//
//   assets/quran/quran_dataset.json          (canonical Tanzil text + metadata)
//   assets/quran/translations/en_rowwad.json
//   assets/quran/translations/de_rowwad.json
//   assets/quran/tafsir/ar_muyassar.json
//   assets/quran/resource_manifest.json
//
// The Mushaf layout is deliberately NOT written into any asset: QUL's real
// KFGQPC V2 layout file has been validated structurally, but the companion
// word/script dataset that resolves its word ids to (ayah, wordIndex) has
// not been supplied yet, and no synthetic Mushaf data is ever generated as
// a stand-in. See docs/QURAN_DATA_PROVENANCE.md.
//
// Run with: dart run tool/quran_data/build_production_data.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/dataset_integrity.dart';

import 'src/mushaf_layout_source.dart';
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

  // The Mushaf layout is validated (real file, real structure) but not
  // shipped: see the file-level doc comment above.
  String mushafStatus;
  QulLayoutInfo? mushafInfo;
  final qulZip = File('tool/quran_data/sources/qpc-v2-15-lines.db.zip');
  if (qulZip.existsSync()) {
    final extractDir = Directory('$_cache/qul_layout');
    extractDir.createSync(recursive: true);
    final result = Process.runSync('unzip', [
      '-o',
      qulZip.path,
      '-d',
      extractDir.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Failed to extract QUL layout zip: ${result.stderr}');
    }
    final dbFile = File('${extractDir.path}/qpc-v2-15-lines.db');
    final source = QulKfgqpcV2MushafDataSource(dbFile);
    mushafInfo = source.readInfo();
    final layout = await source.loadRawLayout();
    final layoutReport = validateQulLayout(layout);
    stdout.writeln(
      'QUL layout structurally valid: ${layoutReport.isValid} '
      '(${layout.lines.length} lines across ${mushafInfo.pageCount} pages)',
    );
    mushafStatus = 'SHIP_BLOCKED_PENDING_WORD_DATA';
  } else {
    stdout.writeln(
      'No QUL layout source found at ${qulZip.path} — Mushaf layer skipped entirely.',
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
    'mushafDataHash': mushafInfo?.sourceHash,
    'mushafFontStatus': 'SHIP_BLOCKED_LICENSE',
    'mushafStatus': mushafStatus,
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
