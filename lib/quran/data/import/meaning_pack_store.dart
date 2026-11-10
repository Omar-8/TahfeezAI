import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show PlatformException;

import 'bundled_database_installer.dart';

/// What a meaning pack holds: a translation's, a tafsir's or a word-meaning
/// set's text — the rows of [table] whose [key] is the pack's id. The lists
/// of them ([meta]) stay in the ready-made databases; their text comes and
/// goes ([MeaningPackStore]).
enum MeaningPackKind {
  translation(
    'translation_verses',
    'slug',
    'SELECT slug FROM translation_books',
  ),
  tafsir('tafsir_verses', 'tafsir_id', 'SELECT id FROM tafsir_works'),
  wbw('wbw_words', 'pack_id', 'SELECT id FROM wbw_packs');

  const MeaningPackKind(this.table, this.key, this.meta);

  final String table;
  final String key;

  /// Every pack of this kind in the bundle (one column: its id).
  final String meta;

  /// English's and Arabic's, ready from the first start and always kept:
  /// built into the databases, not packed.
  Set<String> get builtIn => switch (this) {
    translation => const {'en-rowwad'},
    tafsir => const {'en-mukhtasar', 'ar-muyassar', 'ar-seraj'},
    wbw => const {'en-qurancom'},
  };
}

/// The text of the translations, tafsirs and word meanings in use, put on
/// the device and taken off again. The packs (built by
/// `tool/quran_db/build_databases_test.dart`) are downloaded on the phones
/// ([DownloadingMeaningPackStore]; ~25 MB the app no longer carries) and
/// imported from the app's JSON on the web ([ImportingMeaningPackStore]).
abstract class MeaningPackStore {
  MeaningPackStore({required this.databases, required this.loadString});

  /// Each kind's database.
  final Map<MeaningPackKind, GeneratedDatabase> databases;
  final Future<String> Function(String asset) loadString;

  Map<String, dynamic>? _manifest;

