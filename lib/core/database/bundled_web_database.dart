import 'dart:convert';
import 'dart:js_interop';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

/// The web's ready-made Quran databases — the same files the phones unpack
/// (`assets/quran/db/`, `BundledDatabaseInstaller`): each opens under its
/// bundle's version (`quran_<version>`), started from the bundled copy the
/// first time — inflated by the browser itself, then checked against its
/// SHA-256 — so nothing is imported row by row. A new app version brings
/// new ones, under new names; the old ones are deleted once the app is up
/// ([deleteStaleBundledWebDatabases]).
QueryExecutor? openBundledWebDatabase(String name) {
  if (!_names.contains(name)) return null;
  return DatabaseConnection.delayed(
    Future(() async {
      final manifest = await _manifest;
      final entry = (manifest['databases'] as Map)[name] as Map;
      final result = await WasmDatabase.open(
        databaseName: '${name}_${manifest['version']}',
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
        initializeDatabase: () => _unpack(name, entry.cast<String, Object?>()),
      );
      return result.resolvedExecutor;
    }),
  );
}

/// The ready-made databases of earlier versions (and the imported ones of
/// the web builds before them), deleted.
Future<void> deleteStaleBundledWebDatabases() async {
  final version = (await _manifest)['version'];
  final probe = await WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  for (final existing in probe.existingDatabases) {
    final (_, name) = existing;
    final stale = _names.any(
      (n) => name == n || (name.startsWith('${n}_') && name != '${n}_$version'),
    );
    if (stale) await probe.deleteDatabase(existing);
  }
}

const _assetDir = 'assets/quran/db';
const _names = {'quran', 'translations', 'tafsirs', 'wbw_resources'};

final Future<Map<String, dynamic>> _manifest = rootBundle
    .loadString('$_assetDir/manifest.json')
    .then((s) => jsonDecode(s) as Map<String, dynamic>);

Future<Uint8List> _unpack(String name, Map<String, Object?> entry) async {
  final packed = (await rootBundle.load('$_assetDir/${entry['asset']}')).buffer
      .asUint8List();
  // zlib (RFC 1950): the browser's "deflate".
  final inflated = web.Blob([packed.toJS].toJS).stream().pipeThrough(
    web.DecompressionStream('deflate') as web.ReadableWritablePair,
  );
  final bytes = (await web.Response(
    inflated,
  ).arrayBuffer().toDart).toDart.asUint8List();
  final digest =
      (await web.window.crypto.subtle.digest('SHA-256'.toJS, bytes.toJS).toDart
              as JSArrayBuffer)
          .toDart
          .asUint8List();
  final hash = [for (final b in digest) b.toRadixString(16).padLeft(2, '0')]
      .join();
  if (hash != entry['sha256']) {
    throw StateError(
      '$name: the bundled database failed hash verification '
      '(expected ${entry['sha256']}, got $hash)',
    );
  }
  return bytes;
}
