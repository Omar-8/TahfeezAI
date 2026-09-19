import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/downloads/resource_download_status.dart';
import 'package:tahfeez_ai/wbw/application/wbw_library_controller.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/domain/models/wbw_models.dart';
import 'package:tahfeez_ai/wbw/domain/wbw_pack_catalog.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import '../wbw_test_fixtures.dart';

/// A fake catalog reporting one known pack, so tests can exercise
/// not-downloaded/outdated states without a real network manifest.
class _FakeWbwPackCatalog implements WbwPackCatalog {
  _FakeWbwPackCatalog(this._packs);

  final List<WbwLanguagePack> _packs;

  @override
  Future<List<WbwLanguagePack>> availablePacks() async => _packs;
}

void main() {
  late WbwDatabase db;

  ProviderContainer makeContainer({
    List<WbwLanguagePack> catalogPacks = const [],
  }) {
    db = WbwDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        wbwDatabaseProvider.overrideWith((ref) => db),
        wbwPackCatalogProvider.overrideWith(
          (ref) => _FakeWbwPackCatalog(catalogPacks),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    return container;
  }

  test('starts empty when nothing is installed or cataloged', () async {
    final container = makeContainer();
    final statuses = await container.read(wbwLibraryControllerProvider.future);
    expect(statuses, isEmpty);
  });

  test('a cataloged, uninstalled pack is notDownloaded', () async {
    final container = makeContainer(catalogPacks: [buildTestWbwPack()]);
    final statuses = await container.read(wbwLibraryControllerProvider.future);
    expect(statuses, hasLength(1));
    expect(statuses.single.state, ResourceDownloadState.notDownloaded);
  });

  test('install makes the pack completed and queryable', () async {
    final container = makeContainer(catalogPacks: [buildTestWbwPack()]);
    await container.read(wbwLibraryControllerProvider.future);

    await container
        .read(wbwLibraryControllerProvider.notifier)
        .install(buildTestWbwPack(), buildTestWbwWords());

    final statuses = container.read(wbwLibraryControllerProvider).value!;
    expect(statuses.single.state, ResourceDownloadState.completed);

    final word = await container
        .read(wbwRepositoryProvider)
        .getWord(packId: testWbwPackId, ayahId: 1001, wordIndex: 0);
    expect(word?.translation, 'word');
  });

  test('a newer catalog version than what is installed is outdated', () async {
    final container = makeContainer(
      catalogPacks: [buildTestWbwPack(version: 2)],
    );
    await container
        .read(wbwRepositoryProvider)
        .installPack(buildTestWbwPack(version: 1), buildTestWbwWords());

    final statuses = await container.read(wbwLibraryControllerProvider.future);
    expect(statuses.single.state, ResourceDownloadState.outdated);
  });

  test('remove deletes the pack and it disappears from the library', () async {
    final container = makeContainer();
    await container
        .read(wbwRepositoryProvider)
        .installPack(buildTestWbwPack(), buildTestWbwWords());
    await container.read(wbwLibraryControllerProvider.future);

    await container
        .read(wbwLibraryControllerProvider.notifier)
        .remove(testWbwPackId);

    final statuses = container.read(wbwLibraryControllerProvider).value!;
    expect(statuses, isEmpty);
    expect(
      await container
          .read(wbwRepositoryProvider)
          .getInstalledPack(testWbwPackId),
      isNull,
    );
  });
}
