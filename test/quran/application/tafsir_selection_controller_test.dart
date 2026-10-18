import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';

void main() {
  // See `translation_selection_controller_test.dart`'s `setUp` doc comment:
  // both these controllers are `keepAlive` and persist to a shared,
  // process-wide `BrowserStorage`, so their keys must be cleared before
  // each test to keep a fire-and-forget `_restore()` from racing with and
  // clobbering this test's own mutations.
  setUp(() async {
    final cleanup = ProviderContainer();
    await cleanup.read(browserStorageProvider).remove('tafsir.active_id');
    await cleanup.read(browserStorageProvider).remove('tafsir.text_scale');
    cleanup.dispose();
  });

  group('TafsirSelectionController', () {
    test('until chosen: the default for the language', () {
      for (final (language, id) in [
        ('ar', 'ar-muyassar'),
        ('en', 'en-mukhtasar'),
        ('tr', 'tr-mukhtasar'),
        ('id', 'id-mukhtasar'),
        ('es', 'es-mukhtasar'),
        ('ru', 'ru-mukhtasar'),
        ('fa', 'fa-mukhtasar'),
        ('bn', 'bn-mukhtasar'),
        ('ur', 'ur-ahsanulbayan'),
        ('de', 'en-mukhtasar'),
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
          container.read(tafsirSelectionControllerProvider),
          id,
          reason: language,
        );
      }
    });

    test('none, once chosen, stays none', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(tafsirSelectionControllerProvider.notifier)
          .select(null);
      expect(
        await container
            .read(browserStorageProvider)
            .getString('tafsir.active_id'),
        '',
      );
    });

    test('select sets then clears the active tafsir', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        tafsirSelectionControllerProvider.notifier,
      );

      await notifier.select('en-a');
      expect(container.read(tafsirSelectionControllerProvider), 'en-a');

      await notifier.select(null);
      expect(container.read(tafsirSelectionControllerProvider), isNull);
    });

    test('persists the selected tafsir id', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(tafsirSelectionControllerProvider.notifier)
          .select('en-a');

      final stored = await container
          .read(browserStorageProvider)
          .getString('tafsir.active_id');
      expect(stored, 'en-a');
    });
  });

  group('TafsirTextScaleController', () {
    test('defaults to 1.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(tafsirTextScaleControllerProvider), 1.0);
    });

    test('setScale updates and persists the scale', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(tafsirTextScaleControllerProvider.notifier)
          .setScale(1.5);

      expect(container.read(tafsirTextScaleControllerProvider), 1.5);
      final stored = await container
          .read(browserStorageProvider)
          .getString('tafsir.text_scale');
      expect(stored, '1.5');
    });
  });
}
