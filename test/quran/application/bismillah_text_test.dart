import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/application/bismillah_text.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../quran_test_fixtures.dart';

void main() {
  test('returns null with no Quran dataset installed', () async {
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(bismillahTextProvider.future), isNull);
  });

  test(
    "resolves to Al-Fatiha's own ayah 1 text -- the Bismillah's real, "
    'canonical source, never a literal string written into a widget',
    () async {
      final db = QuranDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await const QuranDatasetImporter().import(
        db,
        buildValidSyntheticPayload(),
      );
      final container = ProviderContainer(
        overrides: [
          quranDatabaseProvider.overrideWith((ref) => db),
          quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(quranRepositoryProvider);
      final ayah1Words = await repository.getWordsForAyah(
        1001,
        scriptCode: testScriptCode,
      );
      final expected = ayah1Words.map((w) => w.text).join(' ');

      expect(await container.read(bismillahTextProvider.future), expected);
    },
  );
}
