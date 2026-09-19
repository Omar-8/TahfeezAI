import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/downloads/resource_integrity.dart';
import 'package:tahfeez_ai/quran/data/repositories/drift_translation_repository.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';

import '../../translation_tafsir_test_fixtures.dart';

void main() {
  late TranslationDatabase db;
  late DriftTranslationRepository repo;

  setUp(() {
    db = TranslationDatabase(NativeDatabase.memory());
    repo = DriftTranslationRepository(db);
  });

  tearDown(() => db.close());

  test('getInstalledTranslations is empty before any install', () async {
    expect(await repo.getInstalledTranslations(), isEmpty);
  });

  test('installTranslation makes the book and its verses readable', () async {
    await repo.installTranslation(
      buildTestTranslationBook(),
      buildTestTranslationVerses(),
    );

    final installed = await repo.getInstalledTranslations();
    expect(installed, hasLength(1));
    expect(installed.single.slug, testTranslationSlug);

    final verse = await repo.getVerseText((
      chapterNo: 1,
      verseNo: 1,
    ), slug: testTranslationSlug);
    expect(verse?.text, contains('verse 1'));
    expect(verse?.footnotes.single.text, 'A test footnote.');
    expect(verse?.crossReferences.single, (chapterNo: 1, verseNo: 2));
  });

  test('getVerseRangeText batches a whole range', () async {
    await repo.installTranslation(
      buildTestTranslationBook(),
      buildTestTranslationVerses(),
    );

    final verses = await repo.getVerseRangeText((
      chapterNo: 1,
      fromVerseNo: 2,
      toVerseNo: 4,
    ), slug: testTranslationSlug);
    expect(verses.map((v) => v.verseNo), [2, 3, 4]);
  });

  test(
    'installTranslation rejects a payload whose checksum does not match',
    () async {
      final book = buildTestTranslationBook();
      final tamperedVerses = [
        for (final v in buildTestTranslationVerses())
          v.copyWith(text: '${v.text} (tampered)'),
      ];

      await expectLater(
        repo.installTranslation(book, tamperedVerses),
        throwsA(isA<ResourceChecksumMismatchException>()),
      );
      expect(await repo.getInstalledTranslation(testTranslationSlug), isNull);
    },
  );

  test(
    'a failed checksum verification never touches a previously installed book',
    () async {
      await repo.installTranslation(
        buildTestTranslationBook(),
        buildTestTranslationVerses(),
      );

      final corruptUpdate = buildTestTranslationBook(version: 2);
      final tamperedVerses = [
        for (final v in buildTestTranslationVerses())
          v.copyWith(text: '${v.text} (tampered)'),
      ];
      await expectLater(
        repo.installTranslation(corruptUpdate, tamperedVerses),
        throwsA(isA<ResourceChecksumMismatchException>()),
      );

      final stillInstalled = await repo.getInstalledTranslation(
        testTranslationSlug,
      );
      expect(stillInstalled?.version, 1);
      final verse = await repo.getVerseText((
        chapterNo: 1,
        verseNo: 1,
      ), slug: testTranslationSlug);
      expect(verse?.text, isNot(contains('tampered')));
    },
  );

  test('installTranslation rejects an unsupported format version', () async {
    final book = buildTestTranslationBook().copyWith(formatVersion: 999);

    await expectLater(
      repo.installTranslation(book, buildTestTranslationVerses()),
      throwsA(isA<ResourceFormatVersionException>()),
    );
  });

  test('re-installing with a newer version replaces the old verses', () async {
    await repo.installTranslation(
      buildTestTranslationBook(),
      buildTestTranslationVerses(),
    );

    final updatedVerses = [
      for (final v in buildTestTranslationVerses())
        v.copyWith(text: '${v.text} v2'),
    ];
    final updatedBook = TranslationBook(
      slug: testTranslationSlug,
      displayName: 'Test Translation',
      languageCode: 'en',
      author: 'Test Author',
      version: 2,
      source: 'https://example.invalid/translations/en-test',
      license: 'Test License — synthetic fixture only',
      checksum: computeResourceChecksum([
        for (final v
            in updatedVerses..sort((a, b) => a.verseNo.compareTo(b.verseNo)))
          '${v.chapterNo}:${v.verseNo}:${v.text}',
      ]),
    );

    await repo.installTranslation(updatedBook, updatedVerses);

    final installed = await repo.getInstalledTranslation(testTranslationSlug);
    expect(installed?.version, 2);
    final verse = await repo.getVerseText((
      chapterNo: 1,
      verseNo: 1,
    ), slug: testTranslationSlug);
    expect(verse?.text, endsWith('v2'));
  });

  test('deleteTranslation removes both the book and its verses', () async {
    await repo.installTranslation(
      buildTestTranslationBook(),
      buildTestTranslationVerses(),
    );

    await repo.deleteTranslation(testTranslationSlug);

    expect(await repo.getInstalledTranslation(testTranslationSlug), isNull);
    expect(
      await repo.getVerseText((
        chapterNo: 1,
        verseNo: 1,
      ), slug: testTranslationSlug),
      isNull,
    );
  });
}
