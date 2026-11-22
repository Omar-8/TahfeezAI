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

/// Add a habit: the ready-made ones by group (one tap adds it, to change
/// on its own page), or one of one's own.
class HabitCatalogScreen extends ConsumerWidget {
  const HabitCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(habitsProvider);
    final kept = {for (final h in s.habits) ?h.template: h.id};
    final scale = MediaQuery.textScalerOf(context);
    return HabitsScaffold(
      title: l10n.habitsAdd,
      body: CustomScrollView(
        key: const ValueKey('habits-catalog'),
        slivers: [
          SliverPadding(
            padding: withBarSpace(
              context,
              const EdgeInsets.all(TahfeezSpacing.md),
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: TahfeezCard(
                    key: const ValueKey('habits-new'),
                    onTap: () => context.push(AppRoutes.habitsNew),
                    child: Row(
                      spacing: TahfeezSpacing.smPlus,
                      children: [
                        HabitIconChip(HabitGroup.own.icon),
                        Expanded(
                          child: Text(
                            l10n.habitsNew,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const Icon(Icons.add_rounded),
                      ],
                    ),
                  ),
                ),
                for (final group in HabitGroup.values)
                  if (group != HabitGroup.own) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: TahfeezSpacing.lg,
                          bottom: TahfeezSpacing.sm,
                        ),
                        child: Row(
                          spacing: TahfeezSpacing.sm,
                          children: [
                            Icon(
                              group.icon,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            Text(
                              group.title(l10n),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: scale.scale(260),
                        mainAxisExtent: scale.scale(104),
                        crossAxisSpacing: TahfeezSpacing.sm,
                        mainAxisSpacing: TahfeezSpacing.sm,
                      ),
                      itemCount: habitCatalog
                          .where((t) => t.group == group)
                          .length,
                      itemBuilder: (context, i) {
                        final t = habitCatalog
                            .where((t) => t.group == group)
                            .elementAt(i);
                        return _TemplateTile(template: t, keptAs: kept[t.id]);
                      },
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template, required this.keptAs});

  final HabitTemplate template;

  /// The habit made of it already, if any.
  final String? keptAs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = habitTemplateName(l10n, template);
    return TahfeezCard(
      key: ValueKey('habit-template-${template.id}'),
      padding: const EdgeInsets.all(TahfeezSpacing.sm),
      // Its own page first: added there, with "Add habit" (owner,
      // 2026-11-21) — kept already, the habit itself.
      onTap: () => context.push(
        keptAs != null
            ? AppRoutes.habit(keptAs!)
            : AppRoutes.habitTemplate(template.id),
      ),
      child: Row(
        spacing: TahfeezSpacing.sm,
        children: [
          HabitIconChip(template.icon, size: 36),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: template.phrase != null
                      ? TextDirection.rtl
                      : null,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  [
                    habitScheduleText(context, template.schedule),
                    if (template.target != null)
                      ?habitAmountText(l10n, template.unit, template.target!),
                  ].join(' · '),
                  // (One line more: it was cut short — owner, 2026-11-21.)
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (keptAs != null)
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20),
        ],
      ),
    );
  }
}

/// A habit of one's own: its name and icon, its days, what it counts and
/// how much, a reminder.
class HabitNewScreen extends ConsumerStatefulWidget {
  const HabitNewScreen({super.key});

  @override
  ConsumerState<HabitNewScreen> createState() => _HabitNewState();
}

class _HabitNewState extends ConsumerState<HabitNewScreen> {
  final _name = TextEditingController();
  var _icon = habitIcons.first;
  var _days = {1, 2, 3, 4, 5, 6, 7};
  var _unit = HabitUnit.none;
  var _target = 1;
  TimeOfDay? _reminder;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = _name.text.trim().isNotEmpty;
    return HabitsScaffold(
      title: l10n.habitsNew,
      body: ListView(
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
        children: [
          TextField(
            key: const ValueKey('habit-new-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.habitsName),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TahfeezSpacing.md),
          Wrap(
            spacing: TahfeezSpacing.xs,
            runSpacing: TahfeezSpacing.xs,
            children: [
              for (final icon in habitIcons)
                ChoiceChip(
                  key: ValueKey('habit-new-icon-${icon.codePoint}'),
                  label: Icon(icon, size: 20),
                  selected: _icon == icon,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _icon = icon),
                ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.md),
          Text(l10n.habitsSchedule, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 4,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: ValueKey('habit-new-weekday-$d'),
                  label: Text(weekdayName(context, d)),
                  selected: _days.contains(d),
                  onSelected: (on) => setState(() {
                    final next = {..._days};
                    on ? next.add(d) : next.remove(d);
                    if (next.isNotEmpty) _days = next;
                  }),
                ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.md),
          Text(l10n.habitsTarget, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final u in HabitUnit.values)
                ChoiceChip(
                  key: ValueKey('habit-new-unit-${u.name}'),
                  label: Text(habitUnitName(l10n, u)),
                  selected: _unit == u,
                  onSelected: (_) => setState(() => _unit = u),
                ),
            ],
          ),
          if (_unit != HabitUnit.none)
            ListTile(
              key: const ValueKey('habit-new-target'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(habitAmountText(l10n, _unit, _target) ?? ''),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final a = await askHabitAmount(
                  context,
                  initial: _target,
                  label: habitUnitName(l10n, _unit),
                );
                if (a != null) setState(() => _target = a);
              },
            ),
          SwitchListTile(
            key: const ValueKey('habit-new-reminder'),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.habitsRemindersOn),
            subtitle: _reminder == null
                ? null
                : Text(_reminder!.format(context)),
            value: _reminder != null,
            onChanged: (on) async {
              if (!on) {
                setState(() => _reminder = null);
                return;
              }
              final picked = await showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 20, minute: 0),
              );
              if (picked != null) setState(() => _reminder = picked);
            },
          ),
          const SizedBox(height: TahfeezSpacing.md),
          FilledButton(
            key: const ValueKey('habit-new-save'),
            onPressed: !ready
                ? null
                : () {
                    final habit = ref
                        .read(habitsProvider.notifier)
                        .addOwn(
                          name: _name.text.trim(),
                          icon: _icon.codePoint,
                          schedule: _days.length == 7
                              ? const DailySchedule()
                              : WeekdaysSchedule(_days),
                          target: _target,
                          unit: _unit,
                          reminders: [
                            if (_reminder case final r?)
                              HabitReminder(minutes: r.hour * 60 + r.minute),
                          ],
                        );
                    context.pushReplacement(AppRoutes.habit(habit.id));
                  },
            child: Text(l10n.habitsSave),
          ),
          Padding(
            padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
            child: Text(
              l10n.habitsSource,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
