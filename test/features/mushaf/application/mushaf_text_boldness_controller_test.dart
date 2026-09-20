// Exercises MushafTextBoldnessController's real persistence, backed by the
// same BrowserStorage-via-shared_preferences mechanism
// MushafAppearanceController/other reader preference controllers already
// use -- never a new persistence mechanism of its own.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_text_boldness_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_text_boldness.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _prefKey = 'mushaf.textBoldness';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SharedPreferencesBrowserStorage();

  // BrowserStorage is a real, process-wide store shared across every test
  // in this file (the same gotcha `bundled_dataset_seeder_test.dart`
  // documents) -- the saved preference must not leak between tests.
  setUp(() async {
    await storage.remove(_prefKey);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('defaults to Medium for a user who has never set this preference '
      '(no migration required)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(mushafTextBoldnessControllerProvider),
      MushafTextBoldness.medium,
    );
  });

  test('setBoldness updates state immediately', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(mushafTextBoldnessControllerProvider.notifier)
        .setBoldness(MushafTextBoldness.bold);

    expect(
      container.read(mushafTextBoldnessControllerProvider),
      MushafTextBoldness.bold,
    );
  });

  test(
    'setBoldness persists the choice to the real preference store',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(mushafTextBoldnessControllerProvider.notifier)
          .setBoldness(MushafTextBoldness.light);

      expect(
        await container.read(browserStorageProvider).getString(_prefKey),
        'light',
      );
    },
  );

  test('a fresh ProviderContainer (simulating an app restart) restores a '
      'previously saved preference', () async {
    await storage.setString(_prefKey, 'bold');

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      mushafTextBoldnessControllerProvider,
      (_, _) {},
    );
    addTearDown(sub.close);

    await settle();

    expect(
      container.read(mushafTextBoldnessControllerProvider),
      MushafTextBoldness.bold,
    );
  });

  test(
    'survives "switching Surahs"/"switching Mushaf pages" -- i.e. surviving '
    'independently of any particular reader session, since it is a plain '
    'top-level keepAlive preference, never scoped to a location/page',
    () async {
      await storage.setString(_prefKey, 'light');

      // Two independent containers -- standing in for two different
      // reader sessions/navigations -- both see the same persisted value.
      final containerA = ProviderContainer();
      addTearDown(containerA.dispose);
      final subA = containerA.listen(
        mushafTextBoldnessControllerProvider,
        (_, _) {},
      );
      addTearDown(subA.close);
      await settle();
      expect(
        containerA.read(mushafTextBoldnessControllerProvider),
        MushafTextBoldness.light,
      );

      final containerB = ProviderContainer();
      addTearDown(containerB.dispose);
      final subB = containerB.listen(
        mushafTextBoldnessControllerProvider,
        (_, _) {},
      );
      addTearDown(subB.close);
      await settle();
      expect(
        containerB.read(mushafTextBoldnessControllerProvider),
        MushafTextBoldness.light,
      );
    },
  );
}
