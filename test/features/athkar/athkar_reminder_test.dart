import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_reminder.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/fake_reminder_scheduler.dart';

/// The morning and evening athkar reminders (owner, 2026-11-21): off until
/// turned on; each day ahead at its time.
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
  late FakeReminderScheduler scheduler;
  late ProviderContainer container;

  setUp(() async {
    scheduler = FakeReminderScheduler();
    container = ProviderContainer(
      overrides: [
        dailyReminderSchedulerProvider.overrideWithValue(scheduler),
        browserStorageProvider.overrideWithValue(_MemoryStorage()),
        memorizationClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 21, 10),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(athkarReminderProvider);
    await pumpEventQueue();
  });

  test('off at first: nothing scheduled', () {
    expect(scheduler.once, isEmpty);
    expect(scheduler.handlers, contains(AthkarReminderController.payload));
  });

  test('the morning one on: every day at 6:30 — one notification '
      'repeating (an iPhone keeps 64 in all)', () async {
    final reminders = container.read(athkarReminderProvider.notifier);
    expect(await reminders.setEnabled(AthkarTime.morning, true), isTrue);
    expect(scheduler.once, isEmpty);
    final morning = scheduler.repeating[AthkarTime.morning.firstId]!;
    expect((morning.weekday, morning.hour, morning.minute), (null, 6, 30));
    expect(morning.title, 'Morning athkar');
    expect(morning.payload, AthkarReminderController.payload);

    // The evening one too, at its own time.
    await reminders.setEnabled(AthkarTime.evening, true);
    await reminders.setTime(AthkarTime.evening, 18 * 60);
    final evening = scheduler.repeating[AthkarTime.evening.firstId]!;
    expect((evening.hour, evening.minute), (18, 0));
    expect(scheduler.repeating, hasLength(2));

    // Off: its own gone, the other kept.
    await reminders.setEnabled(AthkarTime.morning, false);
    expect(scheduler.repeating.keys, [AthkarTime.evening.firstId]);
  });

  test('permission refused: stays off', () async {
    final refused = FakeReminderScheduler(granted: false);
    final c = ProviderContainer(
      overrides: [
        dailyReminderSchedulerProvider.overrideWithValue(refused),
        browserStorageProvider.overrideWithValue(_MemoryStorage()),
      ],
    );
    addTearDown(c.dispose);
    c.read(athkarReminderProvider);
    await pumpEventQueue();
    expect(
      await c
          .read(athkarReminderProvider.notifier)
          .setEnabled(AthkarTime.morning, true),
      isFalse,
    );
    expect(
      c.read(athkarReminderProvider)[AthkarTime.morning]!.enabled,
      isFalse,
    );
    expect(refused.once, isEmpty);
    expect(refused.repeating, isEmpty);
  });
}
