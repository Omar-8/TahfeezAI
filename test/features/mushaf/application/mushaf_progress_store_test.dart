import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_progress_store.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';

class _MemoryStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}

  final values = <String, Object>{};
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  late _MemoryStorage storage;

  /// A run of the app: its own container, restoring once at its start.
  ProviderContainer launch() {
    MushafProgressStore.resetRestored();
    final container = ProviderContainer(
      overrides: [browserStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => storage = _MemoryStorage());

  test(
    'hide mode and the words uncovered survive the app being closed',
    () async {
      final first = launch();
      first.read(mushafHideModeProvider.notifier)
        ..toggle()
        ..reportPageWords(604, wordCount: 30, ayahBoundaries: const [4, 10, 30])
        ..revealNextWord(604)
        ..revealNextWord(604)
        ..revealNextAyah(604);
      final uncovered = first.read(mushafHideModeProvider).revealedOn(604);
      expect(uncovered, greaterThan(2));
      await pumpEventQueue();

      final again = launch();
      again.read(mushafHideModeProvider);
      await pumpEventQueue();
      final restored = again.read(mushafHideModeProvider);
      expect(restored.enabled, isTrue);
      expect(restored.revealedOn(604), uncovered);
    },
  );

  test('a finished recitation\'s colours are shown again; one under way, '
      'or none, is not kept', () async {
    const results = MushafWordOverlay(
      first: (ayahId: 112001, wordIndex: 0),
      last: (ayahId: 112004, wordIndex: 4),
      marks: {
        (ayahId: 112001, wordIndex: 0): MushafWordMark.correct,
        (ayahId: 112003, wordIndex: 0): MushafWordMark.wrong,
      },
      heard: {(ayahId: 112003, wordIndex: 0): 'بَل'},
      corrected: {(ayahId: 112003, wordIndex: 0)},
      inks: {MushafWordMark.tajweed: 0xFF2255AA},
      hideUnrevealed: false,
      followHideMode: true,
    );
    final first = launch();
    first.read(mushafWordOverlayProvider.notifier).set(results);
    await pumpEventQueue();

    final again = launch();
    again.read(mushafWordOverlayProvider);
    await pumpEventQueue();
    expect(again.read(mushafWordOverlayProvider), results);
    expect(again.read(mushafWordOverlayProvider.notifier).restored, isTrue);

    // A recitation under way replaces them: nothing kept.
    again
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: (ayahId: 112001, wordIndex: 0),
            last: (ayahId: 112004, wordIndex: 4),
          ),
        );
    await pumpEventQueue();
    final third = launch();
    third.read(mushafWordOverlayProvider);
    await pumpEventQueue();
    expect(third.read(mushafWordOverlayProvider), isNull);
  });
}
