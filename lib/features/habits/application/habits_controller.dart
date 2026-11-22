import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import '../domain/hijri.dart';
import '../../athkar/application/athkar_progress.dart';
import '../../athkar/data/athkar_source.dart';
import '../../khatmah/application/khatmah_controller.dart';
import '../../../memorization/application/memorization_progress.dart';

/// The habits kept, their log (each day's amount: done once there), and
/// the Hijri calendar's adjustment.
@immutable
class HabitsState {
  const HabitsState({
    this.habits = const [],
    this.log = const {},
    this.hijriAdjust = 0,
    this.loaded = false,
    this.auto = const {},
  });

  final List<Habit> habits;

  /// Habit id → day ("2026-11-21") → amount (≥ 1: done).
  final Map<String, Map<String, int>> log;

  /// Days the Hijri date is moved by (−1, 0, +1).
  final int hijriAdjust;

  /// Read back from the phone (until then: none shown as missing).
  final bool loaded;

  /// What the rest of the app did each day, for the habits in step with
  /// it ([HabitSync]): the khatmah's pages read, the ayahs recited from
  /// memory.
  final Map<HabitSync, Map<String, int>> auto;

  Habit? habit(String id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// [habit]'s amount on [day] (`null`: not done) — as ticked, else as
  /// the rest of the app has it (a habit in step with it).
  int? amountOn(String habit, String day) {
    final logged = log[habit]?[day];
    if (logged != null) return logged;
    final sync = habitTemplate(this.habit(habit)?.template)?.sync;
    if (sync == null) return null;
    final a = auto[sync]?[day];
    return a == null || a <= 0 ? null : a;
  }

  /// Whether [habit] is due on [date]: from the day it was added, by its
  /// schedule.
  bool dueOn(Habit habit, DateTime date) =>
      habitDay(date).compareTo(habit.since) >= 0 &&
      habit.schedule.dueOn(date, hijriOf(date, adjust: hijriAdjust));

  HabitsState copyWith({
    List<Habit>? habits,
    Map<String, Map<String, int>>? log,
    int? hijriAdjust,
    Map<HabitSync, Map<String, int>>? auto,
    bool? loaded,
  }) => HabitsState(
    habits: habits ?? this.habits,
    log: log ?? this.log,
    hijriAdjust: hijriAdjust ?? this.hijriAdjust,
    loaded: loaded ?? true,
    auto: auto ?? this.auto,
  );
}

/// The user's habits (owner, 2026-11-21): ready-made or their own, each
/// ticked day by day — today, or a day gone by — with how much.
class HabitsController extends Notifier<HabitsState> {
  static const storageKey = 'habits.v1';

  @override
  HabitsState build() {
    // In step with the rest of the app (owner, 2026-11-21).
    ref.listen(khatmahProvider, (_, next) {
      final k = next.value;
      final pages = <String, int>{};
      for (final day in k?.readOn.values ?? const <String>[]) {
        pages[day] = (pages[day] ?? 0) + 1;
      }
      _setAuto(HabitSync.khatmah, pages);
    }, fireImmediately: true);
    ref.listen(dailyRecitedProvider, (_, next) {
      _setAuto(HabitSync.memorization, {
        for (final e in (next.value ?? const <DateTime, int>{}).entries)
          habitDay(e.key): e.value,
      });
    }, fireImmediately: true);
    ref.listen(athkarProgressProvider, _onAthkar);
    unawaited(_restore());
    return const HabitsState();
  }

  void _setAuto(HabitSync sync, Map<String, int> days) {
    final auto = {...stateOrNull?.auto ?? const {}, sync: days};
    if (stateOrNull == null) {
      _pendingAuto = auto;
      return;
    }
    state = state.copyWith(auto: auto, loaded: state.loaded);
  }

  /// (Set before the first state: kept for it.)
  Map<HabitSync, Map<String, int>> _pendingAuto = const {};

