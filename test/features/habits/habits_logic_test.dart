import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_reminder.dart';
import 'package:tahfeez_ai/features/habits/application/habit_reminders.dart';
import 'package:tahfeez_ai/features/habits/application/habits_controller.dart';
import 'package:tahfeez_ai/features/habits/domain/habit.dart';
import 'package:tahfeez_ai/features/habits/domain/habit_catalog.dart';
import 'package:tahfeez_ai/features/habits/domain/hijri.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/empty_memorization_repository.dart';
import '../../test_helpers/fake_reminder_scheduler.dart';

import 'package:tahfeez_ai/memorization/memorization_providers.dart';

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

/// Habits (owner, 2026-11-21): when each is due (weekdays, Hijri days and
/// dates), its log (a day's amount — the last one's by default), how it
/// goes, kept on the phone; its reminders.
void main() {
  late _MemoryStorage storage;
  late FakeReminderScheduler scheduler;
  var now = DateTime(2026, 11, 21, 10); // A Saturday: 11 Jumada II 1448.

  ProviderContainer launch() {
    final c = ProviderContainer(
      overrides: [
        browserStorageProvider.overrideWithValue(storage),
        memorizationClockProvider.overrideWithValue(() => now),
        dailyReminderSchedulerProvider.overrideWithValue(scheduler),
        memorizationRepositoryProvider.overrideWithValue(
          const EmptyMemorizationRepository(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    storage = _MemoryStorage();
    scheduler = FakeReminderScheduler();
    now = DateTime(2026, 11, 21, 10);
  });

  test('the Hijri date: Umm al-Qura, moved a day where asked', () {
    expect(hijriOf(DateTime(2026, 11, 21)), (year: 1448, month: 6, day: 11));
    expect(hijriOf(DateTime(2026, 11, 21), adjust: 1).day, 12);
    expect(hijriOf(DateTime(2026, 11, 21), adjust: -1).day, 10);
    expect(
      formatHijri((year: 1448, month: 9, day: 1), 'en'),
      '1 Ramadan 1448 AH',
    );
    expect(
      formatHijri((year: 1448, month: 9, day: 1), 'ar'),
      '1 رمضان 1448 هـ',
    );
  });

  test('when due: every day, weekdays, Ayyām al-Bīḍ, ʿArafah — from the '
      'day it was added', () async {
    final c = launch();
    await pumpEventQueue();
    final h = c.read(habitsProvider.notifier);
    final monThu = h.addTemplate(habitTemplate('fastMonThu')!);
    final beed = h.addTemplate(habitTemplate('fastBeed')!);
    final duha = h.addTemplate(habitTemplate('duha')!);
    final s = c.read(habitsProvider);
    expect(s.dueOn(duha, DateTime(2026, 11, 21)), isTrue);
    expect(s.dueOn(duha, DateTime(2026, 11, 20)), isFalse, reason: 'before');
    expect(s.dueOn(monThu, DateTime(2026, 11, 23)), isTrue, reason: 'Monday');
    expect(s.dueOn(monThu, DateTime(2026, 11, 24)), isFalse);
    expect(s.dueOn(monThu, DateTime(2026, 11, 26)), isTrue, reason: 'Thu');
    // 13–15 Jumada II: 23–25 November.
    for (final (d, due) in [(22, false), (23, true), (25, true), (26, false)]) {
      expect(s.dueOn(beed, DateTime(2026, 11, d)), due, reason: '$d');
    }
    // A day later where the month began a day later.
    h.setHijriAdjust(-1);
    expect(c.read(habitsProvider).dueOn(beed, DateTime(2026, 11, 26)), isTrue);
    expect(c.read(habitsProvider).dueOn(beed, DateTime(2026, 11, 23)), isFalse);
  });

  test('ticked: the last amount given, else the target; any day since it '
      'was added; counted one by one; untick', () async {
    final c = launch();
    await pumpEventQueue();
    final h = c.read(habitsProvider.notifier);
    now = DateTime(2026, 11, 1, 9);
    final duha = h.addTemplate(habitTemplate('duha')!);
    now = DateTime(2026, 11, 21, 10);
    h.tick(duha, '2026-11-19');
    expect(c.read(habitsProvider).amountOn(duha.id, '2026-11-19'), 2);
    h.tick(duha, '2026-11-20', amount: 4);
    expect(h.defaultAmount(duha), 4, reason: 'the last amount');
    h.tick(duha, '2026-11-21');
    expect(c.read(habitsProvider).amountOn(duha.id, '2026-11-21'), 4);
    h.untick(duha, '2026-11-21');
    expect(c.read(habitsProvider).amountOn(duha.id, '2026-11-21'), isNull);

    final wird = h.addTemplate(habitTemplate('wirdSalawat')!);
    expect(h.countOne(wird, '2026-11-21'), 1);
    expect(h.countOne(wird, '2026-11-21'), 2);

    final s = c.read(habitsProvider);
    expect(
      habitStreak(s, duha, DateTime(2026, 11, 21)),
      2,
      reason: '19th and 20th (today not yet: not broken)',
    );
    final month = habitPeriod(
      s,
      duha,
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 21),
    );
    expect(month, (done: 2, due: 21, total: 6));
    expect(habitsDay(s, DateTime(2026, 11, 21)), (done: 1, due: 2));
  });

  test('kept on the phone: back as it was; removed with its log', () async {
    final c = launch();
    await pumpEventQueue();
    final h = c.read(habitsProvider.notifier);
    final own = h.addOwn(
      name: 'Walk',
      icon: habitIcons[9].codePoint,
      schedule: const WeekdaysSchedule({1, 3, 5}),
      unit: HabitUnit.minutes,
      target: 20,
      reminders: const [HabitReminder(minutes: 7 * 60)],
    );
    h
      ..tick(own, '2026-11-21', amount: 30)
      ..setHijriAdjust(1);
    await pumpEventQueue();

    final again = launch();
    again.read(habitsProvider);
    await pumpEventQueue();
    final s = again.read(habitsProvider);
    final back = s.habit(own.id)!;
    expect(back.name, 'Walk');
    expect(back.schedule, const WeekdaysSchedule({1, 3, 5}));
    expect((back.unit, back.target), (HabitUnit.minutes, 20));
    expect(back.reminders.single.minutes, 7 * 60);
    expect(s.amountOn(own.id, '2026-11-21'), 30);
    expect(s.hijriAdjust, 1);

    again.read(habitsProvider.notifier).remove(own.id);
    expect(again.read(habitsProvider).habits, isEmpty);
    expect(again.read(habitsProvider).log[own.id], isNull);
  });

  test('the morning athkar habit and Athkar share one reminder: on and its '
      'time either way, one notification', () async {
    final c = launch();
    c.read(habitRemindersProvider);
    c.read(athkarHabitReminderSyncProvider);
    c.read(athkarReminderProvider);
    await pumpEventQueue();
    final h = c.read(habitsProvider.notifier);
    final morning = h.addTemplate(habitTemplate('athkarMorning')!);
    await pumpEventQueue();
    // The habit's reminder turned Athkar's on, at its time — Athkar's is
    // the one scheduled, not a second.
    var athkar = c.read(athkarReminderProvider)[AthkarTime.morning]!;
    expect((athkar.enabled, athkar.minutes), (true, 6 * 60 + 30));
    expect(
      scheduler.repeating.values.where(
        (r) => r.payload == habitPayload(morning.id),
      ),
      isEmpty,
    );
    expect(scheduler.repeating.keys, contains(AthkarTime.morning.firstId));

    // Athkar's time changed: the habit's too.
    await c
        .read(athkarReminderProvider.notifier)
        .setTime(AthkarTime.morning, 7 * 60);
    await pumpEventQueue();
    expect(
      c.read(habitsProvider).habit(morning.id)!.reminders.first.minutes,
      7 * 60,
    );

    // The habit's reminder off: Athkar's too.
    h.update(
      c.read(habitsProvider).habit(morning.id)!.copyWith(remindersOn: false),
    );
    await pumpEventQueue();
    athkar = c.read(athkarReminderProvider)[AthkarTime.morning]!;
    expect(athkar.enabled, isFalse);
    // Athkar's on again: the habit's too.
    await c
        .read(athkarReminderProvider.notifier)
        .setEnabled(AthkarTime.morning, true);
    await pumpEventQueue();
    expect(c.read(habitsProvider).habit(morning.id)!.remindersOn, isTrue);
  });

  test(
    'reminders: daily ones repeating; a fast\'s the evening before and '
    'at suhoor, by weekday; Ayyām al-Bīḍ\'s date by date; off: none',
    () async {
      final c = launch();
      c.read(habitRemindersProvider);
      await pumpEventQueue();
      final h = c.read(habitsProvider.notifier);
      final duha = h.addTemplate(habitTemplate('duha')!);
      await pumpEventQueue();
      expect(scheduler.repeating.values.single.weekday, isNull);
      expect(
        (
          scheduler.repeating.values.single.hour,
          scheduler.repeating.values.single.title,
        ),
        (9, 'Ḍuḥā prayer'),
      );
      expect(scheduler.handlers, contains(habitPayload(duha.id)));

      final monThu = h.addTemplate(habitTemplate('fastMonThu')!);
      await pumpEventQueue();
      final fast = scheduler.repeating.values
          .where((r) => r.payload == habitPayload(monThu.id))
          .map((r) => (r.weekday, r.hour))
          .toSet();
      expect(fast, {
        (DateTime.sunday, 21), (DateTime.wednesday, 21), // the evening before
        (DateTime.monday, 4), (DateTime.thursday, 4), // suhoor
      });

      final beed = h.addTemplate(habitTemplate('fastBeed')!);
      await pumpEventQueue();
      final dates = scheduler.once.values.map((o) => o.at).toList()..sort();
      // 13–15 Jumada II (23–25 Nov): the evening before each, and suhoor.
      expect(dates.first, DateTime(2026, 11, 22, 21));
      expect(dates, contains(DateTime(2026, 11, 23, 4)));
      expect(dates, contains(DateTime(2026, 11, 25, 4)));
      expect(
        dates.every((d) => d.isBefore(DateTime(2027, 1, 21))),
        isTrue,
        reason: '60 days ahead at most',
      );

      // Its reminders off: gone; the habit removed: gone too.
      h.update(
        c.read(habitsProvider).habit(beed.id)!.copyWith(remindersOn: false),
      );
      await pumpEventQueue();
      expect(scheduler.once, isEmpty);
      h
        ..remove(duha.id)
        ..remove(monThu.id);
      await pumpEventQueue();
      expect(scheduler.repeating, isEmpty);
    },
  );
}
