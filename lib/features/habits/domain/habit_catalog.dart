import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import 'habit.dart';

/// The catalog's groups.
enum HabitGroup {
  prayer(Icons.mosque_outlined),
  fasting(Icons.nights_stay_outlined),
  remembrance(Icons.record_voice_over_outlined),
  quran(Icons.menu_book_outlined),
  family(Icons.favorite_outline_rounded),
  own(Icons.edit_outlined);

  const HabitGroup(this.icon);

  final IconData icon;

  String title(AppLocalizations l10n) => switch (this) {
    prayer => l10n.habitsGroupPrayer,
    fasting => l10n.habitsGroupFasting,
    remembrance => l10n.habitsGroupRemembrance,
    quran => l10n.habitsGroupQuran,
    family => l10n.habitsGroupFamily,
    own => l10n.habitsGroupOwn,
  };
}

/// Where a habit is done in the app: a tap on its reminder (or its Open)
/// goes there (owner, 2026-11-21).
sealed class HabitLink {
  const HabitLink();
}

/// An athkar chapter (its id).
class AthkarLink extends HabitLink {
  const AthkarLink(this.chapter);
  final int chapter;
}

/// A surah, from its start.
class SurahLink extends HabitLink {
  const SurahLink(this.surah);
  final int surah;
}

/// The Mushaf, where reading was left.
class ReadingLink extends HabitLink {
  const ReadingLink();
}

/// The Memorize tab.
class MemorizeLink extends HabitLink {
  const MemorizeLink();
}

/// A ready-made habit: its look, when it is due, how much, its reminders
/// (each changeable when it is added).
class HabitTemplate {
  const HabitTemplate({
    required this.id,
    required this.group,
    required this.icon,
    this.schedule = const DailySchedule(),
    this.target,
    this.unit = HabitUnit.none,
    this.reminders = const [],
    this.link,
    this.phrase,
    this.presets = const [],
    this.sync,
  });

  final String id;
  final HabitGroup group;
  final IconData icon;
  final HabitSchedule schedule;
  final int? target;
  final HabitUnit unit;
  final List<HabitReminder> reminders;
  final HabitLink? link;

  /// A wird's words, said and counted (in Arabic, in every language).
  final String? phrase;

  /// Its target's ready-made choices (owner, 2026-11-21: 2, 4, 6, 8 rakʿahs
  /// — Witr odd: 1, 3, 5…), any other one typed.
  final List<int> presets;

  /// What keeps it in step with the rest of the app (ticked there, ticked
  /// here).
  final HabitSync? sync;
}

/// Where a habit is done in step with the app (owner, 2026-11-21: "not
/// two separate concepts").
enum HabitSync {
  /// The khatmah's pages read that day.
  khatmah,

  /// The ayahs recited from memory that day (Memorize's own count).
  memorization,

  /// Athkar's Morning & Evening chapter finished before 14:00.
  athkarMorning,

  /// …finished from 14:00 on.
  athkarEvening,

  /// Athkar's Before sleeping chapter finished.
  athkarSleep,
}

/// A fast's reminders: the evening before, and suhoor before dawn.
const _fast = [
  HabitReminder(
    minutes: 21 * 60,
    dayBefore: true,
    kind: HabitReminderKind.fastTomorrow,
  ),
  HabitReminder(minutes: 4 * 60, kind: HabitReminderKind.suhoor),
];

/// Prayers prayed two by two.
const _even = [2, 4, 6, 8];

HabitReminder _at(int hour, [int minute = 0]) =>
    HabitReminder(minutes: hour * 60 + minute);

