import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_models.dart';
import '../../recitation/application/hifz_controller.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/application/recitation_session_controller.dart';
import 'memorize_screen.dart' show ayahRangeLabel, surahNames;

/// A session's results, after it ends: each ayah's grade and its strength
/// before → after, and a loop over the weak ayahs.
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
    // The latest result per ayah (a loop recites them more than once).
    final latest = <int, SummaryRow>{};
    for (final r in summary.rows) {
      latest[r.attempt.ayahId] = r;
    }
    final rows = latest.values.toList()
      ..sort((a, b) => a.attempt.ayahId.compareTo(b.attempt.ayahId));
    final weak = [
      for (final r in rows)
        if (r.attempt.grade != AyahGrade.good) r.attempt.ayahId,
    ];

    (String, Color) grade(AyahGrade g) => switch (g) {
      AyahGrade.good => (l10n.memGradeGood, scheme.primary),
      AyahGrade.hard => (l10n.memGradeHard, scheme.tertiary),
      AyahGrade.fail => (l10n.memGradeFail, scheme.error),
    };
    String pct(double? s) => s == null ? '–' : '${(s * 100).round()}%';

    void repeatWeak() {
      final location = ref.read(mushafRecitationTargetProvider)?.location;
      Navigator.of(context).pop();
      if (location == null || weak.isEmpty) return;
      ref.read(hifzControllerProvider.notifier).setLoop((
        from: (chapterNo: weak.first ~/ 1000, verseNo: weak.first % 1000),
        to: (chapterNo: weak.last ~/ 1000, verseNo: weak.last % 1000),
      ), const HifzLoop(mode: HifzLoopMode.eachAyah, count: 3));
      ref
          .read(recitationSessionControllerProvider.notifier)
          .start(startLocation: location);
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
        spacing: TahfeezSpacing.sm,
        children: [
          Text(l10n.memSummaryTitle, style: theme.textTheme.titleLarge),
          if (weak.isEmpty)
            Text(
              l10n.memAllGood,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          TahfeezCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    key: ValueKey('mem-row-${r.attempt.ayahId}'),
                    dense: true,
                    title: Text(
                      ayahRangeLabel(r.attempt.ayahId, r.attempt.ayahId, names),
                    ),
                    subtitle: Text('${pct(r.before)} → ${pct(r.after)}'),
                    trailing: Text(
                      grade(r.attempt.grade).$1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: grade(r.attempt.grade).$2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
