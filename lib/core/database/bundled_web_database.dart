import 'dart:convert';
import 'dart:js_interop';

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web/web.dart' as web;

/// Every database of the web app, opened through one browser check and its
/// workers ([_probe]) — not drift's own `WasmDatabase.open` per database,
/// which checked the browser again for each, starting new workers and
/// loading SQLite once more every time: 6–7 times, one after another, ~1 s
/// each on a phone before the home screen had its data (owner, 2026-11-07:
/// "waiting so long … before the app started").
///
/// The ready-made Quran databases ([_names]) — the same files the phones
/// unpack (`assets/quran/db/`, `BundledDatabaseInstaller`): each opens
/// under its bundle's version (`quran_<version>`), started from the bundled
/// copy the first time — inflated by the browser itself, then checked
/// against its SHA-256 — so nothing is imported row by row. A new app
/// version brings new ones, under new names; the old ones are deleted once
/// the app is up ([deleteStaleBundledWebDatabases]). The others (the
/// reader's own data) open as drift_flutter opened them: same names, same
/// storage.
///
/// Each starts opening as soon as it is made — not at its first query, as
/// before (one after another, as the screens asked) — all side by side,
/// after the Quran's own (the splash waits for it; a first visit's
/// downloads not slowed by the others').
QueryExecutor? openBundledWebDatabase(String name) {
  final Future<DatabaseConnection> connection;
  if (name == 'quran') {
    connection = _quranOpening = _start(name);
  } else {
    final quran = _quranOpening;
    connection = quran == null
        ? _start(name)
        : quran
              .then<void>((_) {}, onError: (Object _) {})
              .then((_) => _start(name));
  }
  return DatabaseConnection.delayed(connection);
}

/// The Quran's database being opened (bootstrap makes it first).
Future<DatabaseConnection>? _quranOpening;

Future<DatabaseConnection> _start(String name) async {
  if (!_names.contains(name)) return _open(name, null);
  final manifest = await _manifest;
  final entry = (manifest['databases'] as Map)[name] as Map;
  return _open(
    '${name}_${manifest['version']}',
    () => _unpack(name, entry.cast<String, Object?>()),
  );
}

/// The browser checked: once for the tidying ([_probe]), and once for each
/// database — its own workers, so the databases are set up side by side
/// (through one check's worker they were set up one after another).
Future<WasmProbeResult> _newProbe() => WasmDatabase.probe(
  sqlite3Uri: Uri.parse('sqlite3.wasm'),
  driftWorkerUri: Uri.parse('drift_worker.js'),
);

final Future<WasmProbeResult> _probe = _newProbe();

/// [name] opened as `WasmDatabase.open` would: the best storage the browser
/// has — or, for a database already stored, the storage it is in.
Future<DatabaseConnection> _open(
  String name,
  Future<Uint8List> Function()? initialize,
) async {
  final probed = await _newProbe();
  final available = probed.availableStorages.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  var chosen = available.isEmpty
      ? WasmStorageImplementation.inMemory
      : available.first;
  for (final (location, existing) in probed.existingDatabases) {
    if (existing != name) continue;
    final forIt = switch (location) {
      WebStorageApi.indexedDb => const [
        WasmStorageImplementation.sharedIndexedDb,
        WasmStorageImplementation.unsafeIndexedDb,
      ],
      WebStorageApi.opfs => const [
        WasmStorageImplementation.opfsShared,
        WasmStorageImplementation.opfsLocks,
      ],
    };
    final usable = available.where(forIt.contains);
    if (usable.isNotEmpty) {
      chosen = usable.first;
      break;
    }
  }
  return probed.open(chosen, name, initializeDatabase: initialize);
}

/// The ready-made databases of earlier versions (and the imported ones of
/// the web builds before them), deleted.
Future<void> deleteStaleBundledWebDatabases() async {
  final version = (await _manifest)['version'];
  final probe = await _probe;
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
