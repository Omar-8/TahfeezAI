import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// A section header: leading icon, title, and an optional trailing "view
/// all"-style action — the pattern `docs/reference/11_HOME_SPEC.md` shows
/// used throughout Home, reused here as a Tahfeez-owned component rather
/// than a copy of that screen's specific implementation.
class TahfeezSectionHeader extends StatelessWidget {
  const TahfeezSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.onViewAll,
    this.viewAllLabel = 'View all',
  });

  final String title;
  final IconData? icon;
  final VoidCallback? onViewAll;
  final String viewAllLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: TahfeezIconSize.lg, color: scheme.primary),
          const SizedBox(width: TahfeezSpacing.sm),
        ],
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: Text(viewAllLabel)),
      ],
    );
  }
}
