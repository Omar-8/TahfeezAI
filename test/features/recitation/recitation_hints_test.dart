import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_hints.dart';

class _Memory implements BrowserStorage {
  final values = <String, Object?>{};

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
  @override
  Future<void> clearExcept(Set<String> keep) async =>
      values.removeWhere((k, _) => !keep.contains(k));
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<void> writeAll(Map<String, Object?> v) async => values.addAll(v);
}

/// The first recitations' tips: tajweed checking off after many tajweed
/// mistakes, lenient strictness after many vowel mistakes — each once, in
/// the first two recitations only.
void main() {
  const settings = HifzSettings();
  ({int checked, int tajweed, int vowels}) tally(
    int checked, {
    int tajweed = 0,
    int vowels = 0,
  }) => (checked: checked, tajweed: tajweed, vowels: vowels);

  group('recitationHintFor', () {
    test('many tajweed mistakes: tajweed off', () {
      expect(
        recitationHintFor(tally(20, tajweed: 6), settings),
        RecitationHint.tajweedOff,
      );
    });

    test('many vowel mistakes: lenient', () {
      expect(
        recitationHintFor(tally(20, vowels: 5), settings),
        RecitationHint.lenient,
      );
    });

    test('a few mistakes, or a small share: none', () {
      expect(
        recitationHintFor(tally(20, tajweed: 3, vowels: 3), settings),
        isNull,
      );
      expect(
        recitationHintFor(tally(100, tajweed: 10, vowels: 10), settings),
        isNull,
      );
    });

    test('nothing to offer when already set so', () {
      expect(
        recitationHintFor(
          tally(20, tajweed: 8),
          settings.copyWith(tajweed: false),
        ),
        isNull,
      );
      expect(
        recitationHintFor(
          tally(20, vowels: 8),
          settings.copyWith(strictness: RecitationStrictness.lenient),
        ),
        isNull,
      );
    });

    test('a tip given before is not given again; the other is', () {
      expect(
        recitationHintFor(
          tally(20, tajweed: 8, vowels: 8),
          settings,
          shown: {RecitationHint.tajweedOff},
        ),
        RecitationHint.lenient,
      );
    });
  });

  group('recitationHintAfter', () {
    test('only the first two recitations, each tip once', () async {
      final storage = _Memory();
      final bad = tally(30, tajweed: 10, vowels: 10);
      expect(
        await recitationHintAfter(storage, settings, bad),
        RecitationHint.tajweedOff,
      );
      expect(
        await recitationHintAfter(storage, settings, bad),
        RecitationHint.lenient,
      );
      // A third recitation: no tips any more.
      expect(await recitationHintAfter(storage, settings, bad), isNull);
    });

    test('a recitation stopped at once does not count', () async {
      final storage = _Memory();
      expect(
        await recitationHintAfter(storage, settings, tally(3, tajweed: 3)),
        isNull,
      );
      expect(await recitationHintAfter(storage, settings, tally(20)), isNull);
      // Still within the first two.
      expect(
        await recitationHintAfter(storage, settings, tally(20, vowels: 9)),
        RecitationHint.lenient,
      );
    });
  });
}
