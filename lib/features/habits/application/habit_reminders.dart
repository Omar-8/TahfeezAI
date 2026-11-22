import 'dart:async';

import '../../athkar/application/athkar_reminder.dart';

import 'dart:convert';

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import 'habits_controller.dart';

/// A habit's reminder's payload: `habit:<id>`.
String habitPayload(String id) => 'habit:$id';

/// The habits' reminders, scheduled again whenever the habits change:
/// daily and weekday ones repeating (one pending notification each — an
/// iPhone keeps 64 in all); Hijri-day ones a date at a time, the next
/// [hijriAhead] days. A tap opens where the habit is done (its athkar,
/// its surah, the Mushaf, Memorize) — else the habit, to tick it (owner,
/// 2026-11-21).
class HabitRemindersController extends Notifier<void> {
  static const idsKey = 'habits.notificationIds';

  /// The notifications' ids: from here on.
  static const firstId = 2000;
  static const hijriAhead = 60;

  /// What is scheduled now (to cancel before scheduling again).
  var _scheduled = <int>[];
  var _restored = false;
  Future<void>? _running;

  @override
  void build() {
    ref.listen(habitsProvider, (previous, next) {
      if (!next.loaded) return;
      if (previous != null &&
          previous.loaded &&
          identical(previous.habits, next.habits) &&
          previous.hijriAdjust == next.hijriAdjust) {
        return;
      }
      _queue();
    }, fireImmediately: true);
  }

  /// Rescheduling one at a time.
  void _queue() {
    _running = (_running ?? Future<void>.value()).then((_) => _reschedule());
  }

  DailyReminderScheduler get _scheduler =>
      ref.read(dailyReminderSchedulerProvider);

  Future<void> _reschedule() async {
    if (!ref.mounted) return;
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    await scheduler.initialize();
    final storage = ref.read(browserStorageProvider);
    if (!_restored) {
      _restored = true;
      final raw = await storage.getString(idsKey);
      if (raw != null) {
        _scheduled = [for (final i in jsonDecode(raw) as List) i as int];
      }
    }
    await scheduler.cancelIds(_scheduled);
    final s = ref.read(habitsProvider);
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    final now = ref.read(memorizationClockProvider)();
    final ids = <int>[];
    var next = firstId;
    for (final habit in s.habits) {
      scheduler.onOpen(habitPayload(habit.id), () => _open(habit.id));
      if (!habit.remindersOn) continue;
      // The morning and evening athkar's: Athkar's own reminder, not a
      // second one (AthkarHabitReminderSync).
      if (athkarTimeOfHabit(habit) != null) continue;
      final name = habitName(l10n, habit);
      String body(HabitReminder r) => switch (r.kind) {
        HabitReminderKind.fastTomorrow => l10n.habitsFastTomorrowBody(name),
        HabitReminderKind.suhoor => l10n.habitsSuhoorBody(name),
        HabitReminderKind.reminder => l10n.habitsReminderBody(name),
      };
      for (final r in habit.reminders) {
        final hour = r.minutes ~/ 60, minute = r.minutes % 60;
        Future<void> repeat({int? weekday}) async {
          final id = next++;
          ids.add(id);
          await scheduler.scheduleRepeating(
            id: id,
            weekday: weekday,
            hour: hour,
            minute: minute,
            title: name,
            body: body(r),
            channelId: 'habit_reminder',
            channelName: l10n.habitsReminderChannel,
            payload: habitPayload(habit.id),
          );
        }

        switch (habit.schedule) {
          case DailySchedule():
            await repeat();
          case WeekdaysSchedule(:final days):
            for (final d in days) {
              // The day before a Monday: a Sunday.
              await repeat(weekday: r.dayBefore ? (d + 5) % 7 + 1 : d);
            }
          case HijriDaysSchedule() || HijriDatesSchedule():
            for (var i = 0; i <= hijriAhead; i++) {
              final day = DateTime(now.year, now.month, now.day + i);
              if (!s.dueOn(habit, day)) continue;
              final at = DateTime(
                day.year,
                day.month,
                day.day - (r.dayBefore ? 1 : 0),
                hour,
                minute,
              );
              if (!at.isAfter(now)) continue;
              final id = next++;
              ids.add(id);
              await scheduler.scheduleOnce(
                id: id,
                at: at,
                title: name,
                body: body(r),
                channelId: 'habit_reminder',
                channelName: l10n.habitsReminderChannel,
                payload: habitPayload(habit.id),
              );
            }
        }
      }
    }
    _scheduled = ids;
    await storage.setString(idsKey, jsonEncode(ids));
  }

