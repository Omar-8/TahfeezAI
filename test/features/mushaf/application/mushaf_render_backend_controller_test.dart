import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_render_backend_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_render_backend.dart';

const _prefKey = 'mushaf.renderBackend';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SharedPreferencesBrowserStorage();

  // BrowserStorage is a real, process-wide store shared across every test
  // in this file (the same gotcha `mushaf_text_boldness_controller_test.dart`
  // documents) -- the saved preference must not leak between tests.
  setUp(() async {
    await storage.remove(_prefKey);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test('defaults to MushafRenderBackend.qpcV2 -- Stage 1 of the migration must '
      'not change production behavior as a side effect of adding the new '
      'backend', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(mushafRenderBackendControllerProvider),
      MushafRenderBackend.qpcV2,
    );
  });

  test('setBackend(quranEngine) updates state and persists the selection '
      '-- only reachable in a non-release build, which is what `flutter '
      'test` itself compiles as (kReleaseMode == false); the release-mode '
      'refusal branch is structurally guarded the same way every other '
      'kReleaseMode-gated provider in this codebase is, and is not '
      'independently exercisable from a normal test run', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(mushafRenderBackendControllerProvider.notifier)
        .setBackend(MushafRenderBackend.quranEngine);

    expect(
      container.read(mushafRenderBackendControllerProvider),
      MushafRenderBackend.quranEngine,
    );
  });

  test(
    'a fresh controller restores a previously persisted selection',
    () async {
      final container1 = ProviderContainer();
      addTearDown(container1.dispose);
      await container1
          .read(mushafRenderBackendControllerProvider.notifier)
          .setBackend(MushafRenderBackend.quranEngine);
      await settle();

      final container2 = ProviderContainer();
      addTearDown(container2.dispose);
      // _restore() runs asynchronously from build() -- await it settling
      // before asserting the restored value.
      container2.read(mushafRenderBackendControllerProvider);
      await settle();

      expect(
        container2.read(mushafRenderBackendControllerProvider),
        MushafRenderBackend.quranEngine,
      );
    },
  );
}
