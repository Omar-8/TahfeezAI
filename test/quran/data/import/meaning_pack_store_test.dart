import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';

/// Unpacks a bundled asset as the phone's code would: zlib (the main
/// databases) or xz (the packs; the xz tool here).
Future<String> _unpack(String asset, String destination) async {
  final List<int> bytes;
  if (asset.endsWith('.zlib')) {
    bytes = zlib.decode(File(asset).readAsBytesSync());
  } else {
    final out = await Process.run('xz', [
      '-d',
      '-c',
      asset,
    ], stdoutEncoding: null);
    bytes = out.stdout as List<int>;
  }
  File(destination).writeAsBytesSync(bytes);
  return sha256.convert(bytes).toString();
}

void main() {
  late Directory dir;
  late TranslationDatabase translations;
  late TafsirDatabase tafsir;
  late WbwDatabase wbw;
  late MeaningPackStore store;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('packs');
    // The ready-made databases as the phone gets them.
    Future<File> base(String name) async {
      final file = File('${dir.path}/$name.sqlite');
      await _unpack('assets/quran/db/$name.sqlite.zlib', file.path);
      return file;
    }

    translations = TranslationDatabase(
      NativeDatabase(await base('translations')),
    );
    tafsir = TafsirDatabase(NativeDatabase(await base('tafsirs')));
    wbw = WbwDatabase(NativeDatabase(await base('wbw_resources')));
    store = MeaningPackStore(
      databases: {
        MeaningPackKind.translation: translations,
        MeaningPackKind.tafsir: tafsir,
        MeaningPackKind.wbw: wbw,
      },
      temp: Directory('${dir.path}/temp'),
      loadString: (asset) async => File(asset).readAsStringSync(),
      unpack: _unpack,
    );
  });

  tearDown(() async {
    await translations.close();
    await tafsir.close();
    await wbw.close();
    dir.deleteSync(recursive: true);
  });

  Future<int> verses(String slug) async =>
      (await translations
              .customSelect(
                'SELECT COUNT(*) AS n FROM translation_verses WHERE slug = ?',
                variables: [Variable(slug)],
              )
              .getSingle())
          .read<int>('n');

  test(
    'English and Arabic are there from the start; the rest packed',
    () async {
      expect(await store.installed(MeaningPackKind.translation), {'en-rowwad'});
      expect(await store.installed(MeaningPackKind.tafsir), {
        'en-mukhtasar',
        'ar-muyassar',
        'ar-seraj',
      });
      expect(await store.installed(MeaningPackKind.wbw), {'en-qurancom'});
      expect(await store.available(MeaningPackKind.translation), hasLength(17));
      // Every language's list is there, to choose from.
      final books = await translations
          .select(translations.translationBooks)
          .get();
      expect(books, hasLength(18));
    },
  );

  test('a language goes on, whole, and off again', () async {
    await store.install(MeaningPackKind.translation, 'de-rowwad');
    expect(await verses('de-rowwad'), 6236);
    await store.install(MeaningPackKind.wbw, 'fr-qurancom');
    expect(await store.installed(MeaningPackKind.wbw), {
      'en-qurancom',
      'fr-qurancom',
    });

    await store.remove(MeaningPackKind.translation, 'de-rowwad');
    expect(await verses('de-rowwad'), 0);
    // The built-in ones are never taken off.
    await store.remove(MeaningPackKind.translation, 'en-rowwad');
    expect(await verses('en-rowwad'), 6236);
    expect(Directory('${dir.path}/temp').listSync(), isEmpty);
  });

  test('installing again replaces it, not doubles it', () async {
    await store.install(MeaningPackKind.tafsir, 'fr-mukhtasar');
    await store.install(MeaningPackKind.tafsir, 'fr-mukhtasar');
    final n = await tafsir
        .customSelect(
          "SELECT COUNT(*) AS n FROM tafsir_verses WHERE tafsir_id = 'fr-mukhtasar'",
        )
        .getSingle();
    expect(n.read<int>('n'), greaterThan(0));
  });
}
