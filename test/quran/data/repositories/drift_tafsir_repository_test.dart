import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/downloads/resource_integrity.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_tafsir_repository.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';

import '../../translation_tafsir_test_fixtures.dart';

void main() {
  late TafsirDatabase db;
  late DriftTafsirRepository repo;

  setUp(() {
    db = TafsirDatabase(NativeDatabase.memory());
    repo = DriftTafsirRepository(db);
  });

  tearDown(() => db.close());

  test('getInstalledTafsirs is empty before any install', () async {
    expect(await repo.getInstalledTafsirs(), isEmpty);
  });

  test('installTafsir makes the work and its verses readable', () async {
    await repo.installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    final installed = await repo.getInstalledTafsirs();
    expect(installed, hasLength(1));
    expect(installed.single.id, testTafsirId);

    final verse = await repo.getVerseText((
      chapterNo: 1,
      verseNo: 1,
    ), tafsirId: testTafsirId);
    expect(verse?.text, contains('verse 1'));
  });

  test(
    'installTafsir rejects a payload whose checksum does not match',
    () async {
      final work = buildTestTafsirWork();
      final tamperedVerses = [
        for (final v in buildTestTafsirVerses())
          v.copyWith(text: '${v.text} (tampered)'),
      ];

      await expectLater(
        repo.installTafsir(work, tamperedVerses),
        throwsA(isA<ResourceChecksumMismatchException>()),
      );
      expect(await repo.getInstalledTafsir(testTafsirId), isNull);
    },
  );

  test('installTafsir rejects an unsupported format version', () async {
    final work = buildTestTafsirWork().copyWith(formatVersion: 999);

    await expectLater(
      repo.installTafsir(work, buildTestTafsirVerses()),
      throwsA(isA<ResourceFormatVersionException>()),
    );
  });

  test('deletePack removes both the work and its verses', () async {
    await repo.installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    await repo.deleteTafsir(testTafsirId);

    expect(await repo.getInstalledTafsir(testTafsirId), isNull);
    expect(
      await repo.getVerseText((
        chapterNo: 1,
        verseNo: 1,
      ), tafsirId: testTafsirId),
      isNull,
    );
  });
}