  /// An athkar chapter finished today in Athkar: its habits ticked —
  /// Morning & Evening before 14:00 the morning's, from then the
  /// evening's; Before sleeping, the night's.
  void _onAthkar(Map<int, int>? before, Map<int, int> now) {
    final book = ref.read(athkarBookProvider).value;
    if (book == null) return;
    bool done(int chapter, Map<int, int>? counts) {
      final c = book.category(chapter);
      if (c == null || counts == null) return false;
      final (:done, :of) = athkarDone(c, counts);
      return done == of;
    }

    final clock = _now;
    final today = habitDay(clock);
    void tickSynced(HabitSync sync) {
      for (final h in state.habits) {
        if (habitTemplate(h.template)?.sync == sync &&
            state.log[h.id]?[today] == null) {
          tick(h, today, amount: 1);
        }
      }
    }

    for (final chapter in const [27, 28]) {
      if (!done(chapter, now) || done(chapter, before)) continue;
      if (chapter == 28) {
        tickSynced(HabitSync.athkarSleep);
      } else {
        tickSynced(
          clock.hour < 14 ? HabitSync.athkarMorning : HabitSync.athkarEvening,
        );
      }
    }
  }

  DateTime get _now => ref.read(memorizationClockProvider)();

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    if (!ref.mounted) return;
    if (raw == null) {
      state = state.copyWith(auto: {..._pendingAuto, ...state.auto});
      return;
    }
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      state = HabitsState(
        habits: [
          for (final h in json['habits']! as List<Object?>)
            Habit.fromJson(h! as Map<String, Object?>),
        ],
        log: {
          for (final MapEntry(:key, :value)
              in (json['log']! as Map<String, Object?>).entries)
            key: {
              for (final e in (value! as Map<String, Object?>).entries)
                e.key: e.value! as int,
            },
        },
        hijriAdjust: json['hijriAdjust'] as int? ?? 0,
        loaded: true,
        auto: {..._pendingAuto, ...state.auto},
      );
    } on Object {
      state = state.copyWith();
    }
  }

  void _save(HabitsState next) {
    state = next;
    unawaited(
      ref
          .read(browserStorageProvider)
          .setString(
            storageKey,
            jsonEncode({
              'habits': [for (final h in next.habits) h.toJson()],
              'log': next.log,
              'hijriAdjust': next.hijriAdjust,
            }),
          ),
    );
  }

  /// A new habit's id: unique among the kept.
  String _newId() {
    var n = _now.millisecondsSinceEpoch;
    while (state.habits.any((h) => h.id == 'h$n')) {
      n++;
    }
    return 'h$n';
  }

  /// [template] added, as it is or with the user's choices.
  Habit addTemplate(
    HabitTemplate template, {
    HabitSchedule? schedule,
    int? target,
    List<HabitReminder>? reminders,
  }) {
    final habit = Habit(
      id: _newId(),
      template: template.id,
      schedule: schedule ?? template.schedule,
      target: target ?? template.target,
      unit: template.unit,
      reminders: reminders ?? template.reminders,
      since: habitDay(_now),
    );
    _save(state.copyWith(habits: [...state.habits, habit]));
    return habit;
  }

  /// A habit of the user's own.
  Habit addOwn({
    required String name,
    required int icon,
    required HabitSchedule schedule,
    int? target,
    HabitUnit unit = HabitUnit.none,
    List<HabitReminder> reminders = const [],
  }) {
    final habit = Habit(
      id: _newId(),
      name: name,
      icon: icon,
      schedule: schedule,
      target: unit == HabitUnit.none ? null : target,
      unit: unit,
      reminders: reminders,
      since: habitDay(_now),
    );
    _save(state.copyWith(habits: [...state.habits, habit]));
    return habit;
  }

  void update(Habit habit) => _save(
    state.copyWith(
      habits: [for (final h in state.habits) h.id == habit.id ? habit : h],
    ),
  );

  /// Gone, with its log.
  void remove(String id) => _save(
    state.copyWith(
      habits: [
        for (final h in state.habits)
          if (h.id != id) h,
      ],
      log: {...state.log}..remove(id),
    ),
  );

  /// How much a tick gives [habit]: the last amount logged (owner,
  /// 2026-11-21), else its target, else once.
  int defaultAmount(Habit habit) {
    final days = state.log[habit.id];
    if (days != null && days.isNotEmpty) {
      final last = (days.keys.toList()..sort()).last;
      return days[last]!;
    }
    return habit.target ?? 1;
  }

  /// [habit] done on [day] — [amount] of it (else [defaultAmount]).
  void tick(Habit habit, String day, {int? amount}) {
    final a = amount ?? defaultAmount(habit);
    if (a <= 0) return untick(habit, day);
    _save(
      state.copyWith(
        log: {
          ...state.log,
          habit.id: {...?state.log[habit.id], day: a},
        },
      ),
    );
  }

  /// [habit] not done on [day].
  void untick(Habit habit, String day) {
    final days = {...?state.log[habit.id]}..remove(day);
    _save(state.copyWith(log: {...state.log, habit.id: days}));
  }

  /// One more of [habit] on [day] (a wird counted): its count after.
  int countOne(Habit habit, String day) {
    final now = (state.amountOn(habit.id, day) ?? 0) + 1;
    tick(habit, day, amount: now);
    return now;
  }

  void setHijriAdjust(int days) =>
      _save(state.copyWith(hijriAdjust: days.clamp(-1, 1)));
}

