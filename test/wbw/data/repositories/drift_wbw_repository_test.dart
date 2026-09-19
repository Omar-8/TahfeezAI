import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/wbw/data/repositories/drift_wbw_repository.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';

import '../../wbw_test_fixtures.dart';

void main() {
  late WbwDatabase db;
  late DriftWbwRepository repo;

  setUp(() {
    db = WbwDatabase(NativeDatabase.memory());
    repo = DriftWbwRepository(db);
  });

  tearDown(() => db.close());

  test('getInstalledPacks is empty before any install', () async {
    expect(await repo.getInstalledPacks(), isEmpty);
  });

  test('installPack makes the pack and its words readable', () async {
    await repo.installPack(buildTestWbwPack(), buildTestWbwWords());

    final installed = await repo.getInstalledPacks();
    expect(installed, hasLength(1));
    expect(installed.single.id, testWbwPackId);
    expect(installed.single.version, 1);

    final word = await repo.getWord(
      packId: testWbwPackId,
      ayahId: 1001,
      wordIndex: 0,
    );
    expect(word?.translation, 'word');
    expect(word?.transliteration, 'lafz');
  });

  test('getWord returns null for a word the pack has no entry for', () async {
    await repo.installPack(buildTestWbwPack(), buildTestWbwWords());

    final word = await repo.getWord(
      packId: testWbwPackId,
      ayahId: 9999,
      wordIndex: 0,
    );
    expect(word, isNull);
  });

  test('re-installing with a newer version replaces the old words', () async {
    await repo.installPack(buildTestWbwPack(), buildTestWbwWords());

    await repo.installPack(buildTestWbwPack(version: 2), [
      for (final word in buildTestWbwWords())
        word.copyWith(translation: '${word.translation}-v2'),
    ]);

    final installed = await repo.getInstalledPack(testWbwPackId);
    expect(installed?.version, 2);

    final word = await repo.getWord(
      packId: testWbwPackId,
      ayahId: 1001,
      wordIndex: 0,
    );
    expect(word?.translation, 'word-v2');
    // Every verse's words reflect the new version's text, not a mix of old
    // and new rows left behind by a merge instead of a replace.
    for (var verseNo = 1; verseNo <= 7; verseNo++) {
      final ayahId = 1000 + verseNo;
      expect(
        (await repo.getWord(
          packId: testWbwPackId,
          ayahId: ayahId,
          wordIndex: 0,
        ))?.translation,
        'word-v2',
      );
      expect(
        (await repo.getWord(
          packId: testWbwPackId,
          ayahId: ayahId,
          wordIndex: 1,
        ))?.translation,
        'phrase-v2',
      );
    }
  });

  test('deletePack removes both the pack and its words', () async {
    await repo.installPack(buildTestWbwPack(), buildTestWbwWords());

    await repo.deletePack(testWbwPackId);

    expect(await repo.getInstalledPack(testWbwPackId), isNull);
    expect(
      await repo.getWord(packId: testWbwPackId, ayahId: 1001, wordIndex: 0),
      isNull,
    );
  });
}
