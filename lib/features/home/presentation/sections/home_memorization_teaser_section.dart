import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/application/recent_quran_location.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../application/home_providers.dart';
import '../home_location_label.dart';

/// Home's memorization section: this week's recitation practice, the latest
/// sessions (each opening where it started), and a way to start reciting —
/// the Mushaf, where Tahfeez follows the recitation word by word.
class HomeMemorizationTeaserSection extends ConsumerWidget {
  const HomeMemorizationTeaserSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(memorizationSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionMemorization,
          icon: Icons.bookmark_border,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        summary.when(
          data: (s) => _MemorizationCard(summary: s),
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) =>
              const _MemorizationCard(summary: MemorizationSummary()),
        ),
      ],
    );
  }
}

class _MemorizationCard extends ConsumerWidget {
  const _MemorizationCard({required this.summary});

  final MemorizationSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dates = MaterialLocalizations.of(context);
    final recent = ref.watch(recentQuranLocationControllerProvider);

    // Recitation is followed in the Mushaf: the last Mushaf page read, or
    // the Quran index to choose one.
    void start() {
      if (recent is QuranLocationPage) {
        goToQuranLocation(context, recent);
      } else {
        context.go(AppRoutes.quran);
      }
    }

    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          if (summary.recent.isEmpty)
            Row(
              spacing: TahfeezSpacing.smPlus,
              children: [
                Icon(Icons.auto_stories_outlined, color: scheme.primary),
                Expanded(
                  child: Text(
                    l10n.homeMemorizationEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              l10n.homeMemorizationWeek(
                summary.weekSessions,
                summary.weekMinutes,
              ),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              l10n.homeMemorizationRecent,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            for (final session in summary.recent)
              InkWell(
                borderRadius: BorderRadius.circular(TahfeezRadii.sm),
                onTap: session.startLocation == null
                    ? null
                    : () => goToQuranLocation(context, session.startLocation!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TahfeezSpacing.xs,
                  ),
                  child: Row(
                    spacing: TahfeezSpacing.sm,
                    children: [
                      Icon(
                        Icons.mic_none_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      Expanded(
                        child: Text(
                          session.startLocation == null
                              ? dates.formatMediumDate(session.startedAt)
                              : '${homeLocationLabel(l10n, session.startLocation!)}'
                                    ' · ${dates.formatMediumDate(session.startedAt)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        l10n.homeMemorizationMinutes(
                          (session.duration.inSeconds / 60).ceil(),
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: start,
              icon: const Icon(Icons.mic_none_outlined),
              label: Text(l10n.homeMemorizationStart),
            ),
          ),
        ],
      ),
    );
  }
}
