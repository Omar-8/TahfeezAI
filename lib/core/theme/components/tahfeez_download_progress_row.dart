import 'package:flutter/material.dart';

import '../app_spacing.dart';

/// A single resource's download progress: title, a linear progress bar (or
/// an indeterminate one while size is unknown), and a percentage/cancel
/// affordance. Matches the granular, per-resource progress model in
/// `lib/core/downloads/resource_download_status.dart`
/// (`ResourceDownloadProgress`) — this widget is what a Settings download
/// screen or a Storage Cleanup screen renders one of these against.
class TahfeezDownloadProgressRow extends StatelessWidget {
  const TahfeezDownloadProgressRow({
    super.key,
    required this.title,
    this.fraction,
    this.onCancel,
  });

  final String title;

  /// `null` while the total size is unknown (indeterminate progress).
  final double? fraction;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.xs,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (fraction != null)
                Text(
                  '${(fraction! * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (onCancel != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onCancel,
                  tooltip: 'Cancel',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(TahfeezSpacing.xs),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
