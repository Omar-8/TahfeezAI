import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_quran_repository.dart';

import '../multi_script_test_fixtures.dart';

/// Proves Milestone 8's "scripts are swappable without UI rewrites"
/// requirement at the repository layer: the same ayah, read through two
/// different installed scripts, resolves to different word text and a
/// different Mushaf with a different page count/pagination — entirely
/// driven by which `scriptCode` a caller passes, no code branching per
/// script.
void main() {
  late QuranDatabase db;
  late DriftQuranRepository repo;

  setUp(() async {
    db = QuranDatabase(NativeDatabase.memory());
    repo = DriftQuranRepository(db);
    await const QuranDatasetImporter().import(
      db,
      buildMultiScriptSyntheticPayload(),
    );
  });

  tearDown(() => db.close());

  test('getAllScripts returns both installed scripts', () async {
    final scripts = await repo.getAllScripts();
    expect(scripts.map((s) => s.code).toSet(), {
      multiScriptACode,
      multiScriptBCode,
    });
  });

  test('the same ayah resolves different word text per script', () async {
    final wordsA = await repo.getWordsForAyah(
      1001,
      scriptCode: multiScriptACode,
    );
    final wordsB = await repo.getWordsForAyah(
      1001,
      scriptCode: multiScriptBCode,
    );

    expect(wordsA.map((w) => w.text), ['lafz', 'kalima']);
    expect(wordsB.map((w) => w.text), ['harf', 'baab']);
  });

  test(
    'each script resolves to its own Mushaf with its own page count',
    () async {
      final mushafA = await repo.getMushaf(scriptCode: multiScriptACode);
      final mushafB = await repo.getMushaf(scriptCode: multiScriptBCode);

      expect(mushafA?.pageCount, 1);
      expect(mushafB?.pageCount, 2);
    },
  );

  test('the same ayah range lands on a different page per script', () async {
    final pageInA = await repo.getPageForAyah(
      mushafId: multiScriptAMushafId,
      ayahId: 1005,
    );
    final pageInB = await repo.getPageForAyah(
      mushafId: multiScriptBMushafId,
      ayahId: 1005,
    );

    expect(pageInA, 1);
    expect(pageInB, 2);
  });
}
