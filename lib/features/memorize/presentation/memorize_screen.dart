import 'package:flutter/material.dart';

import '../../../core/ui/motion.dart';
import '../../../core/ui/bar_space.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/home_sky.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_models.dart';
import '../../../memorization/domain/recitation_score.dart';
import '../../../memorization/domain/strength_model.dart';
import '../../../memorization/domain/today_scheduler.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/reader_mode.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/hifz_controller.dart';
import 'mark_known_sheet.dart';
import 'plan_sheet.dart';
import 'progress_screen.dart';
import '../../../core/ui/back_to_exit.dart';
import '../../mushaf/application/reading_surah.dart';

/// The Memorize tab, in two tabs: the plan — today's memorization, the
/// three parts of a Hifz day (`docs/MEMORIZATION_MILESTONE.md`), with how
/// today's recitation went — and the progress
/// ([MemorizationProgressView]). Each task opens the Mushaf at its range
/// with hide mode on, the Hifz test set to it; the reciter starts with the
/// mic.
class MemorizeScreen extends ConsumerStatefulWidget {
  const MemorizeScreen({super.key, this.tab = MemorizeTab.plan});

  /// The tab it opens on (`/memorize?tab=progress`, `/memorize/progress`).
  final MemorizeTab tab;

  @override
  ConsumerState<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends ConsumerState<MemorizeScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.tab.index,
  )..addListener(() => setState(() {})); // The top bar's action follows it.

  @override
  void didUpdateWidget(covariant MemorizeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Asked for another tab (a link) while the screen is kept.
    if (widget.tab != oldWidget.tab) _tabs.animateTo(widget.tab.index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(todayPlanProvider);
    final names = surahNames(ref);

    Widget section(String title, String subtitle, IconData icon, Widget body) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.sm,
          children: [
            TahfeezSectionHeader(title: title, icon: icon),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            body,
          ],
        );

    return BackToExit(
      child: SkyBackdrop(
        child: Scaffold(
          appBar: TahfeezAppBar(
            title: Text(l10n.memTitle),
            centerTitle: false,
            actions: [
              // Marking what is already known, beside the progress.
              if (_tabs.index == 1) MarkKnownAction(title: l10n.memTitle),
            ],
          ),
          body: Column(
            children: [
              TabBar(
                controller: _tabs,
                tabs: [
                  Tab(
                    key: const ValueKey('mem-tab-plan'),
                    text: l10n.memTabPlan,
                  ),
                  Tab(
                    key: const ValueKey('mem-tab-progress'),
                    text: l10n.memProgressTitle,
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _plan(context, l10n, plan, names, section),
                    const MemorizationProgressView(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The plan tab: today's score, the new lesson and the revision.
  Widget _plan(
    BuildContext context,
    AppLocalizations l10n,
    AsyncValue<TodayPlan> plan,
    Map<int, String> names,
    Widget Function(String, String, IconData, Widget) section,
  ) => plan.when(
    loading: () => const TahfeezLoadingView(),
    error: (e, _) => TahfeezEmptyView(message: '$e'),
    data: (today) => ListView(
      padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
      children: [
        const _TodayScore(),
        const SizedBox(height: TahfeezSpacing.lg),
        section(
          l10n.memNewLesson,
          l10n.memLessonHint,
          Icons.auto_stories_outlined,
          _NewLessonCard(names: names),
        ),
        const SizedBox(height: TahfeezSpacing.lg),
        if (today.isEmpty)
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TahfeezSpacing.sm,
              children: [
                Text(
                  l10n.memEmptyTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.memEmptyBody),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('mem-empty-mark-known'),
                    onPressed: () => showMarkKnownSheet(context),
                    icon: const Icon(Icons.playlist_add_check),
                    label: Text(l10n.memMarkKnown),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (today.recent.isNotEmpty) ...[
            section(
              l10n.memRecent,
              l10n.memRecentSub,
              Icons.replay_outlined,
              _TaskList(tasks: today.recent, names: names),
            ),
            const SizedBox(height: TahfeezSpacing.lg),
          ],
          if (today.old.isNotEmpty)
            section(
              l10n.memOld,
              l10n.memOldSub,
              Icons.history_edu_outlined,
              _TaskList(tasks: today.old, names: names),
            ),
        ],
      ],
    ),
  );
}

/// The Memorize screen's tabs.
enum MemorizeTab { plan, progress }

/// Each surah's name in the UI language, by number.
Map<int, String> surahNames(WidgetRef ref) => <int, String>{
  for (final s
      in ref.watch(indexedSurahsProvider).value ?? const <IndexedSurah>[])
    s.surah.surahNo: s.localizedName ?? s.arabicName ?? '${s.surah.surahNo}',
};

/// "Al-Ikhlas 1-4", "Al-Ikhlas 1 - An-Nas 6" for ayahs [first]..[last]
/// (stable ids).
String ayahRangeLabel(int first, int last, Map<int, String> names) {
  String name(int ayah) => names[ayah ~/ 1000] ?? '${ayah ~/ 1000}';
  if (first == last) return '${name(first)} ${first % 1000}';
  if (first ~/ 1000 == last ~/ 1000) {
    return '${name(first)} ${first % 1000}–${last % 1000}';
  }
  return '${name(first)} ${first % 1000} – ${name(last)} ${last % 1000}';
}

/// A score (0-1) as a labelled bar: green from 90%, amber from 70%, red
/// below.
class ScoreBar extends StatelessWidget {
  const ScoreBar({
    super.key,
    required this.label,
    required this.value,
    this.dense = false,
  });

  final String label;
  final double value;

  /// Thinner, with smaller text (in a list row).
  final bool dense;

  static Color colorOf(double value, ColorScheme scheme) =>
      value >= StrengthModel.fading
      ? scheme.primary
      : value >= StrengthModel.weak
      ? scheme.tertiary
      : scheme.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = colorOf(value, scheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.xs,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: dense
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style:
                  (dense
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.labelLarge)
                      ?.copyWith(color: color),
            ),
          ],
        ),
        // Filling as it appears.
        ClipRRect(
          borderRadius: BorderRadius.circular(TahfeezRadii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: motion(context, const Duration(milliseconds: 700)),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: dense ? 4 : 6,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
    );
  }
}

/// Memorization and tajweed of [score], side by side.
class ScorePair extends StatelessWidget {
  const ScorePair({super.key, required this.score, this.dense = false});

  final RecitationScore score;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      spacing: TahfeezSpacing.md,
      children: [
        Expanded(
          child: ScoreBar(
            label: l10n.memScoreMemorization,
            value: score.memorization,
            dense: dense,
          ),
        ),
        Expanded(
          child: ScoreBar(
            label: l10n.memScoreTajweed,
            value: score.tajweed,
            dense: dense,
          ),
        ),
      ],
    );
  }
}

/// Today's recitation so far: ayahs recited, and how memorization and
/// tajweed went.
class _TodayScore extends ConsumerWidget {
  const _TodayScore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final score = RecitationScore.of(
      ref.watch(todayAttemptsProvider).value ?? const <AyahAttempt>[],
    );
    return TahfeezCard(
      key: const ValueKey('mem-today-score'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Text(
            l10n.memTodayRecited(score.ayahs),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!score.isEmpty) ScorePair(score: score),
        ],
      ),
    );
  }
}

VerseRef _verse(int ayah) => (chapterNo: ayah ~/ 1000, verseNo: ayah % 1000);

/// Opens the Mushaf at [first]'s page (or [page]) with hide mode on and the
/// Hifz test set to [first]..[last].
Future<void> reciteAyahs(
  BuildContext context,
  WidgetRef ref,
  int first,
  int last, {
  int? page,
}) async {
  final mushaf = await ref.read(defaultMushafProvider.future);
  final pages = await ref.read(ayahPagesProvider.future);
  page ??= pages[first];
  if (mushaf == null || page == null || !context.mounted) return;
  ref.read(requestedHifzRangeProvider.notifier).request((
    from: _verse(first),
    to: _verse(last),
  ));
  final hide = ref.read(mushafHideModeProvider.notifier);
  if (!ref.read(mushafHideModeProvider).enabled) hide.toggle();
  // Ayah mode: the part's first ayah brought into view, not the page's top
  // (Al-Qadr 1 is far down page 598).
  ref.read(ayahModeTargetProvider.notifier).show(first);
  ref.read(readingSurahProvider.notifier).read(page, first);
  goToQuranLocation(context, QuranLocation.page(mushaf.id, page));
}

/// Today's new lesson from the plan, or how to make one. Once it is
/// learned, the next lesson can be learned too.
class _NewLessonCard extends ConsumerStatefulWidget {
  const _NewLessonCard({required this.names});

  final Map<int, String> names;

  @override
  ConsumerState<_NewLessonCard> createState() => _NewLessonCardState();
}

class _NewLessonCardState extends ConsumerState<_NewLessonCard> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plan = ref.watch(activePlanProvider).value;
    final lesson = ref.watch(newLessonProvider).value;
    if (plan == null || lesson == null) {
      return TahfeezCard(
        key: const ValueKey('mem-plan-none'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.smPlus,
          children: [
            Text(l10n.memPlanNone),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                key: const ValueKey('mem-plan-create'),
                onPressed: () => showPlanSheet(context),
                icon: const Icon(Icons.add),
                label: Text(l10n.memPlanCreate),
              ),
            ),
          ],
        ),
      );
    }
    List<Widget> runRow(
      List<int> run, {
      bool again = false,
      bool quiet = false,
      bool divider = true,
    }) {
      void start() => reciteAyahs(context, ref, run.first, run.last);
      return [
        if (divider) const Divider(height: 1),
        Padding(
          key: ValueKey('mem-lesson-${run.first}'),
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.smPlus,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  ayahRangeLabel(run.first, run.last, names),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (again || quiet)
                TextButton(
                  onPressed: start,
                  child: Text(again ? l10n.memAgain : l10n.memStart),
                )
              else
                FilledButton.tonal(
                  onPressed: start,
                  child: Text(l10n.memStart),
                ),
            ],
          ),
        ),
      ];
    }

    final status = lesson.finished
        ? l10n.memPlanFinished
        : lesson.rest
        ? l10n.memLessonRest
        : lesson.done
        ? l10n.memLessonDone
        : null;
    return TahfeezCard(
      key: const ValueKey('mem-lesson'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TahfeezSpacing.md,
              TahfeezSpacing.smPlus,
              TahfeezSpacing.xs,
              TahfeezSpacing.smPlus,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ScoreBar(
                    label: l10n.memPlanProgress(lesson.memorized, lesson.total),
                    value: lesson.progress,
                    dense: true,
                  ),
                ),
                IconButton(
                  key: const ValueKey('mem-plan-edit'),
                  tooltip: l10n.memPlanEdit,
                  onPressed: () => showPlanSheet(context, plan: plan),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ),
          if (status != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(TahfeezSpacing.md),
              child: Text(status, style: theme.textTheme.bodyLarge),
            ),
          ],
          for (final run in lesson.runs)
            ...runRow(run, again: lesson.done, quiet: lesson.rest),
          if (lesson.done && lesson.more.isNotEmpty) ...[
            const Divider(height: 1),
            if (!_more)
              Padding(
                padding: const EdgeInsets.all(TahfeezSpacing.sm),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('mem-lesson-more'),
                    onPressed: () => setState(() => _more = true),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.memLessonMore),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  TahfeezSpacing.md,
                  TahfeezSpacing.smPlus,
                  TahfeezSpacing.md,
                  0,
                ),
                child: Text(
                  l10n.memLessonNext,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (i, run) in lesson.more.indexed)
                ...runRow(run, divider: i > 0),
            ],
          ],
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.names});

  static final _compact = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: TahfeezSpacing.md),
    ),
  );

  /// [spans] with " · " between them.
  static List<InlineSpan> _joined(List<InlineSpan> spans) => [
    for (final (i, span) in spans.indexed) ...[
      if (i > 0) const TextSpan(text: ' · '),
      span,
    ],
  ];

  final List<RevisionTask> tasks;
  final Map<int, String> names;

  Future<void> _start(BuildContext context, WidgetRef ref, RevisionTask t) =>
      reciteAyahs(context, ref, t.first, t.last, page: t.page);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final today =
        ref.watch(todayAttemptsProvider).value ?? const <AyahAttempt>[];
    RecitationScore scoreOf(RevisionTask t) {
      final ids = t.ayahIds.toSet();
      return RecitationScore.of(today.where((a) => ids.contains(a.ayahId)));
    }

    TextSpan percent(String label, double value) => TextSpan(
      text: '$label ',
      children: [
        TextSpan(
          text: '${(value * 100).round()}%',
          style: TextStyle(
            color: ScoreBar.colorOf(value, theme.colorScheme),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return TahfeezCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, t) in tasks.indexed) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              key: ValueKey('mem-task-${t.first}'),
              padding: const EdgeInsetsDirectional.fromSTEB(
                TahfeezSpacing.md,
                TahfeezSpacing.xs,
                TahfeezSpacing.sm,
                TahfeezSpacing.xs,
              ),
              child: Row(
                spacing: TahfeezSpacing.sm,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ayahRangeLabel(t.first, t.last, names),
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text.rich(
                          TextSpan(
                            children: _joined([
                              if (t.page != null)
                                TextSpan(text: l10n.memPage(t.page!)),
                              if (t.unverified)
                                TextSpan(text: l10n.memUnverified),
                              // Recited today: how it went. Otherwise its
                              // memory's strength.
                              if (scoreOf(t) case final s when !s.isEmpty) ...[
                                percent(
                                  l10n.memScoreMemorization,
                                  s.memorization,
                                ),
                                percent(l10n.memScoreTajweed, s.tajweed),
                              ] else if (t.strength case final s?)
                                percent(l10n.memStrengthLabel, s),
                            ]),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (t.done)
                    TextButton(
                      style: _compact,
                      onPressed: () => _start(context, ref, t),
                      child: Text(l10n.memAgain),
                    )
                  else
                    FilledButton.tonal(
                      style: _compact,
                      onPressed: () => _start(context, ref, t),
                      child: Text(l10n.memStart),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
