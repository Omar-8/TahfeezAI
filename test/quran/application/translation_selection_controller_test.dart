import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/translation_selection_controller.dart';

void main() {
  // `TranslationSelectionController` is `keepAlive` and persists to the
  // same real (process-wide) `BrowserStorage` key across every test in this
  // file; its `_restore()` is a fire-and-forget async read that can resolve
  // in the middle of a later test's own synchronous-looking mutations and
  // clobber them with whatever a previous test happened to leave behind.
  // Clearing the key before each test means `_restore()` always sees `null`
  // and is a guaranteed no-op, removing the race entirely.
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup
        .read(browserStorageProvider)
        .remove('translation.active_slugs');
    cleanup.dispose();
  });

  group('TranslationSelectionController', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(translationSelectionControllerProvider), isEmpty);
    });

    test('toggle adds then removes a slug', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        translationSelectionControllerProvider.notifier,
      );

      await notifier.toggle('en-a');
      expect(container.read(translationSelectionControllerProvider), ['en-a']);

      await notifier.toggle('en-b');
      expect(container.read(translationSelectionControllerProvider), [
        'en-a',
        'en-b',
      ]);

      await notifier.toggle('en-a');
      expect(container.read(translationSelectionControllerProvider), ['en-b']);
    });

    test('reorder moves a slug to a new position', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        translationSelectionControllerProvider.notifier,
      );
      await notifier.toggle('en-a');
      await notifier.toggle('en-b');
      await notifier.toggle('en-c');

      await notifier.reorder(0, 2);

      expect(container.read(translationSelectionControllerProvider), [
        'en-b',
        'en-c',
        'en-a',
      ]);
    });

    test('persists the active slug list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(translationSelectionControllerProvider.notifier)
          .toggle('en-a');

      final stored = await container
          .read(browserStorageProvider)
          .getString('translation.active_slugs');
      expect(stored, 'en-a');
    });
  });
}
