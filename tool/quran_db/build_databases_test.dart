// Builds the app's ready-made Quran databases from the bundled datasets
// (assets/quran/: the Quran text, the Mushaf layout, translations, tafsir,
// word meanings) — the same import the app used to run on the phone at its
// first start — into assets/quran/db/, with a manifest of their hashes:
// the Quran and the lists of translations, tafsirs and word meanings as
// databases, each one's text as a pack of its own (packs/).
// The app then only unpacks them (bundled_database_installer.dart).
// Needs `xz` on the PATH.
//
//   flutter test tool/quran_db/build_databases_test.dart
//
// Run it again whenever a dataset or a database's schema changes; the
// manifest's version changes with them, and the app installs the new ones.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/logging/logging_package_logger.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_database_installer.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';
import 'package:tahfeez_ai/quran/data/import/meaning_pack_store.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('build the ready-made Quran databases', () async {
    final out = Directory(BundledDatabaseInstaller.assetDir);
    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);
    final work = Directory.systemTemp.createTempSync('quran_db');

    File file(String name) => File('${work.path}/$name.sqlite');
    final quran = QuranDatabase(NativeDatabase(file('quran')));
    final translations = TranslationDatabase(
      NativeDatabase(file('translations')),
    );
    final tafsir = TafsirDatabase(NativeDatabase(file('tafsirs')));
    final wbw = WbwDatabase(NativeDatabase(file('wbw_resources')));
    final c = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => quran),
        translationDatabaseProvider.overrideWith((ref) => translations),
        tafsirDatabaseProvider.overrideWith((ref) => tafsir),
        wbwDatabaseProvider.overrideWith((ref) => wbw),
      ],
    );
    final failure = await BundledDatasetSeeder(
      quranRepository: c.read(quranRepositoryProvider),
      quranDatabase: quran,
      translationRepository: c.read(translationRepositoryProvider),
      tafsirRepository: c.read(tafsirRepositoryProvider),
      wbwRepository: c.read(wbwRepositoryProvider),
      logger: LoggingPackageLogger(),
      storage: _Memory(),
    ).seedIfNeeded();
    expect(failure, isNull);

    Future<List<int>> xz(String path) async {
      // xz at its standard level: about half what Play's compression
      // makes of them, and ~9 MB of memory to unpack.
      final run = await Process.run('xz', [
        '-6',
        '-T1',
        '-k',
        '-c',
        path,
      ], stdoutEncoding: null);
      expect(run.exitCode, 0, reason: '${run.stderr}');
      return run.stdout as List<int>;
    }

    // Each translation's, tafsir's and word-meaning set's text as its own
    // pack (a table `rows`, its columns in the database's order), unpacked
    // on the phone only while in use (meaning_pack_store.dart); the
    // databases keep their lists.
    final databases = <MeaningPackKind, GeneratedDatabase>{
      MeaningPackKind.translation: translations,
      MeaningPackKind.tafsir: tafsir,
      MeaningPackKind.wbw: wbw,
    };
    Directory('${out.path}/packs').createSync();
    final packs = <String, Object>{};
    for (final MapEntry(key: kind, value: db) in databases.entries) {
      final ofKind = <String, Object>{};
      for (final row in await db.customSelect(kind.meta).get()) {
        final id = row.data.values.first as String;
        if (kind.builtIn.contains(id)) continue;
        final pack = File('${work.path}/${kind.name}-$id.sqlite');
        await db.customStatement('ATTACH DATABASE ? AS pack', [pack.path]);
        await db.customStatement(
          'CREATE TABLE pack.rows AS SELECT * FROM ${kind.table} '
          'WHERE ${kind.key} = ?',
          [id],
        );
        await db.customStatement('DETACH DATABASE pack');
        final asset = 'packs/${kind.name}-$id.sqlite.xz';
        File('${out.path}/$asset').writeAsBytesSync(await xz(pack.path));
        ofKind[id] = {
          'sha256': sha256.convert(pack.readAsBytesSync()).toString(),
          'asset': asset,
        };
      }
      packs[kind.name] = ofKind;
      // (English's and Arabic's stay, ready from the start.)
      await db.customStatement(
        'DELETE FROM ${kind.table} WHERE ${kind.key} NOT IN '
        '(${kind.builtIn.map((id) => "'$id'").join(', ')})',
      );
    }

    // Compacted, shrinking as packs come off (auto_vacuum), and closed: one
    // self-contained file each.
    for (final db in <GeneratedDatabase>[quran, translations, tafsir, wbw]) {
      await db.customStatement('PRAGMA auto_vacuum = FULL');
      await db.customStatement('VACUUM');
      await db.close();
    }
    c.dispose();

    final files = <String, Object>{};
    for (final name in BundledDatabaseInstaller.names) {
      final db = file(name);
      final bytes = db.readAsBytesSync();
      final asset = '$name.sqlite.xz';
      File('${out.path}/$asset').writeAsBytesSync(await xz(db.path));
      files[name] = {
        'sha256': sha256.convert(bytes).toString(),
        'bytes': bytes.length,
        'asset': asset,
      };
    }
    // The version: what's inside them.
    final version = sha256
        .convert(utf8.encode(jsonEncode([files, packs])))
        .toString()
        .substring(0, 16);
    File('${out.path}/manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'version': version, 'databases': files, 'packs': packs})}\n',
    );
    work.deleteSync(recursive: true);
    // ignore: avoid_print
    print(
      'built $version: ${files.map((k, v) => MapEntry(k, (v as Map)['bytes']))}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// The seeder's markers, for this one run.
class _Memory implements BrowserStorage {
  final values = <String, Object?>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> clearExcept(Set<String> keep) async =>
      values.removeWhere((k, _) => !keep.contains(k));
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<void> writeAll(Map<String, Object?> v) async => values.addAll(v);
}
