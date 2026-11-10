import 'package:flutter/material.dart';

import '../../../core/ui/motion.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_models.dart';
import '../../../memorization/domain/recitation_score.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import '../../recitation/application/hifz_controller.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/application/recitation_session_controller.dart';
import 'memorize_screen.dart' show ScorePair, ayahRangeLabel, surahNames;

/// A session's results, after it ends — an overview: how many ayahs and how
/// they went, memorization and tajweed, the strength before → after, and
/// only the ayahs to review (with a loop over them).
Future<void> showTestSummarySheet(BuildContext context, TestSummary summary) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      besideOnWide: true,
      builder: (context) => _TestSummarySheet(summary: summary),
    );

class _TestSummarySheet extends ConsumerWidget {
  const _TestSummarySheet({required this.summary});

  final TestSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = surahNames(ref);
    final score = RecitationScore.of(summary.rows.map((r) => r.attempt));
    // The strength before the session and after it: each ayah's first
    // "before" and last "after" (a loop recites them more than once).
    final before = <int, double>{}, after = <int, double>{};
    for (final r in summary.rows) {
      final id = r.attempt.ayahId;
      if (r.before case final b? when !before.containsKey(id)) before[id] = b;
      if (r.after case final a?) after[id] = a;
    }
    int mean(Map<int, double> m) => m.isEmpty
        ? 0
        : (m.values.reduce((a, b) => a + b) / m.length * 100).round();
    // To review: an ayah whose latest result was not good.
    final latest = <int, AyahGrade>{};
    for (final r in summary.rows) {
      latest[r.attempt.ayahId] = r.attempt.grade;
    }
    final weak = [
      for (final MapEntry(key: id, value: g) in latest.entries)
        if (g != AyahGrade.good) (id, g),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    // How long it took: from the session's start (its id holds it) to its
    // last graded ayah.
    final starts = [
      for (final r in summary.rows)
        ?RecitationSessionController.startedAtOf(r.attempt.sessionId),
    ];
    final minutes = starts.isEmpty
        ? null
        : summary.rows
              .map((r) => r.attempt.at)
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .difference(starts.reduce((a, b) => a.isBefore(b) ? a : b))
              .inMinutes;
    // Against last time: these ayahs' tests before this session, and their
    // latest now.
    final previous = <int, AyahAttempt>{
      for (final r in summary.rows) r.attempt.ayahId: ?r.previous,
    };
    final latestAttempts = <int, AyahAttempt>{
      for (final r in summary.rows) r.attempt.ayahId: r.attempt,
    };
    final then = RecitationScore.of(previous.values);
    final nowScore = RecitationScore.of([
      for (final id in previous.keys) ?latestAttempts[id],
    ]);
    String percent(double v) => '${(v * 100).round()}';

    void repeatWeak(int times) {
      final location = ref.read(mushafRecitationTargetProvider)?.location;
      Navigator.of(context).pop();
      if (location == null || weak.isEmpty) return;
      final first = weak.first.$1, last = weak.last.$1;
      ref.read(hifzControllerProvider.notifier).setLoop((
        from: (chapterNo: first ~/ 1000, verseNo: first % 1000),
        to: (chapterNo: last ~/ 1000, verseNo: last % 1000),
      ), HifzLoop(mode: HifzLoopMode.eachAyah, count: times));
      ref
          .read(recitationSessionControllerProvider.notifier)
          .start(startLocation: location);
    }

    // An ayah to review, tapped (or "Check my mistakes": the first of all):
    // its page shown (turned to behind the results if not on screen) and
    // its first mistake's word sheet over the results — on from it to the
    // others; closed, back to the results. (Looked at, the bar's "Mistakes
    // found" goes.)
    Future<void> openAyah(int? ayahId) async {
      final location = ref.read(mushafRecitationTargetProvider)?.location;
      final word = firstMarkedMistake(
        ref.read(mushafWordOverlayProvider),
        ayahId: ayahId,
      );
      ayahId ??= word?.ayahId;
      if (ayahId == null) return;
      final shown = ref
          .read(mushafPageWordRangesProvider)
          .values
          .any((r) => r.first.ayahId <= ayahId! && r.last.ayahId >= ayahId);
      if (!shown && location is QuranLocationPage) {
        final turns = ref.read(mushafPageTurnRequestsProvider.notifier);
        final page = await ref
            .read(quranRepositoryProvider)
            .getPageForAyah(mushafId: location.mushafId, ayahId: ayahId);
        if (page != null) turns.toPage(page);
      }
      if (word != null && context.mounted) {
        showWordDetailSheet(context, wordRef: word);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          // The results' moment: the eight-pointed star turning into
          // place beside the title — filled, in gold, when every ayah went
          // well.
          Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: motion(context, TahfeezMotionDuration.emphasis),
                curve: Curves.easeOutBack,
                builder: (context, t, child) => Transform.rotate(
                  angle: (1 - t) * -0.8,
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * t,
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  ),
                ),
                child: TahfeezStar(
                  color: scheme.tertiary,
                  size: 30,
                  filled: weak.isEmpty,
                ),
              ),
              Expanded(
                child: Text(
                  l10n.memSummaryTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              // Close, at the header's far end (right; left in RTL).
              IconButton(
                key: const ValueKey('mem-summary-close'),
                tooltip: l10n.memClose,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            l10n.memSummaryCounts(
              latest.length,
              latest.values.where((g) => g == AyahGrade.good).length,
              latest.values.where((g) => g == AyahGrade.hard).length,
              latest.values.where((g) => g == AyahGrade.fail).length,
            ),
            key: const ValueKey('mem-summary-counts'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (minutes != null || !then.isEmpty)
            Wrap(
              spacing: TahfeezSpacing.md,
              runSpacing: TahfeezSpacing.xs,
              children: [
                if (minutes != null)
                  _Fact(
                    key: const ValueKey('mem-summary-time'),
                    icon: Icons.timer_outlined,
                    text: l10n.memSummaryMinutes(minutes),
                  ),
                if (!then.isEmpty)
                  _Fact(
                    icon: nowScore.memorization >= then.memorization
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    text: l10n.memSummaryVsLast(
                      percent(then.memorization),
                      percent(nowScore.memorization),
                    ),
                  ),
              ],
            ),
          if (!then.isEmpty)
            _VsLastBar(
              key: const ValueKey('mem-summary-vs-last'),
              then: then.memorization,
              now: nowScore.memorization,
            ),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.smPlus,
              children: [
                ScorePair(score: score),
                if (after.isNotEmpty)
                  Text(
                    l10n.memSummaryStrength(mean(before), mean(after)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (weak.isEmpty)
            Text(l10n.memAllGood, style: theme.textTheme.bodyMedium)
          else ...[
            Text(l10n.memToReview, style: theme.textTheme.titleSmall),
            Text(
              l10n.memToReviewTap,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Wrap(
              spacing: TahfeezSpacing.sm,
              runSpacing: TahfeezSpacing.sm,
              children: [
                for (final (id, g) in weak)
                  ActionChip(
                    key: ValueKey('mem-weak-$id'),
                    side: BorderSide(
                      color: g == AyahGrade.fail
                          ? scheme.error
                          : scheme.tertiary,
                    ),
                    label: Text(ayahRangeLabel(id, id, names)),
                    onPressed: () => openAyah(id),
                  ),
              ],
            ),
          ],
          if (firstMarkedMistake(ref.watch(mushafWordOverlayProvider)) != null)
            OutlinedButton.icon(
              key: const ValueKey('mem-check-mistakes'),
              icon: const Icon(Icons.error_outline_rounded),
              label: Text(l10n.memCheckMistakes),
              onPressed: () => openAyah(null),
            ),
          if (weak.isNotEmpty) _RepeatWeak(onRepeat: repeatWeak),
        ],
      ),
    );
  }
}

/// Last time against now, as a bar: a faint mark at last time's score,
/// and now's filling from there to where it is — past it when better,
/// back under it when worse.
class _VsLastBar extends StatelessWidget {
  const _VsLastBar({super.key, required this.then, required this.now});

  /// Scores, 0-1.
  final double then, now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final better = now >= then;
    Widget fill(double value, Color color) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: value.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        child: SizedBox(
          height: 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: scheme.surfaceContainerHighest),
              fill(then, scheme.onSurfaceVariant.withValues(alpha: 0.3)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: then, end: now),
                duration: motion(context, TahfeezMotionDuration.emphasis),
                curve: TahfeezMotionCurves.standard,
                builder: (context, v, _) =>
                    fill(v, better ? scheme.primary : scheme.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fact about the session, small, with its icon.
class _Fact extends StatelessWidget {
  const _Fact({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TahfeezSpacing.xs,
      children: [
        Icon(icon, size: 16, color: color),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Repeat the ayahs to review: how many times each, then the loop.
class _RepeatWeak extends StatefulWidget {
  const _RepeatWeak({required this.onRepeat});

  final ValueChanged<int> onRepeat;

  @override
  State<_RepeatWeak> createState() => _RepeatWeakState();
}

class _RepeatWeakState extends State<_RepeatWeak> {
  var _times = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        Row(
          spacing: TahfeezSpacing.sm,
          children: [
            Expanded(
              child: Text(
                l10n.recLoopTimesAyahSub,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final n in const [3, 5, 7])
              ChoiceChip(
                key: ValueKey('mem-repeat-$n'),
                label: Text('×$n'),
                selected: _times == n,
                showCheckmark: false,
                onSelected: (_) => setState(() => _times = n),
              ),
          ],
        ),
        FilledButton.icon(
          key: const ValueKey('mem-repeat-weak'),
          icon: const Icon(Icons.repeat_rounded),
          label: Text(l10n.memRepeatWeak),
          onPressed: () => widget.onRepeat(_times),
        ),
      ],
    );
  }
}
