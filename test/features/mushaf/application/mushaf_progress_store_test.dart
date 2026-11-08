import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_progress_store.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

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

  // (Kept a moment after they change.)
  Future<void> saved() => Future<void>.delayed(const Duration(seconds: 1));

  WordRef w(int ayahId, int wordIndex) =>
      (ayahId: ayahId, wordIndex: wordIndex);

  MushafWordOverlay finished(
    Map<WordRef, MushafWordMark> marks, {
    Map<WordRef, String> heard = const {},
    Set<WordRef> corrected = const {},
  }) {
    final words = marks.keys.toList()..sort(compareWordRefs);
    return MushafWordOverlay(
      first: words.first,
      last: words.last,
      marks: marks,
      heard: heard,
      corrected: corrected,
      inks: const {MushafWordMark.tajweed: 0xFF2255AA},
      hideUnrevealed: false,
      followHideMode: true,
    );
  }

  test('every finished recitation\'s colours are kept, on every page, and '
      'shown again when the app opens', () async {
    final first = launch();
    final overlay = first.read(mushafWordOverlayProvider.notifier);
    overlay.set(
      finished(
        {
          w(112001, 0): MushafWordMark.correct,
          w(112003, 0): MushafWordMark.wrong,
        },
        heard: {w(112003, 0): 'بَل'},
        corrected: {w(112003, 0)},
      ),
    );
    // Another surah, recited after it: both kept.
    overlay.set(
      finished({
        w(1001, 0): MushafWordMark.correct,
        w(1001, 1): MushafWordMark.tashkeel,
      }),
    );
    // A recitation under way: kept as it was.
    overlay.set(MushafWordOverlay(first: w(36001, 0), last: w(36083, 9)));
    await saved();

    final again = launch();
    again.read(mushafWordOverlayProvider);
    await pumpEventQueue();
    final shown = again.read(mushafWordOverlayProvider)!;
    expect(shown.marks, {
      w(112001, 0): MushafWordMark.correct,
      w(112003, 0): MushafWordMark.wrong,
      w(1001, 0): MushafWordMark.correct,
      w(1001, 1): MushafWordMark.tashkeel,
    });
    expect(shown.heard, {w(112003, 0): 'بَل'});
    expect(shown.corrected, {w(112003, 0)});
    expect(shown.inks, {MushafWordMark.tajweed: 0xFF2255AA});
    // Its mistakes gone through: the latest recitation's.
    expect(markedMistakes(shown), [w(1001, 1)]);
  });

  test('a word recited again takes its new colour; what was heard on it '
      'before goes', () async {
    final container = launch();
    final overlay = container.read(mushafWordOverlayProvider.notifier);
    overlay.set(
      finished(
        {
          w(112003, 0): MushafWordMark.wrong,
          w(112003, 1): MushafWordMark.correct,
        },
        heard: {w(112003, 0): 'بَل'},
      ),
    );
    overlay.set(finished({w(112003, 0): MushafWordMark.correct}));
    final shown = container.read(mushafWordOverlayProvider)!;
    expect(shown.marks, {
      w(112003, 0): MushafWordMark.correct,
      w(112003, 1): MushafWordMark.correct,
    });
    expect(shown.heard, isEmpty);
  });

  test('while reciting, the kept colours show before its first word only, '
      'and not on words it hides', () async {
    final container = launch();
    final overlay = container.read(mushafWordOverlayProvider.notifier);
    overlay.set(
      finished({
        w(112001, 0): MushafWordMark.correct,
        w(112002, 0): MushafWordMark.wrong,
        w(112004, 0): MushafWordMark.correct,
      }),
    );
    overlay.set(
      MushafWordOverlay(
        first: w(112002, 0),
        last: w(112004, 4),
        hideUnrevealed: false,
        marks: {w(112002, 0): MushafWordMark.current},
      ),
    );
    expect(container.read(mushafWordOverlayProvider)!.marks, {
      w(112001, 0): MushafWordMark.correct,
      w(112002, 0): MushafWordMark.current,
    });
    expect(
      markedMistakes(container.read(mushafWordOverlayProvider)),
      isEmpty,
      reason: 'not the kept ones',
    );
    // Hidden (hide mode): not drawn on hidden words.
    overlay.set(MushafWordOverlay(first: w(112002, 0), last: w(112004, 4)));
    expect(container.read(mushafWordOverlayProvider)!.marks, isEmpty);
    // Over: all kept again.
    overlay.set(null);
    expect(container.read(mushafWordOverlayProvider)!.marks, hasLength(3));
  });

  test('colours hidden (the plain eye): none drawn but the recitation '
      'followed, a recitation\'s kept '
      'all the same — and so after the app is closed; shown again, all '
      'there', () async {
    final container = launch();
    final overlay = container.read(mushafWordOverlayProvider.notifier);
    overlay.set(finished({w(112001, 0): MushafWordMark.wrong}));
    container.read(mushafColoursShownProvider.notifier).set(false);
    expect(container.read(mushafWordOverlayProvider), isNull);
    // Reciting: the current word's band only (no trail), nothing judged;
    // after, nothing drawn.
    overlay.set(
      MushafWordOverlay(
        first: w(112002, 0),
        last: w(112004, 4),
        hideUnrevealed: false,
        marks: {
          w(112002, 0): MushafWordMark.wrong,
          w(112002, 1): MushafWordMark.current,
        },
      ),
    );
    expect(container.read(mushafWordOverlayProvider)!.marks, {
      w(112002, 1): MushafWordMark.current,
    });
    overlay.set(finished({w(112001, 0): MushafWordMark.correct}));
    expect(container.read(mushafWordOverlayProvider), isNull);
    await saved();

    final again = launch();
    again.read(mushafWordOverlayProvider);
    await pumpEventQueue();
    expect(again.read(mushafColoursShownProvider), isFalse);
    expect(again.read(mushafWordOverlayProvider), isNull);
    again.read(mushafColoursShownProvider.notifier).set(true);
    expect(again.read(mushafWordOverlayProvider)!.marks, {
      w(112001, 0): MushafWordMark.correct,
    });
  });

  test('the colours kept before 1.2.1 (the last recitation\'s) are moved '
      'over', () async {
    await MushafProgressStore(storage).saveResults(
      finished(
        {
          w(112001, 0): MushafWordMark.correct,
          w(112003, 0): MushafWordMark.wrong,
        },
        heard: {w(112003, 0): 'بَل'},
      ),
    );
    final container = launch();
    container.read(mushafWordOverlayProvider);
    await pumpEventQueue();
    final shown = container.read(mushafWordOverlayProvider)!;
    expect(shown.marks, hasLength(2));
    expect(shown.heard, {w(112003, 0): 'بَل'});
    expect(markedMistakes(shown), [w(112003, 0)]);
    expect(storage.values.containsKey(MushafProgressStore.resultsKey), isFalse);
    expect(storage.values.containsKey(MushafProgressStore.keptKey), isTrue);
  });
}
