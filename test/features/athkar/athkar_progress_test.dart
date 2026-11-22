import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_progress.dart';
import 'package:tahfeez_ai/features/athkar/domain/athkar.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

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

const _once = Zikr(
  id: 1,
  arabic: 'أ',
  english: '',
  note: '',
  repeat: 1,
  audio: null,
);
const _thrice = Zikr(
  id: 2,
  arabic: 'ب',
  english: '',
  note: '',
  repeat: 3,
  audio: null,
);
const _chapter = AthkarCategory(
  id: 9,
  arabic: 'باب',
  english: 'Chapter',
  audio: 'x.mp3',
  athkar: [_once, _thrice],
);

/// Today's athkar: counted up to each one's number, kept on the phone, and
/// a new day starts afresh (owner, 2026-11-21).
void main() {
  late _MemoryStorage storage;
  late DateTime now;

  ProviderContainer launch() {
    final container = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(storage),
        memorizationClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    storage = _MemoryStorage();
    now = DateTime(2026, 11, 21, 7);
  });

  test('counted up to its number, then done; the chapter ticked once all '
      'are', () async {
    final c = launch();
    final p = c.read(athkarProgressProvider.notifier);
    await pumpEventQueue();
    expect(p.count(_thrice), isFalse);
    expect(p.count(_thrice), isFalse);
    expect(p.isDone(_thrice), isFalse);
    expect(p.count(_thrice), isTrue, reason: 'the third finishes it');
    expect(p.count(_thrice), isFalse, reason: 'no further');
    expect(p.countOf(_thrice), 3);
    expect(athkarDone(_chapter, c.read(athkarProgressProvider)), (
      done: 1,
      of: 2,
    ));
    expect(p.count(_once), isTrue);
    expect(athkarDone(_chapter, c.read(athkarProgressProvider)), (
      done: 2,
      of: 2,
    ));
    p.reset(_chapter);
    expect(athkarDone(_chapter, c.read(athkarProgressProvider)), (
      done: 0,
      of: 2,
    ));
  });

  test('kept on the phone for the day; the next day starts afresh', () async {
    final first = launch();
    await pumpEventQueue();
    first.read(athkarProgressProvider.notifier).count(_thrice);
    await pumpEventQueue();
    final saved = jsonDecode(
      storage.values[AthkarProgressController.storageKey]! as String,
    );
    expect(saved['day'], '2026-11-21');

    // The app opened again later that day: still counted.
    now = DateTime(2026, 11, 21, 23, 59);
    final again = launch();
    again.read(athkarProgressProvider);
    await pumpEventQueue();
    expect(again.read(athkarProgressProvider.notifier).countOf(_thrice), 1);

    // The next morning: afresh.
    now = DateTime(2026, 11, 22, 6);
    final tomorrow = launch();
    tomorrow.read(athkarProgressProvider);
    await pumpEventQueue();
    expect(tomorrow.read(athkarProgressProvider.notifier).countOf(_thrice), 0);
  });

  test('the app kept open past midnight: the new day afresh', () async {
    final c = launch();
    final p = c.read(athkarProgressProvider.notifier);
    await pumpEventQueue();
    p.count(_once);
    expect(p.isDone(_once), isTrue);
    now = DateTime(2026, 11, 22, 0, 1);
    expect(p.isDone(_once), isFalse);
    expect(p.count(_once), isTrue);
  });
}