  /// A tap on [id]'s reminder.
  void _open(String id) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      final habit = ref.read(habitsProvider).habit(id);
      final router = ref.read(appRouterProvider);
      switch (habit == null ? null : habitTemplate(habit.template)?.link) {
        case AthkarLink(:final chapter):
          router.go(AppRoutes.home);
          unawaited(router.push(AppRoutes.athkarCategory(chapter)));
        case SurahLink(:final surah):
          router.go(AppRoutes.home);
          unawaited(router.push('${AppRoutes.home}/surah/$surah'));
        case ReadingLink():
          router.go(AppRoutes.quran);
        case MemorizeLink():
          router.go(AppRoutes.memorize);
        case null:
          router.go(AppRoutes.home);
          if (habit != null) {
            unawaited(router.push(AppRoutes.habit(habit.id)));
          }
      }
    });
  }
}

final habitRemindersProvider = NotifierProvider<HabitRemindersController, void>(
  HabitRemindersController.new,
);

/// The athkar time a habit's reminder is (the morning or evening athkar's),
/// if it is one of those.
AthkarTime? athkarTimeOfHabit(Habit habit) =>
    switch (habitTemplate(habit.template)?.sync) {
      HabitSync.athkarMorning => AthkarTime.morning,
      HabitSync.athkarEvening => AthkarTime.evening,
      _ => null,
    };

/// The morning and evening athkar habits' reminders and Athkar's own are
/// one (owner, 2026-11-22: "not duplicated, in sync"): Athkar's reminder
/// is the one that notifies; a habit's switch or time changes it, and it
/// changes the habit's — whichever is set, both show it.
class AthkarHabitReminderSync extends Notifier<void> {
  @override
  void build() {
    ref.listen(habitsProvider, (previous, next) {
      for (final habit in next.habits) {
        final time = athkarTimeOfHabit(habit);
        if (time == null) continue;
        final before = previous?.habit(habit.id);
        final minutes = habit.reminders.firstOrNull?.minutes;
        final on = habit.remindersOn && minutes != null;
        // Changed in the habit (or just added): Athkar's reminder follows.
        if (before != null &&
            before.remindersOn == habit.remindersOn &&
            before.reminders.firstOrNull?.minutes == minutes) {
          continue;
        }
        final athkar = ref.read(athkarReminderProvider)[time]!;
        final controller = ref.read(athkarReminderProvider.notifier);
        if (minutes != null && athkar.minutes != minutes) {
          unawaited(controller.setTime(time, minutes));
        }
        if (athkar.enabled != on) {
          unawaited(controller.setEnabled(time, on));
        }
      }
    });
    ref.listen(athkarReminderProvider, (previous, next) {
      for (final MapEntry(key: time, value: setting) in next.entries) {
        if (previous?[time] == setting) continue;
        for (final habit in ref.read(habitsProvider).habits) {
          if (athkarTimeOfHabit(habit) != time) continue;
          final first = habit.reminders.firstOrNull;
          // Already the same: nothing to do (no echo back).
          if (habit.remindersOn == setting.enabled &&
              first?.minutes == setting.minutes) {
            continue;
          }
          ref
              .read(habitsProvider.notifier)
              .update(
                habit.copyWith(
                  remindersOn: setting.enabled,
                  reminders: [
                    first?.withMinutes(setting.minutes) ??
                        HabitReminder(minutes: setting.minutes),
                    ...habit.reminders.skip(1),
                  ],
                ),
              );
        }
      }
    });
  }
}

final athkarHabitReminderSyncProvider =
    NotifierProvider<AthkarHabitReminderSync, void>(
      AthkarHabitReminderSync.new,
    );