  Future<Map<String, dynamic>> _read() async => _manifest ??= jsonDecode(
    await loadString('${BundledDatabaseInstaller.assetDir}/manifest.json'),
  ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> _packs() async =>
      ((await _read())['packs'] as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>?> _entry(MeaningPackKind kind, String id) async =>
      ((await _packs())[kind.name] as Map?)?[id] as Map<String, dynamic>?;

  /// Whether a pack going on is a download (it may wait for the network;
  /// nothing is dimmed meanwhile) rather than an import from the app.
  bool get downloads => false;

  /// The packs of [kind] there are.
  Future<Set<String>> available(MeaningPackKind kind) async => {
    ...?((await _packs())[kind.name] as Map?)?.keys.cast<String>(),
  };

  /// [id]'s download, in bytes (`null` if it isn't one).
  Future<int?> downloadBytes(MeaningPackKind kind, String id) async =>
      (await _entry(kind, id))?['xzBytes'] as int?;

  /// The packs of [kind] whose text is on the device.
  Future<Set<String>> installed(MeaningPackKind kind) async {
    final rows = await databases[kind]!
        .customSelect('SELECT DISTINCT ${kind.key} AS id FROM ${kind.table}')
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Puts [id]'s text on the device.
  Future<void> install(MeaningPackKind kind, String id);

  /// Takes [id]'s text off the device (the database shrinks: auto_vacuum);
  /// never a built-in one.
  Future<void> remove(MeaningPackKind kind, String id) async {
    if (kind.builtIn.contains(id)) return;
    await databases[kind]!.customStatement(
      'DELETE FROM ${kind.table} WHERE ${kind.key} = ?',
      [id],
    );
  }
}

/// A pack couldn't be downloaded: no network (or none that answers). It's
/// tried again when the phone is back online.
class MeaningPackOffline implements Exception {
  const MeaningPackOffline(this.cause);

  final Object cause;

  @override
  String toString() => 'Offline: $cause';
}

/// Downloads [url] to the file at [path] (throws [MeaningPackOffline] when
/// there's no network).
typedef MeaningPackFetch = Future<void> Function(Uri url, String path);

/// Unpacks the xz file at [file] into [destination]; returns the SHA-256 of
/// what it wrote (the app: BundledDatabaseInstaller.nativeUnpackFile).
typedef MeaningPackUnpacker = Future<String> Function(
  String file,
  String destination,
);

/// The phones': a pack (xz) is downloaded from the release named after the
/// databases' version (`meaning-packs-<version>`: the files that match
/// them; tool/quran_db/publish_meaning_packs.sh), kept ([cache]: deleted
/// with the pack), unpacked by the platform's own code, checked against its
/// hash, and copied in by SQLite itself (ATTACH, INSERT … SELECT): quick,
/// and little memory.
class DownloadingMeaningPackStore extends MeaningPackStore {
  DownloadingMeaningPackStore({
    required super.databases,
    required super.loadString,
    required this.temp,
    required this.cache,
    required this.fetch,
    required this.unpack,
    this.baseUrl = defaultBaseUrl,
  });

  /// Where the packs are published (a GitHub release per version).
  static const defaultBaseUrl =
      'https://github.com/Omar-8/TahfeezAI/releases/download';

  /// Where a pack is unpacked before it's copied in.
  final Directory temp;

  /// Where the downloaded packs are kept (each until it's deleted: put on
  /// again — the databases replaced by a new version — without a download).
  final Directory cache;

  final MeaningPackFetch fetch;
  final MeaningPackUnpacker unpack;
  final String baseUrl;

  @override
  bool get downloads => true;

  Future<Uri> url(MeaningPackKind kind, String id) async {
    final entry = await _entry(kind, id);
    if (entry == null) throw StateError('No ${kind.name} pack $id');
    final version = (await _read())['version'];
    final name = (entry['asset'] as String).split('/').last;
    return Uri.parse('$baseUrl/meaning-packs-$version/$name');
  }

  File _cached(Map<String, dynamic> entry) =>
      File('${cache.path}/${(entry['asset'] as String).split('/').last}');

  @override
  Future<void> install(MeaningPackKind kind, String id) async {
    final entry = await _entry(kind, id);
    if (entry == null) throw StateError('No ${kind.name} pack $id');
    final packed = _cached(entry);
    temp.createSync(recursive: true);
    final file = File('${temp.path}/${kind.name}-$id.sqlite');
    try {
      var fresh = false;
      Future<void> download() async {
        cache.createSync(recursive: true);
        final part = File('${packed.path}.part');
        await fetch(await url(kind, id), part.path);
        part.renameSync(packed.path);
        fresh = true;
      }

      if (!packed.existsSync()) await download();
      var hash = await _unpackChecked(packed.path, file.path);
      if (hash != entry['sha256'] && !fresh) {
        // A kept copy of another version's (or damaged): downloaded anew.
        packed.deleteSync();
        await download();
        hash = await _unpackChecked(packed.path, file.path);
      }
      if (hash != entry['sha256']) {
        packed.deleteSync();
        throw StateError(
          '${kind.name} pack $id failed hash verification '
          '(expected ${entry['sha256']}, got $hash)',
        );
      }
      final db = databases[kind]!;
      await db.customStatement('ATTACH DATABASE ? AS pack', [file.path]);
      try {
        await db.transaction(() async {
          // (Again, from scratch: a half-copied one is replaced.)
          await db.customStatement(
            'DELETE FROM ${kind.table} WHERE ${kind.key} = ?',
            [id],
          );
          await db.customStatement(
            'INSERT INTO ${kind.table} SELECT * FROM pack.rows',
          );
        });
      } finally {
        await db.customStatement('DETACH DATABASE pack');
      }
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// (Not xz at all — a damaged download — counts as a wrong hash.)
  Future<String> _unpackChecked(String from, String to) async {
    try {
      return await unpack(from, to);
    } on PlatformException catch (e) {
      return 'unpack failed: ${e.message}';
    }
  }

  @override
  Future<void> remove(MeaningPackKind kind, String id) async {
    if (kind.builtIn.contains(id)) return;
    await super.remove(kind, id);
    final entry = await _entry(kind, id);
    if (entry == null) return;
    final packed = _cached(entry);
    if (packed.existsSync()) packed.deleteSync();
  }
}

/// The web's: no file to attach, so a pack's text is imported from its
/// JSON asset (the same text the pack holds; `BundledDatasetSeeder
/// .importPack`).
class ImportingMeaningPackStore extends MeaningPackStore {
  ImportingMeaningPackStore({
    required super.databases,
    required super.loadString,
    required this.import,
  });

  final Future<void> Function(MeaningPackKind kind, String id) import;

  @override
  Future<void> install(MeaningPackKind kind, String id) async {
    if (!(await available(kind)).contains(id)) {
      throw StateError('No ${kind.name} pack $id in the app');
    }
    await import(kind, id);
  }
}
