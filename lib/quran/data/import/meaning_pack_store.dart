import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

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
/// the device and taken off again — the rest stays packed in the app
/// (assets/quran/db/packs/: built by `tool/quran_db/build_databases_test
/// .dart`), so the phone keeps ~20 MB of them rather than ~120. How a pack
/// goes on is the platform's: [UnpackingMeaningPackStore] on the phones,
/// [ImportingMeaningPackStore] on the web.
abstract class MeaningPackStore {
  MeaningPackStore({required this.databases, required this.loadString});

  /// Each kind's database.
  final Map<MeaningPackKind, GeneratedDatabase> databases;
  final Future<String> Function(String asset) loadString;

  Map<String, dynamic>? _manifest;

  Future<Map<String, dynamic>> _packs() async => _manifest ??=
      ((jsonDecode(
                await loadString(
                  '${BundledDatabaseInstaller.assetDir}/manifest.json',
                ),
              ) as Map<String, dynamic>)['packs']
              as Map)
          .cast<String, dynamic>();

  /// The packs of [kind] in the app.
  Future<Set<String>> available(MeaningPackKind kind) async => {
    ...?((await _packs())[kind.name] as Map?)?.keys.cast<String>(),
  };

  /// The packs of [kind] whose text is on the phone.
  Future<Set<String>> installed(MeaningPackKind kind) async {
    final rows = await databases[kind]!
        .customSelect('SELECT DISTINCT ${kind.key} AS id FROM ${kind.table}')
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Puts [id]'s text on the device.
  Future<void> install(MeaningPackKind kind, String id);

  /// Takes [id]'s text off the phone (the database shrinks: auto_vacuum);
  /// never a built-in one.
  Future<void> remove(MeaningPackKind kind, String id) async {
    if (kind.builtIn.contains(id)) return;
    await databases[kind]!.customStatement(
      'DELETE FROM ${kind.table} WHERE ${kind.key} = ?',
      [id],
    );
  }
}

/// The phones': a pack (xz) is unpacked by the platform's own code
/// (BundledDatabaseInstaller's), checked against its hash, and copied in by
/// SQLite itself (ATTACH, INSERT … SELECT): quick, and little memory.
class UnpackingMeaningPackStore extends MeaningPackStore {
  UnpackingMeaningPackStore({
    required super.databases,
    required this.temp,
    required super.loadString,
    required this.unpack,
  });

  /// Where a pack is unpacked before it's copied in.
  final Directory temp;

  /// (The platform's, in the app: BundledDatabaseInstaller.nativeUnpack.)
  final DatabaseUnpacker unpack;

  @override
  Future<void> install(MeaningPackKind kind, String id) async {
    final entry =
        ((await _packs())[kind.name] as Map?)?[id] as Map<String, dynamic>?;
    if (entry == null) throw StateError('No ${kind.name} pack $id in the app');
    temp.createSync(recursive: true);
    final file = File('${temp.path}/${kind.name}-$id.sqlite');
    try {
      final hash = await unpack(
        '${BundledDatabaseInstaller.assetDir}/${entry['asset']}',
        file.path,
      );
      if (hash != entry['sha256']) {
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
