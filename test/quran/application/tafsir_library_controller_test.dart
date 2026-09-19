import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/downloads/resource_download_status.dart';
import 'package:tahfeez_ai/quran/application/tafsir_library_controller.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/domain/models/tafsir_models.dart';
import 'package:tahfeez_ai/quran/domain/tafsir_catalog.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';

import '../translation_tafsir_test_fixtures.dart';

class _FakeTafsirCatalog implements TafsirCatalog {
  _FakeTafsirCatalog(this._works);

  final List<TafsirWork> _works;

  @override
  Future<List<TafsirWork>> availableTafsirs() async => _works;
}

void main() {
  late TafsirDatabase db;

  ProviderContainer makeContainer({List<TafsirWork> catalogWorks = const []}) {
    db = TafsirDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        tafsirDatabaseProvider.overrideWith((ref) => db),
        tafsirCatalogProvider.overrideWith(
          (ref) => _FakeTafsirCatalog(catalogWorks),
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
      tafsirLibraryControllerProvider.future,
    );
    expect(statuses, isEmpty);
  });

  test('install makes the work completed and queryable', () async {
    final container = makeContainer(catalogWorks: [buildTestTafsirWork()]);
    await container.read(tafsirLibraryControllerProvider.future);

    await container
        .read(tafsirLibraryControllerProvider.notifier)
        .install(buildTestTafsirWork(), buildTestTafsirVerses());

    final statuses = container.read(tafsirLibraryControllerProvider).value!;
    expect(statuses.single.state, ResourceDownloadState.completed);
  });

  test('a newer catalog version than what is installed is outdated', () async {
    final container = makeContainer(
      catalogWorks: [buildTestTafsirWork(version: 2)],
    );
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());

    final statuses = await container.read(
      tafsirLibraryControllerProvider.future,
    );
    expect(statuses.single.state, ResourceDownloadState.outdated);
  });

  test('remove deletes the work and it disappears from the library', () async {
    final container = makeContainer();
    await container
        .read(tafsirRepositoryProvider)
        .installTafsir(buildTestTafsirWork(), buildTestTafsirVerses());
    await container.read(tafsirLibraryControllerProvider.future);

    await container
        .read(tafsirLibraryControllerProvider.notifier)
        .remove(testTafsirId);

    final statuses = container.read(tafsirLibraryControllerProvider).value!;
    expect(statuses, isEmpty);
  });
}
