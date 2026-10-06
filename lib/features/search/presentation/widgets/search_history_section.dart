import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/search_history_controller.dart';

/// Recent search queries — shown while the search field is empty
/// (`docs/reference/07_SEARCH_SPEC.md` §7's `SearchHistorySection`), each
/// tappable to re-run and individually deletable, with a "Clear all"
/// action — this milestone's "search history: persist locally and allow
/// clear/delete behavior" requirement made concrete.
class SearchHistorySection extends ConsumerWidget {
  const SearchHistorySection({super.key, required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryControllerProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: AppLocalizations.of(context).searchRecent,
          icon: Icons.history,
          onViewAll: () =>
              ref.read(searchHistoryControllerProvider.notifier).clear(),
          viewAllLabel: AppLocalizations.of(context).searchClearAll,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        for (final entry in history)
          TahfeezListRow(
            title: entry.query,
            leading: const Icon(Icons.history),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: AppLocalizations.of(context).searchRemove,
              onPressed: () => ref
                  .read(searchHistoryControllerProvider.notifier)
                  .remove(entry.query),
            ),
            onTap: () => onSelect(entry.query),
          ),
      ],
    );
  }
}
