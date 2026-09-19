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
import 'dart:io';
import 'dart:typed_data';

final _cacheDir = Directory('tool/quran_data/.cache');

Future<void> main() async {
  if (!_cacheDir.existsSync()) {
    _cacheDir.createSync(recursive: true);
  }

  await _fetchTanzilText();
  await _fetchTanzilMetadata();
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

void _unzip(String zipPath, String destDir) {
  Directory(destDir).createSync(recursive: true);
  final result = Process.runSync('unzip', ['-o', zipPath, '-d', destDir]);
  if (result.exitCode != 0) {
    throw StateError('unzip failed for $zipPath: ${result.stderr}');
  }
}
