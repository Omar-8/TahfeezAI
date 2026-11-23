import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../application/saved_supplications.dart';

/// Bookmark (or no longer) an athkar chapter or a dua, by its key
/// ([SavedSupplications]): filled in the app's green once saved.
class SavedSupplicationButton extends ConsumerWidget {
  const SavedSupplicationButton(
    this.savedKey, {
    super.key,
    this.compact = false,
  });

  final String savedKey;

  /// Smaller, for a tile's corner (still a full tap target).
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final saved = ref.watch(
      savedSupplicationsProvider.select((s) => s.contains(savedKey)),
    );
    return IconButton(
      key: ValueKey('saved-$savedKey'),
      tooltip: saved ? l10n.bookmarkRemove : l10n.supplicationBookmark,
      isSelected: saved,
      visualDensity: compact ? VisualDensity.compact : null,
      icon: Icon(
        saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        color: saved ? scheme.primary : scheme.onSurfaceVariant,
        size: compact ? 22 : null,
      ),
      onPressed: () =>
          ref.read(savedSupplicationsProvider.notifier).toggle(savedKey),
    );
  }
}
