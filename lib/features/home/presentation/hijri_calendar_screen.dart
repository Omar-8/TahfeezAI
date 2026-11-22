import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/bar_space.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../../habits/application/habits_controller.dart';
import '../../habits/domain/hijri.dart';
import '../../habits/presentation/habit_parts.dart';
import 'home_date_card.dart' show HijriEvent;

/// A Hijri month's days, each with its Gregorian date (by the Umm al-Qura
/// calendar, moved by [adjust] days as the Hijri date is everywhere).
List<({DateTime date, int day})> hijriMonthDays(
  int year,
  int month, {
  int adjust = 0,
}) {
  // Near its first day, found exactly.
  final guess = HijriCalendar().hijriToGregorian(year, month, 1);
  var d = DateTime(guess.year, guess.month, guess.day - 3 - adjust);
  while (true) {
    final h = hijriOf(d, adjust: adjust);
    if (h.year == year && h.month == month && h.day == 1) break;
    d = DateTime(d.year, d.month, d.day + 1);
  }
  final days = <({DateTime date, int day})>[];
  while (true) {
    final h = hijriOf(d, adjust: adjust);
    if (h.month != month) break;
    days.add((date: d, day: h.day));
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return days;
}

/// The Hijri calendar (owner, 2026-11-21: from Home's date): a month at a
/// time, each day with its Gregorian date, today ringed, the white days
/// (13–15) and the year's events marked, and the month's events listed.
class HijriCalendarScreen extends ConsumerStatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  ConsumerState<HijriCalendarScreen> createState() => _HijriCalendarState();
}

class _HijriCalendarState extends ConsumerState<HijriCalendarScreen> {
  ({int year, int month})? _shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final intl = intlLocaleOf(locale);
    final adjust = ref.watch(habitsProvider.select((s) => s.hijriAdjust));
    final now = ref.watch(memorizationClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final todayHijri = hijriOf(today, adjust: adjust);
    final shown = _shown ?? (year: todayHijri.year, month: todayHijri.month);
    final days = hijriMonthDays(shown.year, shown.month, adjust: adjust);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    void go(int by) {
      var m = shown.month + by, y = shown.year;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      setState(() => _shown = (year: y, month: m));
    }

    final events = [
      for (final e in HijriEvent.values)
        if (e.month == shown.month)
          for (final d in days)
            if (d.day == e.day) (event: e, date: d.date),
    ];
    final lead = (days.first.date.weekday - 1) % 7;
    final onThisMonth =
        shown.year == todayHijri.year && shown.month == todayHijri.month;
    final gregorianSpan = [
      DateFormat.yMMM(intl).format(days.first.date),
      if (days.first.date.month != days.last.date.month)
        DateFormat.yMMM(intl).format(days.last.date),
    ].join(' – ');
    return HabitsScaffold(
      title: l10n.hijriCalendarTitle,
      body: ListView(
        key: const ValueKey('hijri-calendar'),
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
        children: [
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.sm,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('hijri-previous'),
                      tooltip: l10n.commonPrevious,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                      onPressed: () => go(-1),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${hijriMonthName(shown.month, language)} '
                            '${shown.year}',
                            key: const ValueKey('hijri-month'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            gregorianSpan,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('hijri-next'),
                      tooltip: l10n.commonNext,
                      icon: Icon(
                        rtl
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                      onPressed: () => go(1),
                    ),
                  ],
                ),
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
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  children: [
                    for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                    for (final d in days)
                      _DayCell(
                        day: d.day,
                        date: d.date,
                        today: d.date == today,
                        white: d.day >= 13 && d.day <= 15,
                        event: HijriEvent.values.any(
                          (e) => e.month == shown.month && e.day == d.day,
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: TahfeezSpacing.md,
                  runSpacing: 4,
                  children: [
                    _Legend(
                      color: scheme.primaryContainer,
                      label: l10n.hijriCalendarWhiteDays,
                    ),
                    _Legend(
                      dot: true,
                      color: scheme.tertiary,
                      label: l10n.hijriCalendarEvents,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!onThisMonth)
            Padding(
              padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
              child: Center(
                child: TextButton.icon(
                  key: const ValueKey('hijri-this-month'),
                  icon: const Icon(Icons.today_outlined),
                  label: Text(l10n.habitsThisMonth),
                  onPressed: () => setState(() => _shown = null),
                ),
              ),
            ),
          for (final (:event, :date) in events)
            Padding(
              padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
              child: TahfeezCard(
                key: ValueKey('hijri-event-${event.name}'),
                padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
                child: Row(
                  spacing: TahfeezSpacing.smPlus,
                  children: [
                    HabitIconChip(Icons.event_outlined, size: 36),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title(l10n),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${event.day} ${hijriMonthName(event.month, language)}'
                            '  ·  ${DateFormat.yMMMMEEEEd(intl).format(date)}',
                            style: theme.textTheme.bodySmall?.copyWith(
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
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.today,
    required this.white,
    required this.event,
  });

  final int day;
  final DateTime date;
  final bool today, white, event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      key: ValueKey('hijri-day-$day'),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: today
              ? scheme.primary
              : white
              ? scheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(TahfeezRadii.sm),
        ),
        // (Shrunk to its square in tall fonts and large text.)
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: today ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
              Text(
                '${date.day}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: today
                      ? scheme.onPrimary.withValues(alpha: 0.8)
                      : scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 6,
                child: event
                    ? Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: today ? scheme.onPrimary : scheme.tertiary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.dot = false});

  final Color color;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: dot ? 6 : 14,
          height: dot ? 6 : 14,
          decoration: BoxDecoration(
            color: color,
            shape: dot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: dot ? null : BorderRadius.circular(4),
          ),
        ),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
