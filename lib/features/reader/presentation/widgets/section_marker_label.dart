import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// `ReaderSectionMarkerItem`'s label: a lightweight inline divider for a
/// structural boundary (a Ruku change) between verses —
/// `docs/reference/04_READER_SPEC.md` §13's `SectionMarker`.
class SectionMarkerLabel extends StatelessWidget {
  const SectionMarkerLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.md,
        vertical: TahfeezSpacing.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
