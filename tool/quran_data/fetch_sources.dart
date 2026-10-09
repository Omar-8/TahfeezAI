// Fetches the raw, upstream source files the production Quran dataset is
// built from (Tanzil canonical text + metadata, QuranEnc translations and
// tafsir) into tool/quran_data/.cache/, so build_production_data.dart never
// has to reach the network itself.
//
// The QUL KFGQPC V2 Mushaf layout file is *not* fetched here: QUL gates that
// download behind a required user login and has no public API (verified by
// hand), so it must be obtained manually and placed at
// tool/quran_data/sources/qpc-v2-15-lines.db.zip — see
// docs/QURAN_DATA_PROVENANCE.md for that resource's status.
//
// Run with: dart run tool/quran_data/fetch_sources.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

final _cacheDir = Directory('tool/quran_data/.cache');

/// `dart run tool/quran_data/fetch_sources.dart [quranenc | wbw]`:
/// everything; with `quranenc` only the QuranEnc translations and tafsir;
/// with `wbw` only the word-by-word data (the canonical Tanzil text is left
/// as cached in both).
Future<void> main(List<String> args) async {
  if (!_cacheDir.existsSync()) {
    _cacheDir.createSync(recursive: true);
  }
  if (args.contains('wbw')) {
    await _fetchQuranComWbw();
    return;
  }

  if (!args.contains('quranenc')) {
    await _fetchTanzilText();
    await _fetchTanzilMetadata();
  }
  await _fetchQuranEnc(
    key: 'english_rwwad',
    url: 'https://quranenc.com/downloads/sqlite/english_rwwad.zip',
  );
  await _fetchQuranEnc(
    key: 'german_rwwad',
    url: 'https://quranenc.com/downloads/sqlite/german_rwwad.zip',
  );
  await _fetchQuranEnc(
    key: 'arabic_moyassar',
    url: 'https://quranenc.com/downloads/sqlite/arabic_moyassar.zip',
  );
  // Translation milestone T4 (docs/TRANSLATION_TAFSIR_MILESTONE.md): the
  // launch languages' translations and Al-Mukhtasar tafsir.
  for (final key in const [
    'urdu_junagarhi',
    'indonesian_affairs',
    'turkish_rwwad',
    'french_montada',
    'indonesian_mokhtasar',
    'turkish_mokhtasar',
    'french_mokhtasar',
  ]) {
    await _fetchQuranEnc(
      key: key,
      url: 'https://quranenc.com/downloads/sqlite/$key.zip',
    );
  }
  // No sqlite export is published for this one; its API serves the same
  // rows, written here into the same table shape.
  await _fetchQuranEncViaApi('english_mokhtasar');

  stdout.writeln('All sources fetched into ${_cacheDir.path}');
}

Future<void> _fetchTanzilText() async {
  stdout.writeln('Fetching Tanzil Uthmani text...');
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('https://tanzil.net/pub/download/index.php'),
    );
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
    );
    final body =
        'quranType=uthmani&outType=txt-2&marks=false&sajdah=false&rub=false&'
        'tatweel=true&agree=true';
    request.write(body);
    final response = await request.close();
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (b, d) => b..add(d),
    );
    if (response.statusCode != 200) {
      throw StateError('Tanzil text fetch failed: HTTP ${response.statusCode}');
    }
    File('${_cacheDir.path}/tanzil_uthmani.txt')
        .writeAsBytesSync(bytes.takeBytes());
  } finally {
    client.close();
  }
}

Future<void> _fetchTanzilMetadata() async {
  stdout.writeln('Fetching Tanzil metadata XML...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('https://tanzil.net/res/text/metadata/quran-data.xml'),
    );
    final response = await request.close();
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (b, d) => b..add(d),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Tanzil metadata fetch failed: HTTP ${response.statusCode}',
      );
    }
    File('${_cacheDir.path}/quran-data.xml')
        .writeAsBytesSync(bytes.takeBytes());
  } finally {
    client.close();
  }
}