/// The ready-made habits, by group (owner, 2026-11-21: prayers, fasts,
/// sadaqa, parents and family, athkar, a daily wird, the Quran…).
final habitCatalog = <HabitTemplate>[
  // Prayer.
  HabitTemplate(
    id: 'duha',
    group: HabitGroup.prayer,
    icon: Icons.wb_sunny_outlined,
    target: 2,
    unit: HabitUnit.rakahs,
    presets: _even,
    reminders: [_at(9)],
  ),
  HabitTemplate(
    id: 'qiyam',
    group: HabitGroup.prayer,
    icon: Icons.nightlight_outlined,
    target: 2,
    unit: HabitUnit.rakahs,
    presets: _even,
    reminders: [_at(3, 30)],
  ),
  HabitTemplate(
    id: 'witr',
    group: HabitGroup.prayer,
    icon: Icons.dark_mode_outlined,
    target: 3,
    unit: HabitUnit.rakahs,
    presets: [1, 3, 5, 7, 9],
    reminders: [_at(22)],
  ),
  const HabitTemplate(
    id: 'rawatib',
    group: HabitGroup.prayer,
    icon: Icons.mosque_outlined,
    target: 12,
    unit: HabitUnit.rakahs,
    presets: [10, 12],
  ),
  const HabitTemplate(
    id: 'tasbihAfterSalah',
    group: HabitGroup.prayer,
    icon: Icons.touch_app_outlined,
    target: 5,
    unit: HabitUnit.times,
    presets: [1, 2, 3, 4, 5],
  ),
  // Fasting.
  const HabitTemplate(
    id: 'fastMonThu',
    group: HabitGroup.fasting,
    icon: Icons.calendar_view_week_outlined,
    schedule: WeekdaysSchedule({DateTime.monday, DateTime.thursday}),
    reminders: _fast,
  ),
  const HabitTemplate(
    id: 'fastBeed',
    group: HabitGroup.fasting,
    icon: Icons.brightness_2_outlined,
    schedule: HijriDaysSchedule({13, 14, 15}),
    reminders: _fast,
  ),
  const HabitTemplate(
    id: 'fastArafah',
    group: HabitGroup.fasting,
    icon: Icons.landscape_outlined,
    schedule: HijriDatesSchedule([(month: 12, day: 9)]),
    reminders: _fast,
  ),
  const HabitTemplate(
    id: 'fastAshura',
    group: HabitGroup.fasting,
    icon: Icons.event_outlined,
    schedule: HijriDatesSchedule([(month: 1, day: 9), (month: 1, day: 10)]),
    reminders: _fast,
  ),
  // Remembrance.
  HabitTemplate(
    id: 'athkarMorning',
    group: HabitGroup.remembrance,
    icon: Icons.wb_sunny_outlined,
    reminders: [_at(6, 30)],
    link: const AthkarLink(27),
    sync: HabitSync.athkarMorning,
  ),
  HabitTemplate(
    id: 'athkarEvening',
    group: HabitGroup.remembrance,
    icon: Icons.wb_twilight_rounded,
    reminders: [_at(17, 30)],
    link: const AthkarLink(27),
    sync: HabitSync.athkarEvening,
  ),
  HabitTemplate(
    id: 'athkarSleep',
    group: HabitGroup.remembrance,
    icon: Icons.bedtime_outlined,
    reminders: [_at(22, 30)],
    link: const AthkarLink(28),
    sync: HabitSync.athkarSleep,
  ),
  for (final (id, phrase) in const [
    ('wirdSalawat', 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ'),
    ('wirdSubhanBihamdih', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ'),
    ('wirdSubhanAzim', 'سُبْحَانَ اللَّهِ الْعَظِيمِ'),
    ('wirdIstighfar', 'أَسْتَغْفِرُ اللَّهَ'),
    ('wirdTahlil', 'لَا إِلَٰهَ إِلَّا اللَّهُ'),
    ('wirdTakbir', 'اللَّهُ أَكْبَرُ'),
    ('wirdTahmid', 'الْحَمْدُ لِلَّهِ'),
    ('wirdHawqala', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'),
  ])
    HabitTemplate(
      id: id,
      group: HabitGroup.remembrance,
      icon: Icons.blur_circular_outlined,
      target: 100,
      unit: HabitUnit.times,
      presets: const [33, 100, 300, 1000],
      reminders: [_at(20)],
      phrase: phrase,
    ),
  HabitTemplate(
    id: 'dua',
    group: HabitGroup.remembrance,
    icon: Icons.front_hand_outlined,
    reminders: [_at(21)],
  ),
  // Quran.
  HabitTemplate(
    id: 'quranPages',
    group: HabitGroup.quran,
    icon: Icons.menu_book_outlined,
    target: 5,
    unit: HabitUnit.pages,
    reminders: [_at(20)],
    link: const ReadingLink(),
    presets: const [1, 2, 5, 10, 20],
    sync: HabitSync.khatmah,
  ),
  const HabitTemplate(
    id: 'memorize',
    group: HabitGroup.quran,
    icon: Icons.school_outlined,
    target: 5,
    unit: HabitUnit.ayahs,
    link: MemorizeLink(),
    presets: [1, 3, 5, 10, 20],
    sync: HabitSync.memorization,
  ),
  HabitTemplate(
    id: 'kahf',
    group: HabitGroup.quran,
    icon: Icons.landscape_outlined,
    schedule: const WeekdaysSchedule({DateTime.friday}),
    reminders: [_at(10)],
    link: const SurahLink(18),
  ),
  HabitTemplate(
    id: 'mulk',
    group: HabitGroup.quran,
    icon: Icons.nights_stay_outlined,
    reminders: [_at(22)],
    link: const SurahLink(67),
  ),
  // Charity and family.
  HabitTemplate(
    id: 'sadaqa',
    group: HabitGroup.family,
    icon: Icons.volunteer_activism_outlined,
    target: 1,
    unit: HabitUnit.amount,
    presets: const [1, 5, 10, 20],
    reminders: [_at(10)],
  ),
  HabitTemplate(
    id: 'parents',
    group: HabitGroup.family,
    icon: Icons.call_outlined,
    reminders: [_at(18)],
  ),
  HabitTemplate(
    id: 'kinship',
    group: HabitGroup.family,
    icon: Icons.diversity_3_outlined,
    schedule: const WeekdaysSchedule({DateTime.friday}),
    reminders: [_at(17)],
  ),
];

final _byId = {for (final t in habitCatalog) t.id: t};

/// Ready-made choices for a habit's target when its template has none.
List<int> unitPresets(HabitUnit unit) => switch (unit) {
  HabitUnit.none => const [],
  HabitUnit.times => const [33, 100, 300, 1000],
  HabitUnit.rakahs => _even,
  HabitUnit.amount => const [1, 5, 10, 20],
  HabitUnit.pages => const [1, 2, 5, 10, 20],
  HabitUnit.minutes => const [5, 10, 15, 30],
  HabitUnit.ayahs => const [1, 3, 5, 10, 20],
};

HabitTemplate? habitTemplate(String? id) => id == null ? null : _byId[id];

/// A ready-made habit's name.
String habitTemplateName(AppLocalizations l10n, HabitTemplate t) =>
    t.phrase ??
    switch (t.id) {
      'duha' => l10n.habitDuha,
      'qiyam' => l10n.habitQiyam,
      'witr' => l10n.habitWitr,
      'rawatib' => l10n.habitRawatib,
      'tasbihAfterSalah' => l10n.habitTasbihAfterSalah,
      'fastMonThu' => l10n.habitFastMonThu,
      'fastBeed' => l10n.habitFastBeed,
      'fastArafah' => l10n.habitFastArafah,
      'fastAshura' => l10n.habitFastAshura,
      'athkarMorning' => l10n.athkarMorningTitle,
      'athkarEvening' => l10n.athkarEveningTitle,
      'athkarSleep' => l10n.habitAthkarSleep,
      'dua' => l10n.habitDua,
      'quranPages' => l10n.habitQuranPages,
      'memorize' => l10n.habitMemorize,
      'kahf' => l10n.habitKahf,
      'mulk' => l10n.habitMulk,
      'sadaqa' => l10n.habitSadaqa,
      'parents' => l10n.habitParents,
      'kinship' => l10n.habitKinship,
      _ => t.id,
    };

/// A habit's name: its template's, or the user's own.
String habitName(AppLocalizations l10n, Habit habit) {
  final t = habitTemplate(habit.template);
  return t == null ? (habit.name ?? '') : habitTemplateName(l10n, t);
}

/// The icons a habit of one's own can have.
const habitIcons = <IconData>[
  Icons.check_circle_outline_rounded,
  Icons.mosque_outlined,
  Icons.menu_book_outlined,
  Icons.record_voice_over_outlined,
  Icons.favorite_outline_rounded,
  Icons.volunteer_activism_outlined,
  Icons.nights_stay_outlined,
  Icons.wb_sunny_outlined,
  Icons.water_drop_outlined,
  Icons.directions_walk_rounded,
  Icons.call_outlined,
  Icons.school_outlined,
  Icons.restaurant_outlined,
  Icons.bedtime_outlined,
  Icons.spa_outlined,
  // Sport (owner, 2026-11-21).
  Icons.directions_run_rounded,
  Icons.fitness_center_rounded,
  Icons.directions_bike_rounded,
  Icons.pool_rounded,
  Icons.hiking_rounded,
];

/// A habit's icon.
IconData habitIcon(Habit habit) {
  final t = habitTemplate(habit.template);
  if (t != null) return t.icon;
  return habitIcons.firstWhere(
    (i) => i.codePoint == habit.icon,
    orElse: () => habitIcons.first,
  );
}
