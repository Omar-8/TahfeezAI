import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/logging/logging_package_logger.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_database_installer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';

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

/// A bundle of tiny "databases" (their text standing for the unpacked file),
/// with the manifest the installer reads.
({String manifest, Map<String, String> assets}) _bundle(
  Map<String, String> contents, {
  String version = 'v1',
  bool badHash = false,
}) {
  final assets = <String, String>{};
  final databases = <String, Object>{};
  for (final MapEntry(key: name, value: text) in contents.entries) {
    assets['${BundledDatabaseInstaller.assetDir}/$name.sqlite.xz'] = text;
    databases[name] = {
      'sha256': badHash ? 'nope' : sha256.convert(utf8.encode(text)).toString(),
      'bytes': text.length,
      'asset': '$name.sqlite.xz',
    };
  }
  return (
    manifest: jsonEncode({'version': version, 'databases': databases}),
    assets: assets,
  );
}

void main() {
  late Directory dir;
  late _Memory storage;
  var unpacked = 0;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_install');
    storage = _Memory();
    unpacked = 0;
  });
  tearDown(() => dir.deleteSync(recursive: true));

  BundledDatabaseInstaller installer(
    ({String manifest, Map<String, String> assets}) bundle,
  ) => BundledDatabaseInstaller(
    storage: storage,
    directory: dir,
    logger: LoggingPackageLogger(),
    loadString: (_) async => bundle.manifest,
    unpack: (asset, destination) async {
      unpacked++;
      final text = bundle.assets[asset]!;
      File(destination).writeAsStringSync(text);
      return sha256.convert(utf8.encode(text)).toString();
    },
  );

  final contents = {
    for (final n in BundledDatabaseInstaller.names) n: 'the $n database',
  };

  test('unpacks each database into place', () async {
    expect(await installer(_bundle(contents)).installIfNeeded(), isNull);
    for (final n in BundledDatabaseInstaller.names) {
      expect(
        File('${dir.path}/$n.sqlite').readAsStringSync(),
        'the $n database',
      );
    }
    expect(storage.values[BundledDatabaseInstaller.installedVersionKey], 'v1');
  });

  test('installed already: nothing unpacked again', () async {
    await installer(_bundle(contents)).installIfNeeded();
    unpacked = 0;
    expect(await installer(_bundle(contents)).installIfNeeded(), isNull);
    expect(unpacked, 0);
  });

  test('a new version replaces the old, and its stale journal', () async {
    await installer(_bundle(contents)).installIfNeeded();
    File('${dir.path}/quran.sqlite-wal').writeAsStringSync('stale');
    final newer = {...contents, 'quran': 'the new quran database'};
    expect(
      await installer(_bundle(newer, version: 'v2')).installIfNeeded(),
      isNull,
    );
    expect(
      File('${dir.path}/quran.sqlite').readAsStringSync(),
      'the new quran database',
    );
    expect(File('${dir.path}/quran.sqlite-wal').existsSync(), isFalse);
    expect(storage.values[BundledDatabaseInstaller.installedVersionKey], 'v2');
  });

  test(
    'a database failing its hash is not installed; the failure says so',
    () async {
      final failure = await installer(_bundle(contents, badHash: true))
          .installIfNeeded();
      expect(failure, contains('hash verification'));
      expect(File('${dir.path}/quran.sqlite').existsSync(), isFalse);
      expect(storage.values, isEmpty);
    },
  );

  test('an unpacking that fails (a full phone) is the failure', () async {
    final failing = BundledDatabaseInstaller(
      storage: storage,
      directory: dir,
      logger: LoggingPackageLogger(),
      loadString: (_) async => _bundle(contents).manifest,
      unpack: (_, _) async => throw PlatformException(
        code: 'unpack',
        message: 'java.io.IOException: write failed: ENOSPC (No space left on device)',
      ),
    );
    expect(await failing.installIfNeeded(), contains('No space left'));
  });

  test(
    'the real bundle unpacks into the Quran',
    () async {
      // The databases tool/quran_db/build_databases_test.dart built, unpacked
      // by the xz tool as Android's code would.
      final real = BundledDatabaseInstaller(
        storage: storage,
        directory: dir,
        logger: LoggingPackageLogger(),
        loadString: (asset) async => File(asset).readAsStringSync(),
        unpack: (asset, destination) async {
          final out = await Process.run('xz', [
            '-d',
            '-c',
            asset,
          ], stdoutEncoding: null);
          final bytes = out.stdout as List<int>;
          File(destination).writeAsBytesSync(bytes);
          return sha256.convert(bytes).toString();
        },
      );
      expect(await real.installIfNeeded(), isNull);
      final db = QuranDatabase(
        NativeDatabase(File('${dir.path}/quran.sqlite')),
      );
      addTearDown(db.close);
      expect(await db.select(db.surahs).get(), hasLength(114));
      expect(await db.select(db.mushafTokens).get(), isNotEmpty);
    },
    skip: Process.runSync('which', ['xz']).exitCode != 0
        ? 'needs the xz tool'
        : false,
  );
}
