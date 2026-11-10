import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/logging_package_logger.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_tafsir_repository.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_translation_repository.dart';
import 'package:tahfeez_ai/wbw/data/repositories/drift_wbw_repository.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';

import '../../../test_helpers/memory_storage.dart';

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
  final fetched = <Uri>[];
  var offline = false;
  File cached(String name) => File('${dir.path}/cache/$name.sqlite.xz');

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
    fetched.clear();
    offline = false;
    store = DownloadingMeaningPackStore(
      databases: {
        MeaningPackKind.translation: translations,
        MeaningPackKind.tafsir: tafsir,
        MeaningPackKind.wbw: wbw,
      },
      temp: Directory('${dir.path}/temp'),
      cache: Directory('${dir.path}/cache'),
      loadString: (asset) async => File(asset).readAsStringSync(),
      // The release: the app's own pack files, as published.
      fetch: (url, path) async {
        if (offline) throw const MeaningPackOffline('no network');
        fetched.add(url);
        File('assets/quran/db/packs/${url.pathSegments.last}').copySync(path);
      },
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
      expect(await store.available(MeaningPackKind.translation), hasLength(24));
      // Every language's list is there, to choose from.
      final books = await translations
          .select(translations.translationBooks)
          .get();
      expect(books, hasLength(25));
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

  test('a pack is downloaded from the release of the databases\' version, '
      'and kept until it comes off', () async {
    final version = (jsonDecode(
      File('assets/quran/db/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>)['version'];
    await store.install(MeaningPackKind.translation, 'fr-noor');
    expect(fetched, [
      Uri.parse(
        'https://github.com/Omar-8/TahfeezAI/releases/download/'
        'meaning-packs-$version/translation-fr-noor.sqlite.xz',
      ),
    ]);
    expect(await verses('fr-noor'), 6236);
    expect(cached('translation-fr-noor').existsSync(), isTrue);
    expect(Directory('${dir.path}/temp').listSync(), isEmpty);

    await store.remove(MeaningPackKind.translation, 'fr-noor');
    expect(await verses('fr-noor'), 0);
    expect(cached('translation-fr-noor').existsSync(), isFalse);
  });

  test('its text gone (the databases replaced by a new version): put on '
      'again from the kept copy, no download', () async {
    await store.install(MeaningPackKind.tafsir, 'fr-mukhtasar');
    await tafsir.customStatement(
      "DELETE FROM tafsir_verses WHERE tafsir_id = 'fr-mukhtasar'",
    );
    offline = true;
    await store.install(MeaningPackKind.tafsir, 'fr-mukhtasar');
    expect(fetched, hasLength(1));
    expect(
      await store.installed(MeaningPackKind.tafsir),
      contains('fr-mukhtasar'),
    );
  });

  test('a kept copy that fails its hash: downloaded anew', () async {
    await store.install(MeaningPackKind.wbw, 'fr-qurancom');
    await store.remove(MeaningPackKind.wbw, 'fr-qurancom');
    // Another version's (or damaged).
    cached('wbw-fr-qurancom')
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        File('assets/quran/db/packs/wbw-tr-qurancom.sqlite.xz')
            .readAsBytesSync(),
      );
    await store.install(MeaningPackKind.wbw, 'fr-qurancom');
    expect(fetched, hasLength(2));
    expect(await store.installed(MeaningPackKind.wbw), contains('fr-qurancom'));
  });

  test('a download that fails its hash: not installed, not kept', () async {
    final bad = DownloadingMeaningPackStore(
      databases: {MeaningPackKind.translation: translations},
      temp: Directory('${dir.path}/temp'),
      cache: Directory('${dir.path}/cache'),
      loadString: (asset) async => File(asset).readAsStringSync(),
      fetch: (url, path) async =>
          File('assets/quran/db/packs/translation-de-rowwad.sqlite.xz')
              .copySync(path),
      unpack: _unpack,
    );
    await expectLater(
      bad.install(MeaningPackKind.translation, 'fr-noor'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('hash verification'),
        ),
      ),
    );
    expect(await verses('fr-noor'), 0);
    expect(cached('translation-fr-noor').existsSync(), isFalse);
  });

  test('no network: nothing installed, and it says so', () async {
    offline = true;
    await expectLater(
      store.install(MeaningPackKind.translation, 'fr-noor'),
      throwsA(isA<MeaningPackOffline>()),
    );
    expect(await verses('fr-noor'), 0);
    expect(Directory('${dir.path}/temp').listSync(), isEmpty);
  });

  test("every pack's download size is in the manifest (the lists show it; "
      'the publish tool checks the release against it)', () async {
    for (final kind in MeaningPackKind.values) {
      for (final id in await store.available(kind)) {
        final bytes = await store.downloadBytes(kind, id);
        expect(
          bytes,
          File('assets/quran/db/packs/${kind.name}-$id.sqlite.xz').lengthSync(),
          reason: id,
        );
      }
    }
    expect(store.downloads, isTrue);
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

  group("the web's: a pack imported from its JSON asset", () {
    late QuranDatabase quran;
    late MeaningPackStore web;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      quran = QuranDatabase(NativeDatabase.memory());
      final seeder = BundledDatasetSeeder(
        quranRepository: DriftQuranRepository(quran),
        quranDatabase: quran,
        translationRepository: DriftTranslationRepository(translations),
        tafsirRepository: DriftTafsirRepository(tafsir),
        wbwRepository: DriftWbwRepository(wbw),
        logger: LoggingPackageLogger(),
        storage: MemoryStorage(),
      );
      web = ImportingMeaningPackStore(
        databases: {
          MeaningPackKind.translation: translations,
          MeaningPackKind.tafsir: tafsir,
          MeaningPackKind.wbw: wbw,
        },
        loadString: rootBundle.loadString,
        import: seeder.importPack,
      );
    });

    tearDown(() => quran.close());

    test('every pack in the app has its JSON, hashed', () async {
      final hashes =
          (jsonDecode(
                await rootBundle.loadString(
                  'assets/quran/resource_manifest.json',
                ),
              ) as Map<String, dynamic>)['packagedAssetHashes']
              as Map<String, dynamic>;
      for (final kind in MeaningPackKind.values) {
        final dir = switch (kind) {
          MeaningPackKind.translation => 'translations',
          MeaningPackKind.tafsir => 'tafsir',
          MeaningPackKind.wbw => 'wbw',
        };
        for (final id in await web.available(kind)) {
          final key = '$dir/${id.replaceAll('-', '_')}.json';
          expect(hashes, contains(key), reason: '$id has no hash');
          expect(File('assets/quran/$key').existsSync(), isTrue, reason: key);
        }
      }
    });

    test('a language goes on, whole, as the phone\'s pack would', () async {
      await web.install(MeaningPackKind.translation, 'de-rowwad');
      expect(await verses('de-rowwad'), 6236);
      await web.install(MeaningPackKind.wbw, 'fr-qurancom');
      await web.install(MeaningPackKind.tafsir, 'fr-mukhtasar');
      expect(await web.installed(MeaningPackKind.wbw), {
        'en-qurancom',
        'fr-qurancom',
      });
      expect(
        await web.installed(MeaningPackKind.tafsir),
        contains('fr-mukhtasar'),
      );
      // Off and on again: whole again (its list entry stayed meanwhile).
      await web.remove(MeaningPackKind.translation, 'de-rowwad');
      expect(await verses('de-rowwad'), 0);
      await web.install(MeaningPackKind.translation, 'de-rowwad');
      expect(await verses('de-rowwad'), 6236);
    });
  });
}
