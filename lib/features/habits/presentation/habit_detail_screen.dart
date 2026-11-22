import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/bar_space.dart';
import '../../../core/ui/motion.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../../../quran/domain/models/quran_location.dart';
import '../application/habits_controller.dart';
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import 'habit_parts.dart';

/// Where a habit is done in the app, opened (owner, 2026-11-21).
void openHabitLink(BuildContext context, HabitLink link) => switch (link) {
  AthkarLink(:final chapter) => context.push(AppRoutes.athkarCategory(chapter)),
  SurahLink(:final surah) => goToQuranLocation(
    context,
    QuranLocation.surah(surah),
  ),
  ReadingLink() => context.go(AppRoutes.quran),
  MemorizeLink() => context.go(AppRoutes.memorize),
};

/// One habit: its month day by day (any day since it was added ticked or
/// unticked — owner, 2026-11-21: a day forgotten), how it goes, its target,
/// its days and its reminders; removed.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailState();
}

class _HabitDetailState extends ConsumerState<HabitDetailScreen> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(habitsProvider);
    final habit = s.habit(widget.id);
    if (habit == null) {
      return HabitsScaffold(
        title: l10n.habitsTitle,
        body: s.loaded
            ? const SizedBox.shrink()
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final controller = ref.read(habitsProvider.notifier);
    final now = ref.watch(memorizationClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final month = _month ?? DateTime(today.year, today.month);
    final template = templateOf(habit);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final (:done, :due, :total) = habitPeriod(
      s,
      habit,
      month,
      monthEnd.isAfter(today) ? today : monthEnd,
    );
    final streak = habitStreak(s, habit, today);
    final since = habitDate(habit.since);
    final locale = intlLocaleOf(Localizations.localeOf(context));
    final name = habitName(l10n, habit);

    return HabitsScaffold(
      title: l10n.habitsTitle,
      body: ListView(
        key: const ValueKey('habit-detail'),
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
        children: [
          Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              HabitIconChip(habitIcon(habit), size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const ValueKey('habit-name'),
                      textDirection: template?.phrase != null
                          ? TextDirection.rtl
                          : null,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        habitScheduleText(context, habit.schedule),
                        if (habit.target != null)
                          ?habitAmountText(l10n, habit.unit, habit.target!),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (habitSyncNote(l10n, template?.sync) case final note?)
            Padding(
              padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
              child: Row(
                key: const ValueKey('habit-sync'),
                spacing: TahfeezSpacing.xs,
                children: [
                  Icon(Icons.sync_rounded, size: 18, color: scheme.primary),
                  Expanded(
                    child: Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: TahfeezSpacing.md),
          Wrap(
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.xs,
            children: [
              if (template?.link case final link?)
                FilledButton.icon(
                  key: const ValueKey('habit-open'),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.habitsOpen),
                  onPressed: () => openHabitLink(context, link),
                ),
              if (template?.phrase != null)
                FilledButton.icon(
                  key: const ValueKey('habit-count'),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: Text(l10n.habitsCount),
                  onPressed: () => context.push(
                    '${AppRoutes.habitCount(habit.id)}?day=${habitDay(today)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.md),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.sm,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('habit-month-previous'),
                      tooltip: l10n.commonPrevious,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                      onPressed: () => setState(
                        () => _month = DateTime(month.year, month.month - 1),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMM(locale).format(month),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('habit-month-next'),
                      tooltip: l10n.commonNext,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                      onPressed:
                          month.year == today.year && month.month == today.month
                          ? null
                          : () => setState(
                              () => _month = DateTime(
                                month.year,
                                month.month + 1,
                              ),
                            ),
                    ),
                  ],
                ),
                _MonthGrid(
                  habit: habit,
                  state: s,
                  month: month,
                  today: today,
                  since: since,
                  onTap: (d) {
                    final key = habitDay(d);
                    if (s.amountOn(habit.id, key) != null) {
                      controller.untick(habit, key);
                    } else {
                      controller.tick(habit, key);
                    }
                  },
                  onLongPress: habit.unit == HabitUnit.none
                      ? null
                      : (d) async {
                          final key = habitDay(d);
                          final a = await askHabitAmount(
                            context,
                            initial:
                                s.amountOn(habit.id, key) ??
                                controller.defaultAmount(habit),
                            label: habitUnitName(l10n, habit.unit),
                          );
                          if (a != null) controller.tick(habit, key, amount: a);
                        },
                ),
                Text(
                  [
                    l10n.habitsDaysDone(done, due),
                    if (total > 0) ?habitAmountText(l10n, habit.unit, total),
                    if (streak > 0) l10n.habitsStreak(streak),
                  ].join(' · '),
                  key: const ValueKey('habit-month-stats'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TahfeezSpacing.md),
          _HabitStats(habit: habit, state: s, today: today),
          const SizedBox(height: TahfeezSpacing.md),
          _HabitSettings(habit: habit),
          const SizedBox(height: TahfeezSpacing.md),
          TextButton.icon(
            key: const ValueKey('habit-remove'),
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            label: Text(
              l10n.habitsRemove,
              style: TextStyle(color: scheme.error),
            ),
            onPressed: () async {
              final sure = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(l10n.habitsRemoveConfirm(name)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      key: const ValueKey('habit-remove-confirm'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.habitsRemove),
                    ),
                  ],
                ),
              );
              if (sure != true || !context.mounted) return;
              controller.remove(habit.id);
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}

/// A month, a week a row: each day the habit is due a circle — filled once
/// done; a day before it was added or still to come, not tappable.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.habit,
    required this.state,
    required this.month,
    required this.today,
    required this.since,
    required this.onTap,
    required this.onLongPress,
  });

  final Habit habit;
  final HabitsState state;
  final DateTime month, today, since;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime>? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = DateTime(month.year, month.month + 1, 0).day;
    // Weeks from the locale's first day (Monday here: as most calendars).
    final lead = (DateTime(month.year, month.month).weekday - 1) % 7;
    final cells = [
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
    ];
    return Column(
      children: [
        Row(
          children: [
            for (var w = 1; w <= 7; w++)
              Expanded(
                child: Text(
                  weekdayName(context, w),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final d in cells)
              if (d == null)
                const SizedBox.shrink()
              else
                _DayCell(
                  date: d,
                  due: state.dueOn(habit, d),
                  amount: state.amountOn(habit.id, habitDay(d)),
                  enabled: !d.isAfter(today) && !d.isBefore(since),
                  today: habitDay(d) == habitDay(today),
                  onTap: () => onTap(d),
                  onLongPress: onLongPress == null
                      ? null
                      : () => onLongPress!(d),
                ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.due,
    required this.amount,
    required this.enabled,
    required this.today,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime date;
  final bool due, enabled, today;
  final int? amount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = amount != null;
    final color = done
        ? scheme.primary
        : due && enabled
        ? scheme.primaryContainer
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: InkWell(
        key: ValueKey('habit-day-${habitDay(date)}'),
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: today ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: Text(
            '${date.day}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: done
                  ? scheme.onPrimary
                  : enabled
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant.withValues(alpha: 0.5),
              fontWeight: due ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// A habit's target, its days (every day or chosen weekdays), and its
/// reminders.
class _HabitSettings extends ConsumerWidget {
  const _HabitSettings({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(habitsProvider.notifier);
    final theme = Theme.of(context);
    final weekdays = switch (habit.schedule) {
      DailySchedule() => {1, 2, 3, 4, 5, 6, 7},
      WeekdaysSchedule(:final days) => days,
      _ => null,
    };
    String time(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (habit.unit != HabitUnit.none)
            HabitTargetPicker(
              key: const ValueKey('habit-target'),
              unit: habit.unit,
              presets: (templateOf(habit)?.presets.isNotEmpty ?? false)
                  ? templateOf(habit)!.presets
                  : unitPresets(habit.unit),
              value: habit.target ?? 1,
              onChanged: (v) =>
                  controller.update(habit.copyWith(target: () => v)),
            ),
          if (weekdays != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
              child: Text(
                l10n.habitsSchedule,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    key: ValueKey('habit-weekday-$d'),
                    label: Text(weekdayName(context, d)),
                    selected: weekdays.contains(d),
                    onSelected: (on) {
                      final next = {...weekdays};
                      on ? next.add(d) : next.remove(d);
                      if (next.isEmpty) return;
                      controller.update(
                        habit.copyWith(
                          schedule: next.length == 7
                              ? const DailySchedule()
                              : WeekdaysSchedule(next),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          SwitchListTile(
            key: const ValueKey('habit-reminders'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.habitsRemindersOn),
            value: habit.remindersOn && habit.reminders.isNotEmpty,
            onChanged: (on) {
              if (on && habit.reminders.isEmpty) {
                controller.update(
                  habit.copyWith(
                    remindersOn: true,
                    reminders: const [HabitReminder(minutes: 20 * 60)],
                  ),
                );
              } else {
                controller.update(habit.copyWith(remindersOn: on));
              }
            },
          ),
          if (habit.remindersOn)
            for (final (i, r) in habit.reminders.indexed)
              ListTile(
                key: ValueKey('habit-reminder-$i'),
                contentPadding: const EdgeInsetsDirectional.only(start: 40),
                leading: const Icon(Icons.schedule),
                title: Text(time(r.minutes)),
                subtitle: r.dayBefore ? Text(l10n.habitsDayBefore) : null,
                trailing: IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => controller.update(
                    habit.copyWith(
                      reminders: [...habit.reminders]..removeAt(i),
                    ),
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: r.minutes ~/ 60,
                      minute: r.minutes % 60,
                    ),
                  );
                  if (picked == null) return;
                  controller.update(
                    habit.copyWith(
                      reminders: [
                        for (final (j, x) in habit.reminders.indexed)
                          j == i
                              ? x.withMinutes(picked.hour * 60 + picked.minute)
                              : x,
                      ],
                    ),
                  );
                },
              ),
          if (habit.remindersOn)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('habit-add-reminder'),
                icon: const Icon(Icons.add_alarm_outlined),
                label: Text(l10n.habitsAddReminder),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 20, minute: 0),
                  );
                  if (picked == null) return;
                  controller.update(
                    habit.copyWith(
                      reminders: [
                        ...habit.reminders,
                        HabitReminder(
                          minutes: picked.hour * 60 + picked.minute,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// How the habit has gone, as Memorize's progress shows its own: icons,
/// labels and numbers counting up as it appears (owner, 2026-11-21) —
/// all it gave (rakʿahs prayed, times said, pages, ayahs, days fasted…),
/// the days done, the streaks, this month.
class _HabitStats extends StatelessWidget {
  const _HabitStats({
    required this.habit,
    required this.state,
    required this.today,
  });

  final Habit habit;
  final HabitsState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final number = NumberFormat.decimalPattern(
      intlLocaleOf(Localizations.localeOf(context)),
    );
    final all = habitPeriod(state, habit, habitDate(habit.since), today);
    final month = habitPeriod(
      state,
      habit,
      DateTime(today.year, today.month),
      today,
    );
    final streak = habitStreak(state, habit, today);
    final best = habitBestStreak(state, habit, today);
    final fasting = templateOf(habit)?.group == HabitGroup.fasting;
    final (IconData totalIcon, String totalLabel) = switch (habit.unit) {
      HabitUnit.rakahs => (Icons.mosque_outlined, l10n.habitsTotalRakahs),
      HabitUnit.times => (Icons.touch_app_outlined, l10n.habitsTotalTimes),
      HabitUnit.pages => (Icons.menu_book_outlined, l10n.habitsTotalPages),
      HabitUnit.ayahs => (Icons.school_outlined, l10n.habitsTotalAyahs),
      HabitUnit.amount => (
        Icons.volunteer_activism_outlined,
        l10n.habitsTotalGiven,
      ),
      HabitUnit.minutes => (Icons.schedule_rounded, l10n.habitsTotalMinutes),
      HabitUnit.none => (
        fasting ? Icons.nights_stay_outlined : Icons.event_available_outlined,
        fasting ? l10n.habitsDaysFasted : l10n.habitsDaysDoneLabel,
      ),
    };
    final total = habit.unit == HabitUnit.none ? all.done : all.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
          child: Row(
            spacing: TahfeezSpacing.sm,
            children: [
              Icon(Icons.insights_outlined, color: scheme.primary, size: 20),
              Text(l10n.habitsStatsTitle, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
        // Counting up as it appears, as Memorize's do.
        TweenAnimationBuilder<double>(
          key: const ValueKey('habit-stats'),
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, const Duration(milliseconds: 1100)),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) {
            String count(int n) => number.format((n * t).round());
            Widget cell(IconData icon, String value, String label) => Row(
              spacing: TahfeezSpacing.sm,
              children: [
                Icon(icon, size: 22, color: scheme.primary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: theme.textTheme.titleMedium),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            return TahfeezCard(
              child: Column(
                spacing: TahfeezSpacing.md,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: cell(totalIcon, count(total), totalLabel),
                      ),
                      Expanded(
                        child: cell(
                          Icons.calendar_month_outlined,
                          '${count(month.done)} / ${month.due}',
                          l10n.habitsThisMonth,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: cell(
                          Icons.local_fire_department_outlined,
                          l10n.habitsDays((streak * t).round()),
                          l10n.habitsCurrentStreak,
                        ),
                      ),
                      Expanded(
                        child: cell(
                          Icons.emoji_events_outlined,
                          l10n.habitsDays((best * t).round()),
                          l10n.habitsBestStreak,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
