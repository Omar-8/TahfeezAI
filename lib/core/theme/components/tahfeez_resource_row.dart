import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';
import 'tahfeez_download_progress_row.dart';

/// Mirrors `ResourceDownloadState` (`lib/core/downloads/resource_download_status.dart`)
/// — this widget renders one state's trailing affordance; it does not read
/// the download service itself, keeping it presentation-only.
enum TahfeezResourceRowState {
  notDownloaded,
  downloading,
  downloaded,
  outdated,
  failed,
}

/// One row in a downloadable-resource list (a translation, a reciter, a
/// WBW language pack): title, subtitle, and a trailing affordance that
/// depends on [state] — a download icon, a progress row, a checkmark, an
/// "update" chip, or a retry icon. Purely presentational; wiring to
/// `ResourceDownloadService`/`ResourceRepository` is the Resource Manager
/// milestone's job.
class TahfeezResourceRow extends StatelessWidget {
  const TahfeezResourceRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.state,
    this.progressFraction,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final TahfeezResourceRowState state;
  final double? progressFraction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (state == TahfeezResourceRowState.downloading) {
      return TahfeezDownloadProgressRow(
        title: title,
        fraction: progressFraction,
        onCancel: onAction,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          _trailing(context, scheme),
        ],
      ),
    );
  }

  Widget _trailing(BuildContext context, ColorScheme scheme) {
    switch (state) {
      case TahfeezResourceRowState.notDownloaded:
        return IconButton(
          icon: const Icon(Icons.download_outlined),
          iconSize: TahfeezIconSize.lg,
          onPressed: onAction,
        );
      case TahfeezResourceRowState.downloaded:
        return Icon(
          Icons.check_circle,
          size: TahfeezIconSize.lg,
          color: scheme.primary,
        );
      case TahfeezResourceRowState.outdated:
        return FilledButton.tonal(
          onPressed: onAction,
          child: const Text('Update'),
        );
      case TahfeezResourceRowState.failed:
        return IconButton(
          icon: Icon(Icons.error_outline, color: scheme.error),
          iconSize: TahfeezIconSize.lg,
          onPressed: onAction,
          tooltip: 'Retry',
        );
      case TahfeezResourceRowState.downloading:
        return const SizedBox.shrink(); // handled above
    }
  }
}
