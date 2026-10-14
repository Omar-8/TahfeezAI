import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
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

  // Arabic has no default translation: these start from an empty list.
  ProviderContainer arabic() => ProviderContainer(
    overrides: [
      localeControllerProvider.overrideWithBuild(
        (ref, _) => const Locale('ar'),
      ),
    ],
  );

  group('TranslationSelectionController', () {
    test('until chosen: the default for the language', () {
      for (final (language, slugs) in [
        ('en', ['en-rowwad']),
        ('ur', ['ur-junagarhi']),
        ('fr', ['fr-noor']),
        ('id', ['id-affairs']),
        ('es', ['es-noor']),
        ('ru', ['ru-rowwad']),
        ('fa', ['fa-rowwad']),
        ('bn', ['bn-rowwad']),
        ('ar', <String>[]),
      ]) {
        final container = ProviderContainer(
          overrides: [
            localeControllerProvider.overrideWithBuild(
              (ref, _) => Locale(language),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          container.read(translationSelectionControllerProvider),
          slugs,
          reason: language,
        );
      }
    });

    test('toggle adds then removes a slug', () async {
      final container = arabic();
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
      final container = arabic();
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
      final container = arabic();
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
