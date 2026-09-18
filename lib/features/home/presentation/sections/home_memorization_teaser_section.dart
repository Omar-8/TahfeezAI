import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';

/// A concrete, visible placeholder for the memorization dashboard sections
/// (Today's Memorization, Today's Revision, Memorization progress) this
/// milestone must be able to add later "without redesigning the app shell"
/// — per this milestone's explicit "do not paint the architecture into a
/// reading-only corner" requirement. Rather than only architecting an
/// invisible seam, Home reserves and shows this section's slot today, so
/// the Memorization milestone (17) can replace its body with the real
/// dashboard content without moving Home's section order around.
class HomeMemorizationTeaserSection extends StatelessWidget {
  const HomeMemorizationTeaserSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionMemorization,
          icon: Icons.bookmark_border,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        TahfeezCard(
          child: Row(
            spacing: TahfeezSpacing.smPlus,
            children: [
              Icon(Icons.auto_stories_outlined, color: scheme.primary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: TahfeezSpacing.xs,
                  children: [
                    Text(
                      l10n.homeMemorizationTeaserTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.homeMemorizationTeaserBody,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
