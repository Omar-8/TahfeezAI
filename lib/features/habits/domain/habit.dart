import 'package:flutter/foundation.dart';

import 'hijri.dart';

/// When a habit is due.
sealed class HabitSchedule {
  const HabitSchedule();

  factory HabitSchedule.fromJson(Map<String, Object?> json) =>
      switch (json['kind']) {
        'weekdays' => WeekdaysSchedule({
          for (final d in json['days']! as List<Object?>) d! as int,
        }),
        'hijriDays' => HijriDaysSchedule({
          for (final d in json['days']! as List<Object?>) d! as int,
        }),
        'hijriDates' => HijriDatesSchedule([
          for (final d in json['dates']! as List<Object?>)
            (
              month: (d! as List<Object?>)[0]! as int,
              day: (d as List<Object?>)[1]! as int,
            ),
        ]),
        _ => const DailySchedule(),
      };

  Map<String, Object?> toJson();

  /// Whether it is due on [date] (local), its Hijri date [hijri].
  bool dueOn(DateTime date, HijriDate hijri);
}

/// Every day.
class DailySchedule extends HabitSchedule {
  const DailySchedule();

  @override
  Map<String, Object?> toJson() => {'kind': 'daily'};

  @override
  bool dueOn(DateTime date, HijriDate hijri) => true;

  @override
  bool operator ==(Object other) => other is DailySchedule;
  @override
  int get hashCode => 0;
}

/// Chosen weekdays ([DateTime.monday] … [DateTime.sunday]).
class WeekdaysSchedule extends HabitSchedule {
  const WeekdaysSchedule(this.days);

  final Set<int> days;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'weekdays',
    'days': days.toList()..sort(),
  };

  @override
  bool dueOn(DateTime date, HijriDate hijri) => days.contains(date.weekday);

  @override
  bool operator ==(Object other) =>
      other is WeekdaysSchedule && setEquals(other.days, days);
  @override
  int get hashCode => Object.hashAllUnordered(days);
}

/// Days of every Hijri month (Ayyam al-Beed: 13, 14, 15).
class HijriDaysSchedule extends HabitSchedule {
  const HijriDaysSchedule(this.days);

  final Set<int> days;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'hijriDays',
    'days': days.toList()..sort(),
  };

  @override
  bool dueOn(DateTime date, HijriDate hijri) => days.contains(hijri.day);

  @override
  bool operator ==(Object other) =>
      other is HijriDaysSchedule && setEquals(other.days, days);
  @override
  int get hashCode => Object.hashAllUnordered(days);
}

/// Days of the Hijri year (ʿArafah: 9 Dhu al-Hijjah).
class HijriDatesSchedule extends HabitSchedule {
  const HijriDatesSchedule(this.dates);

  final List<({int month, int day})> dates;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'hijriDates',
    'dates': [
      for (final d in dates) [d.month, d.day],
    ],
  };

  @override
  bool dueOn(DateTime date, HijriDate hijri) =>
      dates.any((d) => d.month == hijri.month && d.day == hijri.day);

  @override
  bool operator ==(Object other) =>
      other is HijriDatesSchedule && listEquals(other.dates, dates);
  @override
  int get hashCode => Object.hashAll(dates);
}

/// What a habit's amount counts.
enum HabitUnit {
  /// Done or not: no amount.
  none,

  /// Times (a wird: 100 ṣalawāt).
  times,
  rakahs,

  /// Money given (sadaqa), in the user's own currency.
  amount,
  pages,
  minutes,

  /// Ayahs recited from memory (Daily memorization, in step with
  /// Memorize's own count).
  ayahs,
}

/// What a reminder says.
enum HabitReminderKind {
  /// "Time for …" on the day.
  reminder,

  /// The evening before a fast: "Fasting tomorrow".
  fastTomorrow,

  /// Before dawn on a fast's day: "Suhoor".
  suhoor,
}

/// A reminder: at [minutes] after midnight, on the day — or the day
/// before ([dayBefore]).
@immutable
class HabitReminder {
  const HabitReminder({
    required this.minutes,
    this.dayBefore = false,
    this.kind = HabitReminderKind.reminder,
  });

  factory HabitReminder.fromJson(Map<String, Object?> json) => HabitReminder(
    minutes: json['minutes']! as int,
    dayBefore: json['dayBefore'] == true,
    kind: HabitReminderKind.values.byName(
      json['kind'] as String? ?? HabitReminderKind.reminder.name,
    ),
  );

  final int minutes;
  final bool dayBefore;
  final HabitReminderKind kind;

  HabitReminder withMinutes(int minutes) =>
      HabitReminder(minutes: minutes, dayBefore: dayBefore, kind: kind);

  Map<String, Object?> toJson() => {
    'minutes': minutes,
    if (dayBefore) 'dayBefore': true,
    'kind': kind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is HabitReminder &&
      other.minutes == minutes &&
      other.dayBefore == dayBefore &&
      other.kind == kind;
  @override
  int get hashCode => Object.hash(minutes, dayBefore, kind);
}

/// A habit the user keeps: from the catalog ([template]) or their own
/// ([name], [icon]); when it is due, its target, its reminders.
@immutable
class Habit {
  const Habit({
    required this.id,
    this.template,
    this.name,
    this.icon,
    required this.schedule,
    this.target,
    this.unit = HabitUnit.none,
    this.reminders = const [],
    this.remindersOn = true,
    required this.since,
  });

  factory Habit.fromJson(Map<String, Object?> json) => Habit(
    id: json['id']! as String,
    template: json['template'] as String?,
    name: json['name'] as String?,
    icon: json['icon'] as int?,
    schedule: HabitSchedule.fromJson(json['schedule']! as Map<String, Object?>),
    target: json['target'] as int?,
    unit: HabitUnit.values.byName(json['unit'] as String? ?? 'none'),
    reminders: [
      for (final r in json['reminders'] as List<Object?>? ?? const [])
        HabitReminder.fromJson(r! as Map<String, Object?>),
    ],
    remindersOn: json['remindersOn'] != false,
    since: json['since']! as String,
  );

  final String id;

  /// Its catalog entry's id (`null`: the user's own habit).
  final String? template;

  /// The user's own habit's name and icon (a Material icon's code point).
  final String? name;
  final int? icon;

  final HabitSchedule schedule;

  /// How much a day (4 rakʿahs, 100 times): `null`, just done.
  final int? target;
  final HabitUnit unit;
  final List<HabitReminder> reminders;

  /// Its reminders sent (they are kept, turned off).
  final bool remindersOn;

  /// The day it was added ("2026-11-21"): not due before.
  final String since;

  Habit copyWith({
    String? name,
    int? icon,
    HabitSchedule? schedule,
    int? Function()? target,
    HabitUnit? unit,
    List<HabitReminder>? reminders,
    bool? remindersOn,
  }) => Habit(
    id: id,
    template: template,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    schedule: schedule ?? this.schedule,
    target: target != null ? target() : this.target,
    unit: unit ?? this.unit,
    reminders: reminders ?? this.reminders,
    remindersOn: remindersOn ?? this.remindersOn,
    since: since,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'template': ?template,
    'name': ?name,
    'icon': ?icon,
    'schedule': schedule.toJson(),
    'target': ?target,
    'unit': unit.name,
    'reminders': [for (final r in reminders) r.toJson()],
    if (!remindersOn) 'remindersOn': false,
    'since': since,
  };
}

/// A day as habits keep it: "2026-11-21" (local).
String habitDay(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// "2026-11-21" back to its date.
DateTime habitDate(String day) {
  final p = day.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
