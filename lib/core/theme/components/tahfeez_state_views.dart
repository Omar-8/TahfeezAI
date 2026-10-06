import 'package:flutter/material.dart';

import '../../localization/generated/app_localizations.dart';
import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// A centered loading indicator, for a screen/section that has nothing to
/// show yet. Kept trivial on purpose — this is the single place a future
/// milestone would add a skeleton/shimmer treatment if Tahfeez adopts one,
/// without touching every screen that shows a loading state today.
class TahfeezLoadingView extends StatelessWidget {
  const TahfeezLoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: TahfeezSpacing.md,
        children: [
          const CircularProgressIndicator(),
          if (message != null)
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A centered "nothing here yet" state — e.g. an empty bookmarks list or
/// empty read history (`docs/reference/11_HOME_SPEC.md` §4,
/// `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §2).
class TahfeezEmptyView extends StatelessWidget {
  const TahfeezEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              icon,
              size: TahfeezIconSize.xl * 1.5,
              color: scheme.onSurfaceVariant,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A centered error state with a retry affordance — for a failed load
/// (network manifest fetch, a corrupted resource) where the user has
/// something concrete to do next.
class TahfeezErrorView extends StatelessWidget {
  const TahfeezErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              Icons.error_outline,
              size: TahfeezIconSize.xl * 1.5,
              color: scheme.error,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null)
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}
