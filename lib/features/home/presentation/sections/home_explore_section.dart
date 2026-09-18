import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../coming_soon.dart';

/// Home's "Quran collections/exploration" section
/// (`docs/reference/11_HOME_SPEC.md` §6). The category set
/// (Duas/Topics/Prophets/Science) comes from `docs/PROJECT_BRIEF.md`'s own
/// "Explore" product area, not from the reference app's specific category
/// roster/icons — each opens a "coming soon" acknowledgement today since
/// their destination screens are the VOTD/Collections milestone's job
/// (Milestone 15). The grid's column count adapts with
/// [TahfeezBreakpoint], per this milestone's "card/grid adaptation on
/// tablet" requirement.
class HomeExploreSection extends StatelessWidget {
  const HomeExploreSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final breakpoint = TahfeezBreakpoint.of(context);
    final columns = breakpoint.isAtLeastTablet ? 4 : 2;

    final categories = [
      (icon: Icons.self_improvement_outlined, label: l10n.exploreDuas),
      (icon: Icons.topic_outlined, label: l10n.exploreTopics),
      (icon: Icons.groups_outlined, label: l10n.exploreProphets),
      (icon: Icons.science_outlined, label: l10n.exploreScience),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionExplore,
          icon: Icons.explore_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: TahfeezSpacing.sm,
          crossAxisSpacing: TahfeezSpacing.sm,
          childAspectRatio: 1.4,
          children: [
            for (final category in categories)
              TahfeezCard(
                onTap: () => showComingSoon(context),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: TahfeezSpacing.sm,
                  children: [
                    Icon(
                      category.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Text(
                      category.label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
