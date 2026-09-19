import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';

void main() {
  group('QuranScriptPreferenceController', () {
    test('defaults to defaultQuranScriptCode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(quranScriptPreferenceControllerProvider),
        defaultQuranScriptCode,
      );
      expect(container.read(quranScriptCodeProvider), defaultQuranScriptCode);
    });

    test(
      'setScriptCode updates both the controller and quranScriptCode',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(quranScriptPreferenceControllerProvider.notifier)
            .setScriptCode('indopak');

        expect(
          container.read(quranScriptPreferenceControllerProvider),
          'indopak',
        );
        expect(container.read(quranScriptCodeProvider), 'indopak');
      },
    );

    test('persists the selected script code', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(quranScriptPreferenceControllerProvider.notifier)
          .setScriptCode('indopak');

      final stored = await container
          .read(browserStorageProvider)
          .getString('quran.selected_script_code');
      expect(stored, 'indopak');
    });
  });
}
