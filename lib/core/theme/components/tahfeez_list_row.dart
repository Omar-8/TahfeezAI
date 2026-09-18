import 'package:flutter/material.dart';

import '../app_spacing.dart';

/// A generic list row: leading widget, title, optional subtitle, trailing
/// widget. The shared shape behind more specific rows
/// (`TahfeezSettingsTile`, `TahfeezResourceRow`) and usable directly for any
/// other simple row (a bookmark, a search result, a navigator entry).
class TahfeezListRow extends StatelessWidget {
  const TahfeezListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TahfeezSpacing.md,
          vertical: dense ? TahfeezSpacing.sm : TahfeezSpacing.smPlus,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: TahfeezSpacing.smPlus),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: TahfeezSpacing.smPlus),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
