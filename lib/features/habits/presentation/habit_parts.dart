import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../home/presentation/home_sky.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper;
import '../../../core/theme/app_spacing.dart';
import '../domain/habit.dart';
import '../domain/habit_catalog.dart';
import '../domain/hijri.dart';

/// [amount] of [unit] in words ("4 rakʿahs", "100 times"); `null` for a
/// habit just done.
String? habitAmountText(AppLocalizations l10n, HabitUnit unit, int amount) =>
    switch (unit) {
      HabitUnit.none => null,
      HabitUnit.times => l10n.habitsTimes(amount),
      HabitUnit.rakahs => l10n.habitsRakahs(amount),
      HabitUnit.amount => l10n.habitsAmount(amount),
      HabitUnit.pages => l10n.habitsPages(amount),
      HabitUnit.minutes => l10n.habitsMinutes(amount),
      HabitUnit.ayahs => l10n.habitsAyahs(amount),
    };

/// A unit's name (for choosing one).
String habitUnitName(AppLocalizations l10n, HabitUnit unit) => switch (unit) {
  HabitUnit.none => l10n.habitsUnitNone,
  HabitUnit.times => l10n.habitsUnitTimes,
  HabitUnit.rakahs => l10n.habitsUnitRakahs,
  HabitUnit.amount => l10n.habitsUnitAmount,
  HabitUnit.pages => l10n.habitsUnitPages,
  HabitUnit.minutes => l10n.habitsUnitMinutes,
  HabitUnit.ayahs => l10n.habitsUnitAyahs,
};

/// A weekday's short name in the app's language (Mon, Thu…).
String weekdayName(BuildContext context, int weekday) {
  final locale = intlLocaleOf(Localizations.localeOf(context));
  // 2024-01-01 was a Monday.
  return DateFormat.E(locale).format(DateTime(2024, 1, weekday));
}

/// When [schedule] is due, in words.
String habitScheduleText(BuildContext context, HabitSchedule schedule) {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  return switch (schedule) {
    DailySchedule() => l10n.habitsEveryDay,
    WeekdaysSchedule(:final days) => [
      for (final d in days.toList()..sort()) weekdayName(context, d),
    ].join(', '),
    HijriDaysSchedule(:final days) => l10n.habitsHijriMonthly(
      (days.toList()..sort()).join(', '),
    ),
    HijriDatesSchedule(:final dates) => [
      for (final d in dates) '${d.day} ${hijriMonthName(d.month, language)}',
    ].join(', '),
  };
}

/// Habits' scaffold: the sky, the bar, the reading column.
class HabitsScaffold extends StatelessWidget {
  const HabitsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floating,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floating;

  @override
  Widget build(BuildContext context) => SkyBackdrop(
    child: Scaffold(
      appBar: TahfeezAppBar(
        title: Text(title),
        centerTitle: false,
        actions: actions,
      ),
      floatingActionButton: floating,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TahfeezContentWidth.maxReading,
            ),
            child: body,
          ),
        ),
      ),
    ),
  );
}

/// A habit's icon in its round chip.
class HabitIconChip extends StatelessWidget {
  const HabitIconChip(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
      ),
      child: Icon(icon, size: size * 0.55, color: scheme.onPrimaryContainer),
    );
  }
}

/// Asks how much (a number, at least 1): `null` cancelled.
Future<int?> askHabitAmount(
  BuildContext context, {
  required int initial,
  required String label,
}) async {
  final result = await showDialog<int>(
    context: context,
    builder: (context) => _AmountDialog(initial: initial, label: label),
  );
  return result == null || result < 1 ? null : result;
}

/// (Its field's controller its own: alive while the dialog closes.)
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.initial, required this.label});

  final int initial;
  final String label;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() =>
      Navigator.of(context).pop(int.tryParse(_controller.text.trim()));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.habitsHowMuch),
      content: TextField(
        key: const ValueKey('habit-amount-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('habit-amount-ok'),
          onPressed: _done,
          child: Text(l10n.habitsSave),
        ),
      ],
    );
  }
}

/// A habit's target: its ready-made choices (2, 4, 6, 8 rakʿahs — Witr's
/// odd) as buttons, any other number on the stepper beside them (owner,
/// 2026-11-21: as the memorization plan's number of ayahs).
class HabitTargetPicker extends StatelessWidget {
  const HabitTargetPicker({
    super.key,
    required this.unit,
    required this.presets,
    required this.value,
    required this.onChanged,
  });

  final HabitUnit unit;
  final List<int> presets;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        Text(
          habitAmountText(l10n, unit, value) ?? '',
          key: const ValueKey('habit-target-value'),
          style: theme.textTheme.titleSmall,
        ),
        // The ready-made ones on a line (owner, 2026-11-21), − and + on
        // the next.
        SingleChildScrollView(
          key: const ValueKey('habit-presets'),
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: TahfeezSpacing.xs,
            children: [
              for (final p in presets)
                ChoiceChip(
                  key: ValueKey('habit-preset-$p'),
                  label: Text('$p'),
                  selected: value == p,
                  showCheckmark: false,
                  onSelected: (_) => onChanged(p),
                ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CountStepper(
            id: 'habit-target-stepper',
            value: value,
            min: 1,
            max: 9999,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// What keeps a habit in step with the rest of the app, in words.
String? habitSyncNote(AppLocalizations l10n, HabitSync? sync) => switch (sync) {
  null => null,
  HabitSync.khatmah => l10n.habitsSyncKhatmah,
  HabitSync.memorization => l10n.habitsSyncMemorize,
  HabitSync.athkarMorning ||
  HabitSync.athkarEvening ||
  HabitSync.athkarSleep => l10n.habitsSyncAthkar,
};