final habitsProvider = NotifierProvider<HabitsController, HabitsState>(
  HabitsController.new,
);

/// A day's due habits and how many are done.
({int done, int due}) habitsDay(HabitsState s, DateTime date) {
  final day = habitDay(date);
  var done = 0, due = 0;
  for (final h in s.habits) {
    if (!s.dueOn(h, date)) continue;
    due++;
    if (s.amountOn(h.id, day) != null) done++;
  }
  return (done: done, due: due);
}

/// [habit] over [from]..[to] (both included): its due days, those done,
/// and the amounts logged.
({int done, int due, int total}) habitPeriod(
  HabitsState s,
  Habit habit,
  DateTime from,
  DateTime to,
) {
  var done = 0, due = 0, total = 0;
  for (
    var d = DateTime(from.year, from.month, from.day);
    !d.isAfter(to);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final amount = s.amountOn(habit.id, habitDay(d));
    if (s.dueOn(habit, d)) {
      due++;
      if (amount != null) done++;
    }
    total += amount ?? 0;
  }
  return (done: done, due: due, total: total);
}

/// [habit]'s due days done in a row up to [today] (today not done yet
/// doesn't break it).
int habitStreak(HabitsState s, Habit habit, DateTime today) {
  var streak = 0;
  final since = habitDate(habit.since);
  for (
    var d = DateTime(today.year, today.month, today.day);
    !d.isBefore(since);
    d = DateTime(d.year, d.month, d.day - 1)
  ) {
    if (!s.dueOn(habit, d)) continue;
    if (s.amountOn(habit.id, habitDay(d)) != null) {
      streak++;
    } else if (habitDay(d) != habitDay(today)) {
      break;
    }
  }
  return streak;
}

/// [habit]'s longest run of due days done, from the day it was added to
/// [today].
int habitBestStreak(HabitsState s, Habit habit, DateTime today) {
  var best = 0, run = 0;
  for (
    var d = habitDate(habit.since);
    !d.isAfter(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (!s.dueOn(habit, d)) continue;
    if (s.amountOn(habit.id, habitDay(d)) != null) {
      run++;
      if (run > best) best = run;
    } else if (habitDay(d) != habitDay(today)) {
      run = 0;
    }
  }
  return best;
}

/// The habit's template, if any (shorthand).
HabitTemplate? templateOf(Habit h) => habitTemplate(h.template);
