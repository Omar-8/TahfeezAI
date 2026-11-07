import 'package:flutter/material.dart';

import '../../../core/ui/motion.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
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

    void repeatWeak() {
      final location = ref.read(mushafRecitationTargetProvider)?.location;
      Navigator.of(context).pop();
      if (location == null || weak.isEmpty) return;
      final first = weak.first.$1, last = weak.last.$1;
      ref.read(hifzControllerProvider.notifier).setLoop((
        from: (chapterNo: first ~/ 1000, verseNo: first % 1000),
        to: (chapterNo: last ~/ 1000, verseNo: last % 1000),
      ), const HifzLoop(mode: HifzLoopMode.eachAyah, count: 3));
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
                duration: motion(context, const Duration(milliseconds: 800)),
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
                    visualDensity: VisualDensity.compact,
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
          Row(
            spacing: TahfeezSpacing.sm,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.memClose),
              ),
              if (weak.isNotEmpty)
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('mem-repeat-weak'),
                    icon: const Icon(Icons.repeat_rounded),
                    label: Text(l10n.memRepeatWeak),
                    onPressed: repeatWeak,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
