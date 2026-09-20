// Reproduces the real bug a physical device hit: `adb install -r` preserves
// the on-disk SQLite file across reinstalls, so a device that ever ran an
// app build predating the MushafTokens table (and the new Mushafs/
// MushafLines columns) had a stale schema on disk. `QuranDatabase` never
// bumped `schemaVersion` when those were added, so Drift never attempted
// any migration and every subsequent Mushaf import threw against the
// missing table/columns — silently, because logging output wasn't wired to
// any visible sink either (see `logging_package_logger.dart`).
//
// This test builds a real file-backed database matching that stale,
// pre-Mushaf-token schema (schema_version pragma left at 1), then reopens
// it with the current `QuranDatabase` and proves the destructive
// createAll-based migration in `QuranDatabase.migration` brings it up to
// the current schema without throwing.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:tahfeez_ai/quran/data/quran_database.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('quran_db_migration_test');
    dbFile = File('${tempDir.path}/quran.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('opening a stale pre-MushafTokens on-disk database migrates cleanly '
      'instead of leaving the new table/columns missing', () async {
    // Simulate a database left behind by an older app build: the old
    // Mushafs/MushafLines shape (no qiraah/edition/renderingType, no
    // firstTokenId/lastTokenId), no mushaf_tokens table at all, and the
    // schema version pragma still at 1 — exactly what an old install
    // would have on disk.
    final rawDb = sqlite3.sqlite3.open(dbFile.path);
    rawDb.execute('''
        CREATE TABLE mushafs (
          id INTEGER NOT NULL PRIMARY KEY,
          code TEXT NOT NULL UNIQUE,
          script_id INTEGER NOT NULL,
          script_variant_id INTEGER,
          page_count INTEGER NOT NULL,
          lines_per_page INTEGER NOT NULL
        );
        PRAGMA user_version = 1;
      ''');
    rawDb.close();

    // Reopen with the CURRENT QuranDatabase (schemaVersion 2, with the
    // destructive drop-and-recreate migration). This must not throw, and
    // must leave every current table (including mushaf_tokens, and the
    // new Mushafs/MushafLines columns) usable.
    final quranDb = QuranDatabase(NativeDatabase(dbFile));
    addTearDown(quranDb.close);

    // Would throw "no such table: mushaf_tokens" before the fix.
    final tokenCount = await quranDb
        .customSelect('SELECT COUNT(*) AS c FROM mushaf_tokens')
        .getSingle();
    expect(tokenCount.data['c'], 0);

    // Would throw "table mushafs has no column named qiraah" before the
    // fix — proves the new Mushafs columns exist post-migration too.
    final mushafColumns = await quranDb
        .customSelect('PRAGMA table_info(mushafs)')
        .get();
    final columnNames = mushafColumns
        .map((row) => row.data['name'] as String)
        .toSet();
    expect(
      columnNames,
      containsAll(<String>['qiraah', 'edition', 'rendering_type']),
    );

    final version = await quranDb
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data['user_version'], 2);
  });
}
