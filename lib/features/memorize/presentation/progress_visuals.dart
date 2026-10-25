import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_progress.dart';
import '../../../memorization/domain/activity_calendar.dart';
import '../../../memorization/domain/progress_map.dart';

/// The Quran as a ring of its 30 juz, each segment filled by how much of
/// that juz is memorized (recited from memory, then only marked, paler),
/// the share memorized in the middle.
class JuzRing extends StatelessWidget {
  const JuzRing({super.key, required this.map, this.size = 120});

  final ProgressMap map;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (map.share * 100).round();
    return Semantics(
      label: AppLocalizations.of(context).memProgressShare(percent),
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _JuzRingPainter(
            juz: [
              for (final j in map.juz)
                (
                  recited: j.ayahs == 0
                      ? 0.0
                      : j.pages.fold(
                              0,
                              (n, p) => n + p.memorized - p.unverified,
                            ) /
                            j.ayahs,
                  marked: j.ayahs == 0
                      ? 0.0
                      : j.pages.fold(0, (n, p) => n + p.unverified) / j.ayahs,
                ),
            ],
            track: scheme.surfaceContainerHighest,
            fill: scheme.primary,
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '$percent%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JuzRingPainter extends CustomPainter {
  _JuzRingPainter({required this.juz, required this.track, required this.fill});

  /// Each juz's share recited from memory and only marked, 0..1.
  final List<({double recited, double marked})> juz;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (juz.isEmpty) return;
    const stroke = 10.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - stroke / 2,
    );
    final n = juz.length;
    const gap = 0.045; // radians between segments
    final sweep = 2 * math.pi / n - gap;
    Paint paint(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = c;
    final trackPaint = paint(track);
    final recitedPaint = paint(fill);
    final markedPaint = paint(fill.withValues(alpha: 0.35));
    for (var i = 0; i < n; i++) {
      // Juz 1 at the top, on clockwise.
      final start = -math.pi / 2 + i * (sweep + gap) + gap / 2;
      canvas.drawArc(rect, start, sweep, false, trackPaint);
      final r = juz[i].recited.clamp(0.0, 1.0);
      final m = juz[i].marked.clamp(0.0, 1.0 - r);
      if (r > 0) canvas.drawArc(rect, start, sweep * r, false, recitedPaint);
      if (m > 0) {
        canvas.drawArc(rect, start + sweep * r, sweep * m, false, markedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_JuzRingPainter old) =>
      old.track != track || old.fill != fill || !_same(old.juz, juz);

  static bool _same(
    List<({double recited, double marked})> a,
    List<({double recited, double marked})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Days in a row of recitation (and the best run), with a calendar of the
/// last months: a square a day, darker the more ayahs were recited.
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final calendar = ref.watch(activityCalendarProvider).value;
    if (calendar == null) return const SizedBox.shrink();
    final current = calendar.current;
    return TahfeezCard(
      key: const ValueKey('progress-streak'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 28,
                color: current > 0 ? scheme.tertiary : scheme.outline,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.memStreakDays(current),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (calendar.longest > 0)
                      Text(
                        l10n.memStreakBest(calendar.longest),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ActivityHeatmap(calendar: calendar),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 3,
            runSpacing: 3,
            children: [
              Text(l10n.memCalendarLess, style: theme.textTheme.labelSmall),
              const SizedBox(width: 2),
              for (var level = 0; level <= 4; level++)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ActivityHeatmap.colorOf(level, scheme),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              const SizedBox(width: 2),
              Text(l10n.memCalendarMore, style: theme.textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// A square a day, a column a week (the locale's first day at the top),
/// today's week last — as many weeks as fit, up to a year.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.calendar});

  final ActivityCalendar calendar;

  static const _gap = 3.0;

  /// 0: nothing; 1–4: a few ayahs to many.
  static int levelOf(int ayahs) => switch (ayahs) {
    0 => 0,
    < 5 => 1,
    < 15 => 2,
    < 40 => 3,
    _ => 4,
  };

  static Color colorOf(int level, ColorScheme scheme) => level == 0
      ? scheme.surfaceContainerHighest
      : scheme.primary.withValues(
          alpha: const [0.0, 0.3, 0.55, 0.8, 1.0][level],
        );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstWeekday = MaterialLocalizations.of(context)
        .firstDayOfWeekIndex; // 0 = Sunday
    return LayoutBuilder(
      builder: (context, box) {
        final weeks = ((box.maxWidth + _gap) / (13 + _gap)).floor().clamp(
          8,
          53,
        );
        final cell = math.min(
          16.0,
          (box.maxWidth - (weeks - 1) * _gap) / weeks,
        );
        // Back from today to the start of its week, then whole weeks.
        final today = calendar.today;
        final intoWeek = (today.weekday % 7 - firstWeekday) % 7;
        final start = ActivityCalendar.shift(
          today,
          -intoWeek - 7 * (weeks - 1),
        );
        final levels = [
          for (var i = 0; i < weeks * 7; i++)
            levelOf(calendar.on(ActivityCalendar.shift(start, i))),
        ];
        return SizedBox(
          height: 7 * cell + 6 * _gap,
          child: CustomPaint(
            size: Size(box.maxWidth, 7 * cell + 6 * _gap),
            painter: _HeatmapPainter(
              levels: levels,
              future: intoWeek + 1,
              weeks: weeks,
              cell: cell,
              colors: [for (var l = 0; l <= 4; l++) colorOf(l, scheme)],
              today: scheme.primary,
              rtl: Directionality.of(context) == TextDirection.rtl,
            ),
          ),
        );
      },
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.levels,
    required this.future,
    required this.weeks,
    required this.cell,
    required this.colors,
    required this.today,
    required this.rtl,
  });

  /// Day by day from the first column's first day.
  final List<int> levels;

  /// Days of the last week up to today (the rest are to come: not drawn).
  final int future;
  final int weeks;
  final double cell;
  final List<Color> colors;
  final Color today;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = ActivityHeatmap._gap;
    final total = weeks * cell + (weeks - 1) * gap;
    final left = (size.width - total) / 2;
    final paint = Paint();
    final radius = Radius.circular(cell / 4);
    final last = (weeks - 1) * 7 + future - 1;
    for (var i = 0; i <= last; i++) {
      final week = i ~/ 7, day = i % 7;
      final col = rtl ? weeks - 1 - week : week;
      final rect = Rect.fromLTWH(
        left + col * (cell + gap),
        day * (cell + gap),
        cell,
        cell,
      );
      paint.color = colors[levels[i]];
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      if (i == last) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(0.75), radius),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = today,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.weeks != weeks ||
      old.cell != cell ||
      old.future != future ||
      old.rtl != rtl ||
      old.today != today ||
      !_listEquals(old.levels, levels) ||
      !_listEquals(old.colors, colors);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