Future<void> _fetchQuranEnc({required String key, required String url}) async {
  stdout.writeln('Fetching QuranEnc resource "$key"...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await response.fold<BytesBuilder>(
      BytesBuilder(),
      (b, d) => b..add(d),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'QuranEnc fetch failed for $key: HTTP ${response.statusCode}',
      );
    }
    final zipPath = '${_cacheDir.path}/$key.zip';
    File(zipPath).writeAsBytesSync(bytes.takeBytes());
    _unzip(zipPath, '${_cacheDir.path}/$key');
  } finally {
    client.close();
  }
}

/// Quran.com's word-by-word English (meaning + transliteration), from its
/// public API v4, one JSON file per surah under `.cache/qurancom_wbw/`
/// (the same data QUL lists as resource 92; licence unverified — an owner
/// decision, `docs/THIRD_PARTY_RESOURCES.md`).
Future<void> _fetchQuranComWbw() async {
  stdout.writeln('Fetching Quran.com word-by-word (English)...');
  final dir = Directory('${_cacheDir.path}/qurancom_wbw')
    ..createSync(recursive: true);
  final client = HttpClient();
  try {
    for (var surah = 1; surah <= 114; surah++) {
      final verses = <Object?>[];
      for (var page = 1; ; page++) {
        final request = await client.getUrl(
          Uri.parse(
            'https://api.quran.com/api/v4/verses/by_chapter/$surah'
            '?words=true&word_fields=text_uthmani&per_page=50&page=$page',
          ),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode != 200) {
          throw StateError(
            'Quran.com API failed for $surah/$page: HTTP '
            '${response.statusCode}',
          );
        }
        final json = jsonDecode(body) as Map;
        verses.addAll(json['verses'] as List);
        final next = (json['pagination'] as Map)['next_page'];
        if (next == null) break;
      }
      File('${dir.path}/$surah.json').writeAsStringSync(jsonEncode(verses));
    }
  } finally {
    client.close();
  }
}

/// Fetches every surah of QuranEnc resource [key] from its public API
/// (`/api/v1/translation/sura/{key}/{n}`) into
/// `.cache/{key}/{key}.sqlite`, in the exports' own
/// `translations(id, sura, aya, translation, footnotes)` shape. The API
/// prefixes each text with its ayah number ("7. …"), dropped here only
/// where it matches.
Future<void> _fetchQuranEncViaApi(String key) async {
  stdout.writeln('Fetching QuranEnc resource "$key" via its API...');
  final dir = Directory('${_cacheDir.path}/$key')..createSync(recursive: true);
  final file = File('${dir.path}/$key.sqlite');
  if (file.existsSync()) file.deleteSync();
  final db = sqlite3.open(file.path);
  final client = HttpClient();
  try {
    db.execute(
      'CREATE TABLE translations (id INTEGER PRIMARY KEY, sura INTEGER, '
      'aya INTEGER, translation TEXT, footnotes TEXT)',
    );
    final insert = db.prepare(
      'INSERT INTO translations (id, sura, aya, translation, footnotes) '
      'VALUES (?, ?, ?, ?, ?)',
    );
    for (var sura = 1; sura <= 114; sura++) {
      final request = await client.getUrl(
        Uri.parse('https://quranenc.com/api/v1/translation/sura/$key/$sura'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw StateError(
          'QuranEnc API failed for $key/$sura: HTTP '
          '${response.statusCode}',
        );
      }
      final rows = (jsonDecode(body) as Map)['result'] as List;
      for (final r in rows.cast<Map>()) {
        final aya = int.parse('${r['aya']}');
        var text = '${r['translation']}'.trim();
        final prefix = RegExp(r'^(\d+)\.\s*').firstMatch(text);
        if (prefix != null && int.parse(prefix.group(1)!) == aya) {
          text = text.substring(prefix.end);
        }
        insert.execute([
          int.parse('${r['id']}'),
          sura,
          aya,
          text,
          r['footnotes'] ?? '',
        ]);
      }
    }
    insert.close();
  } finally {
    client.close();
    db.close();
  }
}

void _unzip(String zipPath, String destDir) {
  Directory(destDir).createSync(recursive: true);
  final result = Process.runSync('unzip', ['-o', zipPath, '-d', destDir]);
  if (result.exitCode != 0) {
    throw StateError('unzip failed for $zipPath: ${result.stderr}');
  }
}
