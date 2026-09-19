import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/search/application/search_history_controller.dart';

void main() {
  // See `translation_selection_controller_test.dart`'s `setUp` doc comment
  // (Milestone 9) for why this `keepAlive`+`BrowserStorage` controller's key
  // must be cleared before every test in this file.
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup.read(browserStorageProvider).remove('search.history');
    cleanup.dispose();
  });

  test('starts empty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(searchHistoryControllerProvider), isEmpty);
  });

  test('record adds the query to the front', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchHistoryControllerProvider.notifier);

    await notifier.record('first query');
    await notifier.record('second query');

    final history = container.read(searchHistoryControllerProvider);
    expect(history.map((e) => e.query), ['second query', 'first query']);
  });

  test(
    're-recording an existing query moves it to the front without duplicating',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(searchHistoryControllerProvider.notifier);

      await notifier.record('alpha');
      await notifier.record('beta');
      await notifier.record('alpha');

      final history = container.read(searchHistoryControllerProvider);
      expect(history.map((e) => e.query), ['alpha', 'beta']);
    },
  );

  test('ignores a blank query', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(searchHistoryControllerProvider.notifier)
        .record('   ');

    expect(container.read(searchHistoryControllerProvider), isEmpty);
  });

  test('remove deletes one entry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchHistoryControllerProvider.notifier);
    await notifier.record('alpha');
    await notifier.record('beta');

    await notifier.remove('alpha');

    final history = container.read(searchHistoryControllerProvider);
    expect(history.map((e) => e.query), ['beta']);
  });

  test('clear removes everything', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(searchHistoryControllerProvider.notifier);
    await notifier.record('alpha');
    await notifier.record('beta');

    await notifier.clear();

    expect(container.read(searchHistoryControllerProvider), isEmpty);
  });

  test('persists the recorded history as JSON', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(searchHistoryControllerProvider.notifier)
        .record('persisted query');

    final stored = await container
        .read(browserStorageProvider)
        .getString('search.history');
    expect(stored, contains('persisted query'));
  });
}
