import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/downloads/resource_download_status.dart';
import 'package:tahfeez_ai/quran/application/translation_library_controller.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/translation_models.dart';
import 'package:tahfeez_ai/quran/domain/translation_catalog.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';

import '../translation_tafsir_test_fixtures.dart';

class _FakeTranslationCatalog implements TranslationCatalog {
  _FakeTranslationCatalog(this._books);

  final List<TranslationBook> _books;

  @override
  Future<List<TranslationBook>> availableTranslations() async => _books;
}

void main() {
  late TranslationDatabase db;

  ProviderContainer makeContainer({
    List<TranslationBook> catalogBooks = const [],
  }) {
    db = TranslationDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        translationDatabaseProvider.overrideWith((ref) => db),
        translationCatalogProvider.overrideWith(
          (ref) => _FakeTranslationCatalog(catalogBooks),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    return container;
  }

  test('starts empty when nothing is installed or cataloged', () async {
    final container = makeContainer();
    final statuses = await container.read(
      translationLibraryControllerProvider.future,
    );
    expect(statuses, isEmpty);
  });

  test('a cataloged, uninstalled book is notDownloaded', () async {
    final container = makeContainer(catalogBooks: [buildTestTranslationBook()]);
    final statuses = await container.read(
      translationLibraryControllerProvider.future,
    );
    expect(statuses, hasLength(1));
    expect(statuses.single.state, ResourceDownloadState.notDownloaded);
  });

  test('install makes the book completed and queryable', () async {
    final container = makeContainer(catalogBooks: [buildTestTranslationBook()]);
    await container.read(translationLibraryControllerProvider.future);

    await container
        .read(translationLibraryControllerProvider.notifier)
        .install(buildTestTranslationBook(), buildTestTranslationVerses());

    final statuses = container
        .read(translationLibraryControllerProvider)
        .value!;
    expect(statuses.single.state, ResourceDownloadState.completed);

    final verse = await container
        .read(translationRepositoryProvider)
        .getVerseText((chapterNo: 1, verseNo: 1), slug: testTranslationSlug);
    expect(verse, isNotNull);
  });

  test('a newer catalog version than what is installed is outdated', () async {
    final container = makeContainer(
      catalogBooks: [buildTestTranslationBook(version: 2)],
    );
    await container
        .read(translationRepositoryProvider)
        .installTranslation(
          buildTestTranslationBook(),
          buildTestTranslationVerses(),
        );

    final statuses = await container.read(
      translationLibraryControllerProvider.future,
    );
    expect(statuses.single.state, ResourceDownloadState.outdated);
  });

  test('remove deletes the book and it disappears from the library', () async {
    final container = makeContainer();
    await container
        .read(translationRepositoryProvider)
        .installTranslation(
          buildTestTranslationBook(),
          buildTestTranslationVerses(),
        );
    await container.read(translationLibraryControllerProvider.future);

    await container
        .read(translationLibraryControllerProvider.notifier)
        .remove(testTranslationSlug);

    final statuses = container
        .read(translationLibraryControllerProvider)
        .value!;
    expect(statuses, isEmpty);
    expect(
      await container
          .read(translationRepositoryProvider)
          .getInstalledTranslation(testTranslationSlug),
      isNull,
    );
  });
}
