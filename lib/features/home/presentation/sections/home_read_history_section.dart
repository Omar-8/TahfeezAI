import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/home_providers.dart';

/// Home's "Continue Reading / read history" section
/// (`docs/reference/11_HOME_SPEC.md` §4). Always renders the empty state
/// today — no `UserDataRepository` implementation exists yet (Milestone
/// 11) — but the section itself, and the provider it watches, already
/// exist so wiring real history later is additive, not a Home redesign.
class HomeReadHistorySection extends ConsumerWidget {
  const HomeReadHistorySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(readHistoryPreviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionContinueReading,
          icon: Icons.history,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        history.when(
          data: (entries) => TahfeezCard(
            child: entries.isEmpty
                ? TahfeezEmptyView(
                    icon: Icons.history,
                    message: l10n.homeReadHistoryEmpty,
                  )
                : Text(entries.join(', ')),
          ),
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
