import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/home_providers.dart';
import '../home_location_label.dart';

/// Home's "Continue Reading": the last place read, one tap from being
/// opened again, and where the last recitation session started. An empty
/// state until either exists.
class HomeReadHistorySection extends ConsumerWidget {
  const HomeReadHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final continueReading = ref.watch(continueReadingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionContinueReading,
          icon: Icons.history,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        continueReading.when(
          data: (c) => _ContinueReadingCard(data: c),
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) => TahfeezCard(
            child: TahfeezEmptyView(
              icon: Icons.history,
              message: l10n.homeReadHistoryEmpty,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.data});

  final ContinueReading data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = data.location;
    final recitation = data.lastRecitation?.startLocation;
    if (location == null && recitation == null) {
      return TahfeezCard(
        child: TahfeezEmptyView(
          icon: Icons.history,
          message: l10n.homeReadHistoryEmpty,
        ),
      );
    }
    return TahfeezCard(
      onTap: location == null
          ? null
          : () => goToQuranLocation(context, location),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          if (location != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final place = Row(
                  spacing: TahfeezSpacing.smPlus,
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: const Icon(Icons.bookmark_outline),
                    ),
                    Expanded(
                      child: Text(
                        homeLocationLabel(
                          l10n,
                          location,
                          chapterName: data.chapterName,
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                );
                final button = FilledButton(
                  onPressed: () => goToQuranLocation(context, location),
                  child: Text(l10n.homeContinueReadingAction),
                );
                // Narrow for its text (a small screen, large text): the
                // button under the place, not squeezed beside it.
                final scale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxWidth / scale < 220) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: TahfeezSpacing.sm,
                    children: [place, button],
                  );
                }
                return Row(
                  spacing: TahfeezSpacing.smPlus,
                  children: [
                    Expanded(child: place),
                    button,
                  ],
                );
              },
            ),
          if (recitation != null)
            InkWell(
              borderRadius: BorderRadius.circular(TahfeezRadii.sm),
              onTap: () => goToQuranLocation(context, recitation),
              child: Row(
                spacing: TahfeezSpacing.sm,
                children: [
                  Icon(
                    Icons.mic_none_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      l10n.homeContinueReadingLastRecitation(
                        homeLocationLabel(l10n, recitation),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
