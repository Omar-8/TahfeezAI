import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/bar_space.dart';
import '../application/habits_controller.dart';
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import 'habit_parts.dart';

/// A ready-made habit before it is added (owner, 2026-11-21: added with
/// "Add habit", not by a tap on it): what it is, how much, its days, its
/// reminders — each changeable — then added.
class HabitTemplateScreen extends ConsumerStatefulWidget {
  const HabitTemplateScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<HabitTemplateScreen> createState() => _TemplateState();
}

class _TemplateState extends ConsumerState<HabitTemplateScreen> {
  late final HabitTemplate? _template = habitTemplate(widget.id);
  late int _target = _template?.target ?? 1;
  late HabitSchedule _schedule = _template?.schedule ?? const DailySchedule();
  late List<HabitReminder> _reminders = [...?_template?.reminders];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = _template;
    if (t == null) {
      return HabitsScaffold(title: l10n.habitsAdd, body: const SizedBox());
    }
    final weekdays = switch (_schedule) {
      DailySchedule() => {1, 2, 3, 4, 5, 6, 7},
      WeekdaysSchedule(:final days) => days,
      _ => null,
    };
    String time(int minutes) =>
        TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
    return HabitsScaffold(
      title: l10n.habitsAdd,
      body: ListView(
        key: const ValueKey('habit-template'),
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
        children: [
          Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              HabitIconChip(t.icon, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habitTemplateName(l10n, t),
                      textDirection: t.phrase != null
                          ? TextDirection.rtl
                          : null,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      habitScheduleText(context, _schedule),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.sm),
          Text(
            [?habitSyncNote(l10n, t.sync), l10n.habitsAddHint].join('\n'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TahfeezSpacing.md),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.sm,
              children: [
                if (t.unit != HabitUnit.none)
                  HabitTargetPicker(
                    unit: t.unit,
                    presets: t.presets.isEmpty
                        ? unitPresets(t.unit)
                        : t.presets,
                    value: _target,
                    onChanged: (v) => setState(() => _target = v),
                  ),
                if (weekdays != null) ...[
                  Text(l10n.habitsSchedule, style: theme.textTheme.titleSmall),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          key: ValueKey('habit-template-weekday-$d'),
                          label: Text(weekdayName(context, d)),
                          selected: weekdays.contains(d),
                          onSelected: (on) => setState(() {
                            final next = {...weekdays};
                            on ? next.add(d) : next.remove(d);
                            if (next.isEmpty) return;
                            _schedule = next.length == 7
                                ? const DailySchedule()
                                : WeekdaysSchedule(next);
                          }),
                        ),
                    ],
                  ),
                ],
                Text(l10n.habitsRemindersOn, style: theme.textTheme.titleSmall),
                for (final (i, r) in _reminders.indexed)
                  ListTile(
                    key: ValueKey('habit-template-reminder-$i'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(time(r.minutes)),
                    subtitle: r.dayBefore ? Text(l10n.habitsDayBefore) : null,
                    trailing: IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(
                        () => _reminders = [..._reminders]..removeAt(i),
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
                      setState(
                        () => _reminders = [
                          for (final (j, x) in _reminders.indexed)
                            j == i
                                ? x.withMinutes(
                                    picked.hour * 60 + picked.minute,
                                  )
                                : x,
                        ],
                      );
                    },
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('habit-template-add-reminder'),
                    icon: const Icon(Icons.add_alarm_outlined),
                    label: Text(l10n.habitsAddReminder),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 20, minute: 0),
                      );
                      if (picked == null) return;
                      setState(
                        () => _reminders = [
                          ..._reminders,
                          HabitReminder(
                            minutes: picked.hour * 60 + picked.minute,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TahfeezSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('habit-template-add'),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.habitsAdd),
            onPressed: () {
              final habit = ref
                  .read(habitsProvider.notifier)
                  .addTemplate(
                    t,
                    schedule: _schedule,
                    target: t.unit == HabitUnit.none ? null : _target,
                    reminders: _reminders,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.habitsAdded(habitTemplateName(l10n, t))),
                ),
              );
              context.pushReplacement(AppRoutes.habit(habit.id));
            },
          ),
        ],
      ),
    );
  }
}
