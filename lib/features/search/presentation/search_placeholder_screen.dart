import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';

/// The Search tab's content for this milestone. Full-text Quran search is
/// the Search milestone's job (Milestone 10, backed by its own derived
/// search-index database — `docs/ARCHITECTURE.md` §4). This screen only
/// proves the shell's third destination is real.
class SearchPlaceholderScreen extends StatelessWidget {
  const SearchPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.md,
          children: [
            Text(
              l10n.searchPlaceholderTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TahfeezEmptyView(
              icon: Icons.search_outlined,
              message: l10n.searchPlaceholderBody,
            ),
          ],
        ),
      ),
    );
  }
}
