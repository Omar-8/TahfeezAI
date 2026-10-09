import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
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
class HomeMemorizationTeaserSection extends ConsumerWidget {
  const HomeMemorizationTeaserSection({super.key});

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

    return TahfeezCard(
      key: const ValueKey('home-mem-today'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
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
          if (next == null)
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
                    onPressed: () => reciteAyahs(
                      context,
                      ref,
                      next.first,
                      next.last,
                      page: next.page,
                    ),
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
