import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/browser_storage.dart';

/// Unpacks bundled [asset] (xz) into the file at [destination]; returns the
/// SHA-256 of what it wrote.
typedef DatabaseUnpacker = Future<String> Function(
  String asset,
  String destination,
);

/// Puts the app's ready-made Quran databases in place on the phone: unpacks
/// them from the bundle (assets/quran/db/, built by
/// `tool/quran_db/build_databases_test.dart`) where the databases open
/// (`openConnection`'s default: `<documents>/<name>.sqlite`) — at the first
/// start, and again when the app brings new ones.
///
/// Android only; elsewhere the bundled datasets are still imported
/// ([BundledDatasetSeeder]). Unpacking replaces that import on the phone:
/// nothing to decode or insert (it needed a lot of memory and time, and
/// failed on some phones). Android's own code unpacks (xz, streamed: little
/// memory, native speed); each database is checked against its hash before
/// it replaces the old one.
class BundledDatabaseInstaller {
  BundledDatabaseInstaller({
    required this.storage,
    required this.directory,
    required this.logger,
    Future<String> Function(String asset)? loadString,
    DatabaseUnpacker? unpack,
  }) : _loadString = loadString ?? rootBundle.loadString,
       _unpack = unpack ?? nativeUnpack;

  final BrowserStorage storage;

  /// Where the databases open.
  final Directory directory;
  final AppLogger logger;
  final Future<String> Function(String asset) _loadString;
  final DatabaseUnpacker _unpack;

  static const assetDir = 'assets/quran/db';
  static const names = ['quran', 'translations', 'tafsirs', 'wbw_resources'];

  /// The installed databases' version; kept by Reset all data.
  static const installedVersionKey = 'quran.db.installed_version';

  static const _channel = MethodChannel('tahfeez/bundled_db');

  /// Android's own code unpacking an xz asset (BundledDatabaseChannel.kt).
  static Future<String> nativeUnpack(String asset, String destination) async =>
      (await _channel.invokeMethod<String>('unpack', {
        'asset': asset,
        'dest': destination,
      }))!;

  /// Returns why the databases could not be put in place, `null` once they
  /// are (or already were).
  Future<String?> installIfNeeded() async {
    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(
        await _loadString('$assetDir/manifest.json'),
      ) as Map<String, dynamic>;
    } catch (e) {
      return "Could not read the Qur'an databases' manifest: $e";
    }
    final version = manifest['version'] as String;
    final databases = (manifest['databases'] as Map).cast<String, dynamic>();
    final installed = await storage.getString(installedVersionKey);
    if (installed == version &&
        names.every((n) => File(_path(n)).existsSync())) {
      return null;
    }
    try {
      directory.createSync(recursive: true);
      for (final name in names) {
        await _install(name, (databases[name] as Map).cast<String, dynamic>());
      }
    } catch (e, st) {
      logger.error(
        'Could not install the bundled Quran databases.',
        tag: 'BundledDatabaseInstaller',
        error: e,
        stackTrace: st,
      );
      return e is PlatformException ? '${e.message}' : '$e';
    }
    await storage.setString(installedVersionKey, version);
    logger.info(
      'Installed the bundled Quran databases ($version).',
      tag: 'BundledDatabaseInstaller',
    );
    return null;
  }

  String _path(String name) => '${directory.path}/$name.sqlite';

  Future<void> _install(String name, Map<String, dynamic> entry) async {
    final temp = File('${_path(name)}.part');
    final hash = await _unpack('$assetDir/${entry['asset']}', temp.path);
    if (hash != entry['sha256']) {
      if (temp.existsSync()) temp.deleteSync();
      throw StateError(
        '$name: the bundled database failed hash verification '
        '(expected ${entry['sha256']}, got $hash)',
      );
    }
    // The old one's journal would not match the new file.
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      final stale = File('${_path(name)}$suffix');
      if (stale.existsSync()) stale.deleteSync();
    }
    temp.renameSync(_path(name));
  }
}
