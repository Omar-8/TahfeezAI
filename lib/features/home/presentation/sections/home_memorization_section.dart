import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tahfeez_motion.dart';
import '../../../../core/ui/motion.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../memorization/application/memorization_today.dart';
import '../../../../memorization/domain/models/memorization_models.dart';
import '../../../../memorization/domain/plan_scheduler.dart';
import '../../../../memorization/domain/recitation_score.dart';
import '../../../../memorization/domain/today_scheduler.dart';
import '../../../memorize/presentation/memorize_screen.dart';

/// Home's memorization card (`docs/MEMORIZATION_MILESTONE.md`, M5): today's
/// three parts — the new lesson, recent and old revision — with how far
/// each has come, today's scores, and Continue for the next part not done.
class HomeMemorizationSection extends ConsumerWidget {
  const HomeMemorizationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(todayPlanProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionMemorization,
          icon: Icons.school_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        plan.when(
          data: (today) => _TodayCard(today: today),
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) => const _TodayCard(today: TodayPlan()),
        ),
      ],
    );
  }
}

/// The next part to recite: its first and last ayah, and its page.
typedef _Next = ({int first, int last, int? page});

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.today});

  final TodayPlan today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lesson = ref.watch(newLessonProvider).value;
    final names = surahNames(ref);
    final score = RecitationScore.of(
      ref.watch(todayAttemptsProvider).value ?? const <AyahAttempt>[],
    );
    void openMemorize() => context.go(AppRoutes.memorize);

    final lessonOpen =
        lesson != null &&
        !lesson.done &&
        !lesson.rest &&
        !lesson.finished &&
        lesson.runs.isNotEmpty;
    RevisionTask? firstOpen(List<RevisionTask> tasks) =>
        tasks.where((t) => !t.done).firstOrNull;
    final recentOpen = firstOpen(today.recent);
    final oldOpen = firstOpen(today.old);
    final _Next? next = lessonOpen
        ? (
            first: lesson.runs.first.first,
            last: lesson.runs.first.last,
            page: null,
          )
        : recentOpen != null
        ? (
            first: recentOpen.first,
            last: recentOpen.last,
            page: recentOpen.page,
          )
        : oldOpen != null
        ? (first: oldOpen.first, last: oldOpen.last, page: oldOpen.page)
        : null;

    if (lesson == null && today.isEmpty) {
      return TahfeezCard(
        key: const ValueKey('home-mem-empty'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.smPlus,
          children: [
            Text(
              l10n.homeMemNothing,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(
                onPressed: openMemorize,
                child: Text(l10n.homeMemOpen),
              ),
            ),
          ],
        ),
      );
    }

    Widget row(String title, String value, {required bool done}) => Row(
      spacing: TahfeezSpacing.sm,
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: done ? scheme.primary : scheme.outline,
        ),
        Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    String tasks(List<RevisionTask> list) =>
        l10n.homeMemTasksDone(list.where((t) => t.done).length, list.length);

    // Today's parts done of all of them: the lesson (while there is one
    // today) and each revision task.
    final lessonToday =
        lesson != null &&
        !lesson.rest &&
        !lesson.finished &&
        (lesson.done || lesson.runs.isNotEmpty);
    final total =
        (lessonToday ? 1 : 0) + today.recent.length + today.old.length;
    final done =
        (lessonToday && lesson.done ? 1 : 0) +
        today.recent.where((t) => t.done).length +
        today.old.where((t) => t.done).length;
    void continueNext() {
      if (next == null) return;
      reciteAyahs(context, ref, next.first, next.last, page: next.page);
    }

    return TahfeezCard(
      key: const ValueKey('home-mem-today'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          if (total > 0)
            _TodayRingRow(
              done: done,
              total: total,
              onTap: next == null ? null : continueNext,
            ),
          row(l10n.memNewLesson, switch (lesson) {
            null => l10n.homeMemNoPlan,
            NewLesson(finished: true) => l10n.memPlanFinished,
            NewLesson(done: true) => l10n.memLessonDone,
            NewLesson(rest: true) => l10n.memLessonRest,
            NewLesson(:final runs) when runs.isNotEmpty => ayahRangeLabel(
              runs.first.first,
              runs.last.last,
              names,
            ),
            _ => '',
          }, done: lesson != null && (lesson.done || lesson.finished)),
          if (today.recent.isNotEmpty)
            row(l10n.memRecent, tasks(today.recent), done: recentOpen == null),
          if (today.old.isNotEmpty)
            row(l10n.memOld, tasks(today.old), done: oldOpen == null),
          if (!score.isEmpty) ScorePair(score: score, dense: true),
          if (next == null && total == 0)
            Text(
              l10n.homeMemAllDone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          Row(
            spacing: TahfeezSpacing.sm,
            children: [
              if (next != null)
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('home-mem-continue'),
                    onPressed: continueNext,
                    child: Text(l10n.homeMemContinue),
                  ),
                ),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('home-mem-open'),
                  onPressed: openMemorize,
                  child: Text(l10n.homeMemOpen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today at a glance: a ring filling with the parts done (the lesson, each
/// revision task), and what it means in words beside it. Tapping it goes
/// on with the next part.
class _TodayRingRow extends StatelessWidget {
  const _TodayRingRow({required this.done, required this.total, this.onTap});

  final int done, total;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final complete = done >= total;
    final said = complete
        ? l10n.homeMemAllDone
        : l10n.homeMemTasksDone(done, total);
    return Semantics(
      key: const ValueKey('home-today-ring'),
      button: onTap != null,
      label: '${l10n.homeToday}: $said',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.xs),
          child: Row(
            spacing: TahfeezSpacing.md,
            children: [
              TodayRing(done: done, total: total),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(l10n.homeToday, style: theme.textTheme.titleMedium),
                    Text(
                      said,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: complete
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ring filling to [done] of [total], animating to each new value, the
/// count in its middle — a check once all is done.
class TodayRing extends StatelessWidget {
  const TodayRing({
    super.key,
    required this.done,
    required this.total,
    this.size = 56,
  });

  final int done, total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final complete = total > 0 && done >= total;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: share),
        duration: motion(context, TahfeezMotionDuration.emphasis),
        curve: TahfeezMotionCurves.standard,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            value: value,
            track: scheme.surfaceContainerHighest,
            fill: scheme.primary,
          ),
          child: child,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: motion(context, TahfeezMotionDuration.medium),
            switchInCurve: TahfeezMotionCurves.emphasized,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: complete
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('done'),
                    color: scheme.primary,
                    size: size * 0.5,
                  )
                : Text(
                    '$done/$total',
                    key: ValueKey('$done/$total'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.fill});

  final double value;
  final Color track, fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (value > 0) {
      // From the top, clockwise.
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value,
        false,
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}
