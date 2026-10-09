import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// A card representing one Quran navigation unit — a chapter, Juz, Hizb, or
/// page — for use in navigator lists (`docs/reference/04_READER_SPEC.md`
/// §4). A number badge, a title, and an optional subtitle/meta line, with
/// the badge's accent color left to the caller (the reference app
/// distinguishes chapter/Juz/Hizb by accent color —
/// `docs/reference/11_HOME_SPEC.md` §4 — Tahfeez expresses the same
/// semantic distinction with its own token colors, not the reference's
/// specific hues).
class TahfeezQuranSectionCard extends StatelessWidget {
  const TahfeezQuranSectionCard({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.accentColor,
    this.onTap,
    this.footer,
  });

  final int number;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;

  /// Shown under the title and subtitle (e.g. progress).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TahfeezSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: TahfeezSpacing.smPlus),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    if (footer != null) ...[
                      const SizedBox(height: TahfeezSpacing.sm),
                      footer!,
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: TahfeezIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
