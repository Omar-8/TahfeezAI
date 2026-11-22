import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/theme/tahfeez_tones.dart';
import '../../../core/ui/bar_space.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../application/habits_controller.dart';
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import '../domain/hijri.dart';
import 'habit_parts.dart';

/// Habits (owner, 2026-11-21): Today — each habit due on the day chosen
/// (today, or one gone by), ticked; Progress — the week, the month, the
/// year, all habits together and each one.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);
  DateTime? _day;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(habitsProvider);
    final now = ref.watch(memorizationClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final day = _day ?? today;
    void add() => context.push(AppRoutes.habitsAdd);
    Widget list(String key, List<Widget> children) => ListView(
      key: ValueKey(key),
      padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
      children: children,
    );
    return HabitsScaffold(
      title: l10n.habitsTitle,
      // A glass pill, named (owner, 2026-11-21), as Memorize's "Mark what
      // I know".
      actions: [HabitsAddAction(onTap: add)],
      body: !s.loaded
          ? const Center(child: CircularProgressIndicator())
          : s.habits.isEmpty
          ? _Empty(onAdd: add)
          // Two tabs as Memorize's and the Quran's (owner, 2026-11-21).
          : Column(
              children: [
                TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(
                      key: const ValueKey('habits-tab-today'),
                      text: l10n.habitsToday,
                    ),
                    Tab(
                      key: const ValueKey('habits-tab-progress'),
                      text: l10n.habitsProgress,
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      list('habits-list', [
                        _Today(
                          state: s,
                          day: day,
                          today: today,
                          onDay: (d) => setState(() => _day = d),
                        ),
                        const SizedBox(height: TahfeezSpacing.md),
                        // Always one more to add, after the list.
                        Center(
                          child: FilledButton.tonalIcon(
                            key: const ValueKey('habits-add-more'),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.habitsAdd),
                            onPressed: add,
                          ),
                        ),
                      ]),
                      list('habits-progress', [
                        _Progress(state: s, today: today),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Add habit" in the top bar: a glass pill with its name.
class HabitsAddAction extends StatelessWidget {
  const HabitsAddAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: TahfeezSpacing.sm),
      child: Center(
        child: Semantics(
          button: true,
          child: TahfeezGlassSurface(
            key: const ValueKey('habits-add'),
            borderRadius: BorderRadius.circular(TahfeezRadii.pill),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TahfeezSpacing.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TahfeezSpacing.xs,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: scheme.primary),
                    Text(
                      l10n.habitsAdd,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            Text(
              l10n.habitsEmpty,
              key: const ValueKey('habits-empty'),
              textAlign: TextAlign.center,
            ),
            FilledButton.icon(
              key: const ValueKey('habits-empty-add'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.habitsAdd),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's habits: its date (and Hijri), the days before it to tick,
/// how many are done, and each one due.
class _Today extends ConsumerWidget {
  const _Today({
    required this.state,
    required this.day,
    required this.today,
    required this.onDay,
  });

  final HabitsState state;
  final DateTime day, today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final (:done, :due) = habitsDay(state, day);
    final dueHabits = [
      for (final h in state.habits)
        if (state.dueOn(h, day)) h,
    ];
    final earliest = state.habits
        .map((h) => habitDate(h.since))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.md,
      children: [
        // The last week's days, to tick a day forgotten; older ones from
        // a calendar.
        SingleChildScrollView(
          key: const ValueKey('habits-days'),
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            spacing: TahfeezSpacing.xs,
            children: [
              ActionChip(
                key: const ValueKey('habits-pick-day'),
                avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(l10n.habitsPickDay),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: earliest.isBefore(today) ? earliest : today,
                    lastDate: today,
                  );
                  if (picked != null) onDay(picked);
                },
              ),
              for (var i = 6; i >= 0; i--)
                _DayChip(
                  date: DateTime(today.year, today.month, today.day - i),
                  selected:
                      habitDay(day) ==
                      habitDay(
                        DateTime(today.year, today.month, today.day - i),
                      ),
                  state: state,
                  onTap: onDay,
                ),
            ],
          ),
        ),
        TahfeezCard(
          child: Row(
            spacing: TahfeezSpacing.md,
            children: [
              // The day's share — its numbers in the middle, a tick once
              // all are done (owner, 2026-11-21: it showed nothing).
              SizedBox.square(
                dimension: 56,
                child: Stack(
                  key: const ValueKey('habits-ring'),
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: due == 0 ? 0 : done / due),
                        duration: TahfeezMotionDuration.medium,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v,
                          strokeWidth: 6,
                          backgroundColor: scheme.progressTrack,
                        ),
                      ),
                    ),
                    if (due > 0 && done == due)
                      Icon(
                        Icons.check_rounded,
                        key: const ValueKey('habits-ring-done'),
                        color: scheme.primary,
                        size: 30,
                      )
                    else
                      Text(
                        '$done/$due',
                        key: const ValueKey('habits-ring-count'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd(intlLocaleOf(locale)).format(day),
                      style: theme.textTheme.titleMedium,
                    ),
                    // The Hijri date — tapped, moved a day where the
                    // month is sighted a day apart.
                    InkWell(
                      key: const ValueKey('habits-hijri'),
                      onTap: () => _adjustHijri(context, ref, state),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Text(
                            formatHijri(
                              hijriOf(day, adjust: state.hijriAdjust),
                              language,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      due == 0
                          ? l10n.habitsNothingDue
                          : l10n.habitsDoneOf(done, due),
                      key: const ValueKey('habits-done-of'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final h in dueHabits) HabitTile(habit: h, day: day),
      ],
    );
  }
}

/// The Hijri date a day earlier or later (or as the Umm al-Qura calendar
/// has it).
Future<void> _adjustHijri(
  BuildContext context,
  WidgetRef ref,
  HabitsState state,
) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showDialog<int>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.habitsHijriAdjust),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.lg),
          child: Text(l10n.habitsHijriAdjustSub),
        ),
        RadioGroup<int>(
          groupValue: state.hijriAdjust,
          onChanged: (v) => Navigator.of(context).pop(v),
          child: Column(
            children: [
              for (final (days, label) in [
                (-1, l10n.habitsAdjustMinus),
                (0, l10n.habitsAdjustNone),
                (1, l10n.habitsAdjustPlus),
              ])
                RadioListTile<int>(
                  key: ValueKey('habits-hijri-$days'),
                  value: days,
                  title: Text(label),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (picked != null) {
    ref.read(habitsProvider.notifier).setHijriAdjust(picked);
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.state,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final HabitsState state;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (:done, :due) = habitsDay(state, date);
    final all = due > 0 && done == due;
    return InkWell(
      key: ValueKey('habits-day-${habitDay(date)}'),
      borderRadius: BorderRadius.circular(TahfeezRadii.md),
      onTap: () => onTap(date),
      child: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(TahfeezRadii.md),
        ),
        child: Column(
          spacing: 2,
          children: [
            Text(
              weekdayName(context, date.weekday),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              ),
            ),
            Text(
              '${date.day}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              ),
            ),
            Icon(
              all ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 12,
              color: selected
                  ? scheme.onPrimary
                  : all
                  ? scheme.primary
                  : scheme.onPrimaryContainer.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// A habit on a day: its icon, name, the amount done (or its target), and
/// its tick — a tap ticks it (the last amount, else its target); a long
/// press asks how much; a wird, counted.
class HabitTile extends ConsumerWidget {
  const HabitTile({super.key, required this.habit, required this.day});

  final Habit habit;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(habitsProvider);
    final controller = ref.read(habitsProvider.notifier);
    final key = habitDay(day);
    final amount = s.amountOn(habit.id, key);
    final done = amount != null;
    final template = templateOf(habit);
    final counted = template?.phrase != null;
    final shown = amount ?? habit.target;
    final amountText = shown == null
        ? null
        : habitAmountText(l10n, habit.unit, shown);
    // A wird counted to its target is done; counted in part, not yet.
    final complete = done && (!counted || amount >= (habit.target ?? 1));

    Future<void> ask() async {
      final a = await askHabitAmount(
        context,
        initial: amount ?? controller.defaultAmount(habit),
        label: habitUnitName(l10n, habit.unit),
      );
      if (a != null) controller.tick(habit, key, amount: a);
    }

    return TahfeezCard(
      key: ValueKey('habit-tile-${habit.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.md,
        vertical: TahfeezSpacing.sm,
      ),
      onTap: () => context.push(AppRoutes.habit(habit.id)),
      child: Row(
        spacing: TahfeezSpacing.smPlus,
        children: [
          HabitIconChip(habitIcon(habit)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habitName(l10n, habit),
                  textDirection: counted ? TextDirection.rtl : null,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: complete ? TextDecoration.lineThrough : null,
                    decorationColor: scheme.onSurfaceVariant,
                  ),
                ),
                if (amountText != null)
                  Text(
                    counted && done && !complete
                        ? '$amount / ${habit.target}'
                        : amountText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: done ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (counted)
            TextButton(
              key: ValueKey('habit-count-${habit.id}'),
              onPressed: () =>
                  context.push('${AppRoutes.habitCount(habit.id)}?day=$key'),
              child: Text(l10n.habitsCount),
            ),
          IconButton(
            // A long press: how much (its tooltip's own, else).
            onLongPress: habit.unit == HabitUnit.none ? null : ask,
            key: ValueKey('habit-check-${habit.id}'),
            tooltip: complete ? l10n.habitsNotDone : l10n.habitsDone,
            iconSize: 32,
            icon: Icon(
              complete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: complete ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onPressed: () {
              if (complete) {
                controller.untick(habit, key);
              } else {
                controller.tick(
                  habit,
                  key,
                  amount: counted ? habit.target : null,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

enum _Period { week, month, year }

/// How the habits went: over the week, the month or the year — all of
/// them day by day (or month by month), then each one.
class _Progress extends StatefulWidget {
  const _Progress({required this.state, required this.today});

  final HabitsState state;
  final DateTime today;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  var _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = intlLocaleOf(Localizations.localeOf(context));
    final s = widget.state;
    final t = widget.today;
    final (from, to) = switch (_period) {
      _Period.week => (DateTime(t.year, t.month, t.day - 6), t),
      _Period.month => (DateTime(t.year, t.month), t),
      _Period.year => (DateTime(t.year), t),
    };
    // The bars: a day each (a month each in the year).
    final bars = <({String label, double share, bool any})>[];
    if (_period == _Period.year) {
      for (var m = 1; m <= t.month; m++) {
        var done = 0, due = 0;
        final last = m == t.month ? t.day : DateTime(t.year, m + 1, 0).day;
        for (var d = 1; d <= last; d++) {
          final r = habitsDay(s, DateTime(t.year, m, d));
          done += r.done;
          due += r.due;
        }
        bars.add((
          label: DateFormat.MMM(locale).format(DateTime(t.year, m)),
          share: due == 0 ? 0 : done / due,
          any: due > 0,
        ));
      }
    } else {
      for (
        var d = from;
        !d.isAfter(to);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final r = habitsDay(s, d);
        bars.add((
          label: _period == _Period.week
              ? weekdayName(context, d.weekday)
              : '${d.day}',
          share: r.due == 0 ? 0 : r.done / r.due,
          any: r.due > 0,
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.md,
      children: [
        TahfeezSegmentedControl<_Period>(
          options: {
            _Period.week: l10n.habitsWeek,
            _Period.month: l10n.habitsMonth,
            _Period.year: l10n.habitsYear,
          },
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        TahfeezCard(
          key: ValueKey('habits-chart-${_period.name}'),
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: _period == _Period.month ? 2 : 6,
              children: [
                for (final (i, b) in bars.indexed)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 4,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: b.any ? 0.08 + 0.92 * b.share : 0.04,
                            child: Container(
                              decoration: BoxDecoration(
                                color: b.any
                                    ? Color.lerp(
                                        scheme.progressTrack,
                                        scheme.primary,
                                        0.25 + 0.75 * b.share,
                                      )
                                    : scheme.progressTrack,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        // (A month's days: every fifth labelled.)
                        Text(
                          _period == _Period.month && i % 5 != 0 ? '' : b.label,
                          maxLines: 1,
                          softWrap: false,
                          // (Wider than a month's day's bar: over its
                          // neighbours, those unlabelled.)
                          overflow: TextOverflow.visible,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final h in s.habits)
          _HabitSummary(state: s, habit: h, from: from, to: to, today: t),
      ],
    );
  }
}

class _HabitSummary extends StatelessWidget {
  const _HabitSummary({
    required this.state,
    required this.habit,
    required this.from,
    required this.to,
    required this.today,
  });

  final HabitsState state;
  final Habit habit;
  final DateTime from, to, today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (:done, :due, :total) = habitPeriod(state, habit, from, to);
    final streak = habitStreak(state, habit, today);
    final totalText = total == 0
        ? null
        : habitAmountText(l10n, habit.unit, total);
    return TahfeezCard(
      key: ValueKey('habit-summary-${habit.id}'),
      padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
      onTap: () => context.push(AppRoutes.habit(habit.id)),
      child: Row(
        spacing: TahfeezSpacing.smPlus,
        children: [
          HabitIconChip(habitIcon(habit), size: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                Text(
                  habitName(l10n, habit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  child: LinearProgressIndicator(
                    value: due == 0 ? 0 : done / due,
                    minHeight: 6,
                    backgroundColor: scheme.progressTrack,
                  ),
                ),
                Text(
                  [
                    l10n.habitsDaysDone(done, due),
                    ?totalText,
                    if (streak > 1) l10n.habitsStreak(streak),
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
    );
  }
}
