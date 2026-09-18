import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/database/app_database.dart';

void main() {
  test('AppDatabase can write and read a key/value row end-to-end', () async {
    // An in-memory NativeDatabase stands in for the platform-specific
    // executor `openAppDatabase()` would resolve via drift_flutter; the
    // point of this test is to prove the generated Drift table/DAO code
    // and schema actually work at runtime, not just compile.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.keyValueEntries)
        .insert(
          KeyValueEntriesCompanion.insert(key: 'greeting', value: 'salam'),
        );

    final row = await (db.select(
      db.keyValueEntries,
    )..where((tbl) => tbl.key.equals('greeting'))).getSingle();

    expect(row.value, 'salam');
  });
}
