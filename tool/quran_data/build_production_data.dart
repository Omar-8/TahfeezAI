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
import 'package:sqlite3/sqlite3.dart';
import 'package:tahfeez_ai/quran/data/import/dataset_json_codec.dart';
import 'package:tahfeez_ai/quran/domain/dataset_integrity.dart';
import 'package:tahfeez_ai/quran/domain/quran_dataset_payload.dart';

import 'src/mushaf_import.dart';
import 'src/mushaf_layout_source.dart';
import 'src/mushaf_wbw_source.dart';
import 'src/quranenc_source.dart';
import 'src/qurancom_wbw_source.dart';
import 'src/tanzil_source.dart';

const _toolVersion = '1.1.0';

/// The launch languages' ayah translations (QuranEnc keys and versions as
/// listed by its API, 2026-10-09).
const _launchTranslations = [
  (
    key: 'urdu_junagarhi',
    slug: 'ur-junagarhi',
    displayName: 'Urdu Translation - Muhammad Junagarhi',
    language: 'ur',
    author: 'Muhammad Junagarhi',
    version: '1.1.3',
    versionCode: 1103,
  ),
  (
    key: 'indonesian_affairs',
    slug: 'id-affairs',
    displayName: 'Indonesian Translation - Ministry of Religious Affairs',
    language: 'id',
    author: 'Ministry of Religious Affairs (Indonesia)',
    version: '1.0.1',
    versionCode: 1001,
  ),
  (
    key: 'turkish_rwwad',
    slug: 'tr-rowwad',
    displayName: 'Turkish Translation - Rowwad Translation Center',
    language: 'tr',
    author: 'Rowwad Translation Center',
    version: '1.0.4',
    versionCode: 1004,
  ),
  (
    key: 'french_montada',
    slug: 'fr-noor',
    displayName: 'French Translation - Noor International Center',
    language: 'fr',
    author: 'Noor International Center',
    version: '1.0.0',
    versionCode: 1000,
  ),
  // Added 2026-10-14. QuranEnc's API lists no version for the Russian and
  // Bengali ones; they are tracked by sourceHash.
  (
    key: 'spanish_montada_eu',
    slug: 'es-noor',
    displayName: 'Spanish Translation - Noor International Center',
    language: 'es',
    author: 'Noor International Center',
    version: '1.0.1',
    versionCode: 1001,
  ),
  (
    key: 'russian_rwwad',
    slug: 'ru-rowwad',
    displayName: 'Russian Translation - Rowwad Translation Center',
    language: 'ru',
    author: 'Rowwad Translation Center',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'persian_ih',
    slug: 'fa-rowwad',
    displayName: 'Persian Translation - Rowwad Translation Center',
    language: 'fa',
    author: 'Rowwad Translation Center',
    version: '1.1.3',
    versionCode: 1103,
  ),
  (
    key: 'bengali_rwwad',
    slug: 'bn-rowwad',
    displayName: 'Bengali Translation - Rowwad Translation Center',
    language: 'bn',
    author: 'Rowwad Translation Center',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  // Added 2026-10-25 (owner): Malay, Hausa, Kurdish (Sorani), Pashto, Swahili,
  // Kazakh, Uzbek and Somali. Tracked by sourceHash.
  (
    key: 'malay_basumayyah',
    slug: 'ms-basumayyah',
    displayName: 'Malay Translation - Abdullah Basumayyah',
    language: 'ms',
    author: 'Abdullah Muhammad Basumayyah',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'hausa_gummi',
    slug: 'ha-gumi',
    displayName: 'Hausa Translation - Abu Bakr Mahmoud Gumi',
    language: 'ha',
    author: 'Abu Bakr Mahmoud Gumi',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'kurdish_bamoki',
    slug: 'ckb-bamoki',
    displayName: 'Kurdish Translation - Muhammad Salih Bamoki',
    language: 'ckb',
    author: 'Muhammad Salih Bamoki',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'pashto_rwwad',
    slug: 'ps-rowwad',
    displayName: 'Pashto Translation - Rowwad Translation Center',
    language: 'ps',
    author: 'Rowwad Translation Center',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'swahili_rwwad',
    slug: 'sw-rowwad',
    displayName: 'Swahili Translation - Rowwad Translation Center',
    language: 'sw',
    author: 'Rowwad Translation Center',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'kazakh_altai',
    slug: 'kk-altai',
    displayName: 'Kazakh Translation - Khalifa Altai',
    language: 'kk',
    author: 'Khalifa Altai',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'uzbek_rwwad',
    slug: 'uz-rowwad',
    displayName: 'Uzbek Translation - Rowwad Translation Center',
    language: 'uz',
    author: 'Rowwad Translation Center',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
  (
    key: 'somali_yacob',
    slug: 'so-yaqoub',
    displayName: 'Somali Translation - Abdullah Hasan Yaqoub',
    language: 'so',
    author: 'Abdullah Hasan Yaqoub',
    version: 'unversioned upstream (tracked by sourceHash)',
    versionCode: 1,
  ),
];

const _mukhtasarAuthor = 'Tafsir Center for Quranic Studies';

/// Al-Mukhtasar fī Tafsīr al-Qurʾān al-Karīm in the launch languages that
/// have it (none in Urdu).
const _launchTafsirs = [
  (
    key: 'english_mokhtasar',
    id: 'en-mukhtasar',
    displayName: 'Al-Mukhtasar in Interpreting the Noble Quran (English)',
    language: 'en',
  ),
  (
    key: 'indonesian_mokhtasar',
    id: 'id-mukhtasar',
    displayName: 'Al-Mukhtashar dalam Tafsir Al-Qur\'an (Indonesia)',
    language: 'id',
  ),
  (
    key: 'turkish_mokhtasar',
    id: 'tr-mukhtasar',
    displayName: 'Muhtasar Kur\'an-ı Kerim Tefsiri (Türkçe)',
    language: 'tr',
  ),
  (
    key: 'french_mokhtasar',
    id: 'fr-mukhtasar',
    displayName: 'Al-Mukhtasar : exégèse abrégée du Coran (Français)',
    language: 'fr',
  ),
  (
    key: 'spanish_mokhtasar',
    id: 'es-mukhtasar',
    displayName: 'Al-Mukhtasar: exégesis resumida del Corán (Español)',
    language: 'es',
  ),
  (
    key: 'russian_mokhtasar',
    id: 'ru-mukhtasar',
    displayName: 'Аль-Мухтасар: краткий тафсир Корана (Русский)',
    language: 'ru',
  ),
  (
    key: 'persian_mokhtasar',
    id: 'fa-mukhtasar',
    displayName: 'المختصر في تفسير القرآن الکریم (فارسی)',
    language: 'fa',
  ),
  (
    key: 'bengali_mokhtasar',
    id: 'bn-mukhtasar',
    displayName: 'আল-মুখতাসার ফী তাফসীরিল কুরআনিল কারীম (বাংলা)',
    language: 'bn',
  ),
  // Added 2026-10-25 with their languages (QuranEnc has none in Malay,
  // Hausa, Swahili, Kazakh or Somali).
  (
    key: 'kurdish_mokhtasar',
    id: 'ckb-mukhtasar',
    displayName: 'کورتەی تەفسیری قورئانی پیرۆز (کوردی)',
    language: 'ckb',
  ),
  (
    key: 'pashto_mokhtasar',
    id: 'ps-mukhtasar',
    displayName: 'د قرآن کریم په تفسیر کې المختصر (پښتو)',
    language: 'ps',
  ),
  (
    key: 'uzbek_mokhtasar',
    id: 'uz-mukhtasar',
    displayName: 'Al-Muxtasar: Qurʼoni karim tafsiri (Oʻzbekcha)',
    language: 'uz',
  ),
];

/// Ayahs a tafsir leaves empty upstream because the one before covers them
/// too (Spanish 59:23 explains 59:23–24); their empty rows are left out
/// (and out of the checksum the app verifies).
/// Any other empty ayah fails the build.
const _tafsirMergedAyahs = {
  'spanish_mokhtasar': {'59:24'},
};

/// Quran.com's word meanings bundled, by language (fetched with
/// `fetch_sources.dart wbw`); English carries the transliteration.
const _wbwLanguages = [
  ('en', 'English word by word (Quran.com)'),
  ('ur', 'Urdu word by word (Quran.com)'),
  ('id', 'Indonesian word by word (Quran.com)'),
  ('tr', 'Turkish word by word (Quran.com)'),
  ('fa', 'Persian word by word (Quran.com)'),
  ('bn', 'Bengali word by word (Quran.com)'),
  ('fr', 'French word by word (QUL)'),
];

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

  // Unchanged canonical content is left byte-for-byte as shipped (only its
  // import timestamp would differ), so installs never re-import it.
  final datasetFile = File('$_outDir/quran_dataset.json');
  final datasetJson = quranDatasetPayloadToJson(tanzil.payload);
  Object? contentHash(Object? json) => json is Map && json['metadata'] is Map
      ? (json['metadata'] as Map)['contentHash']
      : null;
  final shipped = datasetFile.existsSync()
      ? contentHash(jsonDecode(datasetFile.readAsStringSync()))
      : null;
  final fresh = contentHash(datasetJson);
  packagedAssetHashes['quran_dataset.json'] =
      shipped != null && shipped == fresh
      ? sha256.convert(datasetFile.readAsBytesSync()).toString()
      : _writeJson(datasetFile.path, datasetJson);

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

  // The launch languages (docs/TRANSLATION_TAFSIR_MILESTONE.md, T4): each
  // must hold exactly the canonical ayahs, every one with text.
  final canonicalAyahs = {
    for (final a in tanzil.payload.ayahs) '${a.chapterNo}:${a.verseNo}',
  };
  // [merged]: ayahs deliberately absent (_tafsirMergedAyahs).
  void requireEveryAyah(
    String what,
    Iterable<(int, int, String)> rows, {
    Set<String> merged = const {},
  }) {
    final seen = <String>{};
    for (final (sura, aya, text) in rows) {
      final key = '$sura:$aya';
      if (!canonicalAyahs.contains(key) || text.trim().isEmpty) {
        throw StateError('$what: bad or empty ayah $key');
      }
      seen.add(key);
    }
    if (seen.length + merged.length != canonicalAyahs.length ||
        merged.any(seen.contains)) {
      throw StateError(
        '$what: ${seen.length} ayahs, expected ${canonicalAyahs.length}',
      );
    }
  }

  final extraTranslations = <(QuranEncTranslationResult, String, String)>[];
  for (final t in _launchTranslations) {
    final r = parseQuranEncTranslation(
      sqliteFile: File('$_cache/${t.key}/${t.key}.sqlite'),
      slug: t.slug,
      displayName: t.displayName,
      languageCode: t.language,
      author: t.author,
      version: t.versionCode,
    );
    requireEveryAyah(t.key, [
      for (final v in r.verses) (v.chapterNo, v.verseNo, v.text),
    ]);
    final asset = 'translations/${t.slug.replaceAll('-', '_')}.json';
    packagedAssetHashes[asset] = _writeJson('$_outDir/$asset', {
      'book': translationBookToJson(r.book),
      'verses': r.verses.map(translationVerseToJson).toList(),
    });
    extraTranslations.add((r, t.key, t.version));
  }
  final extraTafsirs = <(QuranEncTafsirResult, String)>[];
  for (final t in _launchTafsirs) {
    final merged = _tafsirMergedAyahs[t.key] ?? const <String>{};
    final r = parseQuranEncTafsir(
      sqliteFile: File('$_cache/${t.key}/${t.key}.sqlite'),
      tafsirId: t.id,
      displayName: t.displayName,
      languageCode: t.language,
      author: _mukhtasarAuthor,
      version: 1,
      leaveOut: merged,
    );
    requireEveryAyah(t.key, [
      for (final v in r.verses) (v.chapterNo, v.verseNo, v.text),
    ], merged: merged);
    final asset = 'tafsir/${t.id.replaceAll('-', '_')}.json';
    packagedAssetHashes[asset] = _writeJson('$_outDir/$asset', {
      'work': tafsirWorkToJson(r.work),
      'verses': r.verses.map(tafsirVerseToJson).toList(),
    });
    extraTafsirs.add((r, t.key));
  }
  // Urdu (owner decision 2026-10-18): Ahsan-ul-Bayan, the commentary of Hafiz
  // Salahuddin Yusuf that QuranEnc's Junagarhi translation carries as its
  // footnotes. Only the ayahs it comments on have a row.
  {
    final r = parseQuranEncTafsir(
      sqliteFile: File('$_cache/urdu_junagarhi/urdu_junagarhi.sqlite'),
      tafsirId: 'ur-ahsanulbayan',
      displayName: 'احسن البیان (اردو)',
      languageCode: 'ur',
      author: 'Hafiz Salahuddin Yusuf',
      version: 1,
      fromFootnotes: true,
      source: 'QuranEnc.com (footnotes of urdu_junagarhi)',
    );
    if (r.verses.length < 2000) {
      throw StateError('Ahsan-ul-Bayan: only ${r.verses.length} ayahs');
    }
    packagedAssetHashes['tafsir/ur_ahsanulbayan.json'] = _writeJson(
      '$_outDir/tafsir/ur_ahsanulbayan.json',
      {
        'work': tafsirWorkToJson(r.work),
        'verses': r.verses.map(tafsirVerseToJson).toList(),
      },
    );
    extraTafsirs.add((r, 'urdu_junagarhi'));
    stdout.writeln(
      'Ahsan-ul-Bayan (Urdu): ${r.verses.length} ayahs with commentary.',
    );
  }
  // Arabic word meanings (owner decision 2026-10-25): al-Sirāj fī Bayān
  // Gharīb al-Qurʾān, the difficult words of each ayah explained (QuranEnc's
  // "Meanings of Words"). Ayahs with no difficult word have no row.
  {
    const key = 'arabic_seraj';
    final file = File('$_cache/$key/$key.sqlite');
    final db = sqlite3.open(file.path);
    final empty = {
      for (final row in db.select(
        "SELECT sura, aya FROM translations WHERE trim(coalesce(translation, '')) = ''",
      ))
        '${row['sura']}:${row['aya']}',
    };
    db.close();
    final r = parseQuranEncTafsir(
      sqliteFile: file,
      tafsirId: 'ar-seraj',
      displayName: 'السراج في بيان غريب القرآن (معاني الكلمات)',
      languageCode: 'ar',
      author: 'Muhammad ibn Abdulaziz Al-Khudayri',
      version: 1,
      leaveOut: empty,
    );
    requireEveryAyah(key, [
      for (final v in r.verses) (v.chapterNo, v.verseNo, v.text),
    ], merged: empty);
    packagedAssetHashes['tafsir/ar_seraj.json'] = _writeJson(
      '$_outDir/tafsir/ar_seraj.json',
      {
        'work': tafsirWorkToJson(r.work),
        'verses': r.verses.map(tafsirVerseToJson).toList(),
      },
    );
    extraTafsirs.add((r, key));
    stdout.writeln(
      'Al-Siraj (Arabic word meanings): ${r.verses.length} ayahs.',
    );
  }
  // Word meanings (docs/TRANSLATION_TAFSIR_MILESTONE.md, T3): Quran.com's
  // English, aligned to the canonical words — licence unverified, shipped
  // by owner decision (docs/THIRD_PARTY_RESOURCES.md).
  final wbwPacks = <QuranComWbwResult>[];
  _qulWbwCache(
    'fr',
    File('tool/quran_data/sources/qul-french-wbw-translation.json.zip'),
    'french-wbw-translation.json',
  );
  for (final (language, name) in _wbwLanguages) {
    final wbwCache = Directory(
      '$_cache/qurancom_wbw${language == 'en' ? '' : '_$language'}',
    );
    if (!wbwCache.existsSync()) continue;
    final result = alignQuranComWbw(
      cacheDir: wbwCache,
      canonicalWords: tanzil.payload.ayahWords,
      packId: '$language-qurancom',
      languageCode: language,
      displayName: name,
      packSource: language == 'fr'
          ? 'QUL (qul.tarteel.ai) French word by word, by Quran.com word position'
          : null,
    );
    if (result.words.length != tanzil.payload.ayahWords.length) {
      throw StateError(
        'Word meanings ($language): ${result.words.length} words, expected '
        '${tanzil.payload.ayahWords.length}',
      );
    }
    wbwPacks.add(result);
    Directory('$_outDir/wbw').createSync(recursive: true);
    final p = result.pack;
    packagedAssetHashes['wbw/${language}_qurancom.json'] = _writeJson(
      '$_outDir/wbw/${language}_qurancom.json',
      {
        'pack': {
          'id': p.id,
          'languageCode': p.languageCode,
          'displayName': p.displayName,
          'version': p.version,
          'checksum': p.checksum,
          'source': p.source,
          'license': p.license,
          'hasTranslation': p.hasTranslation,
          'hasTransliteration': p.hasTransliteration,
        },
        // [ayahId, wordIndex, meaning, transliteration] per word.
        'words': [
          for (final w in result.words)
            [w.ayahId, w.wordIndex, w.translation, w.transliteration],
        ],
      },
    );
    final missing = result.words.where((w) => w.translation == null).length;
    stdout.writeln(
      'Word meanings ($language): ${result.words.length} words aligned '
      '(${result.joined} joined, ${result.respelled} spelled differently, '
      '$missing without a meaning in the language).',
    );
  }

  stdout.writeln(
    'Launch languages: ${extraTranslations.length} translations, '
    '${extraTafsirs.length} tafsirs, every ayah present (Ahsan-ul-Bayan: '
    'the ayahs it comments on).',
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
        'OWNER DECISION 2026-10-09 — bundled and imported in every build, '
        'release included, while QUL layout/word-by-word redistribution '
        'terms stay unverified (docs/QURAN_DATA_PROVENANCE.md §7/§7a/§8, '
        'docs/THIRD_PARTY_RESOURCES.md).',
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
      for (final (r, key, version) in extraTranslations)
        {
          'slug': r.book.slug,
          'resourceId':
              'tahfeez.translation.${r.book.slug.replaceAll('-', '.')}',
          'quranEncKey': key,
          'version': version,
          'sourceHash': r.sourceHash,
          'ayahCount': r.verses.length,
        },
    ],
    'wbwResources': [
      for (final w in wbwPacks)
        {
          'id': w.pack.id,
          'resourceId': 'tahfeez.wbw.${w.pack.languageCode}.qurancom',
          'source': w.pack.languageCode == 'en'
              ? 'Quran.com API v4 (api.quran.com/api/v4), = QUL resource 92'
              : 'Quran.com API v4 (api.quran.com/api/v4), '
                    'language=${w.pack.languageCode}',
          'licenseStatus': w.pack.languageCode == 'en'
              ? 'UNVERIFIED — shipped by owner decision 2026-10-09'
              : 'UNVERIFIED — as the English pack (owner decision '
                    '2026-10-09), extended 2026-10-14',
          'sourceHash': w.sourceHash,
          'wordCount': w.words.length,
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
      for (final (r, key) in extraTafsirs)
        {
          'id': r.work.id,
          'resourceId': 'tahfeez.tafsir.${r.work.id.replaceAll('-', '.')}',
          'quranEncKey': key,
          'version':
              'unversioned upstream (QuranEnc lists no version for '
              'Al-Mukhtasar; tracked by sourceHash)',
          'sourceHash': r.sourceHash,
          'ayahCount': r.verses.length,
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

/// A word meanings cache in Quran.com's form for a language QUL has and Quran.com
/// does not: Quran.com's English word list (the cache `fetch_sources.dart wbw`
/// writes), each word's meaning replaced by QUL's at the same `surah:ayah:word`
/// position. A word QUL has no meaning for keeps the English one, marked as
/// English (so the alignment leaves it to the English pack).
void _qulWbwCache(String language, File zip, String member) {
  final en = Directory('$_cache/qurancom_wbw');
  if (!zip.existsSync() || !en.existsSync()) return;
  final tmp = Directory('$_cache/qul_wbw_$language')
    ..createSync(recursive: true);
  _unzip(zip, tmp);
  final meanings = (jsonDecode(
    File('${tmp.path}/$member').readAsStringSync(),
  ) as Map).cast<String, String>();
  final out = Directory('$_cache/qurancom_wbw_$language')
    ..createSync(recursive: true);
  final name = quranComLanguageNames[language]!;
  for (var surah = 1; surah <= 114; surah++) {
    final verses =
        jsonDecode(File('${en.path}/$surah.json').readAsStringSync()) as List;
    for (final v in verses.cast<Map<String, Object?>>()) {
      for (final w in (v['words']! as List).cast<Map<String, Object?>>()) {
        if (w['char_type_name'] != 'word') continue;
        final m = meanings['${v['verse_key']}:${w['position']}']?.trim();
        if (m != null && m.isNotEmpty) {
          w['translation'] = {'text': m, 'language_name': name};
        }
      }
    }
    File('${out.path}/$surah.json').writeAsStringSync(jsonEncode(verses));
  }
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
