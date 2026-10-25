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
    this.onLongPress,
    this.bookmarked = false,
    this.progress,
    this.progressColor,
    this.progressLabel,
    this.singleLine = false,
    this.art,
  });

  /// The title and the line under it one line each, shortened to fit — a
  /// card of fixed size (a strip of cards), whatever the language or text
  /// size.
  final bool singleLine;

  /// Shown at the end, before the progress (a surah's name in calligraphy).
  final Widget? art;

  final int number;
  final String title;
  final String? subtitle;
  final Color? accentColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// A small bookmark after the title.
  final bool bookmarked;

  /// A share (0-1) shown at the card's end in place of the chevron — its
  /// percentage over a short bar (e.g. how much of a surah is memorized);
  /// `null`: the chevron.
  final double? progress;

  /// The progress's color (default: the accent).
  final Color? progressColor;

  /// Shown at the card's end instead of a share (e.g. "Practised"), when
  /// [progress] is `null`.
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: singleLine ? 1 : null,
                            overflow: singleLine ? TextOverflow.ellipsis : null,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        if (bookmarked)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: TahfeezSpacing.xs,
                            ),
                            child: Icon(
                              Icons.bookmark_rounded,
                              key: const ValueKey('section-card-bookmarked'),
                              size: 16,
                              color: accent,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: singleLine ? 1 : null,
                        overflow: singleLine ? TextOverflow.ellipsis : null,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (art case final art?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TahfeezSpacing.sm,
                    end: TahfeezSpacing.xs,
                  ),
                  child: art,
                ),
              if (progress case final p?)
                SizedBox(
                  key: const ValueKey('section-card-progress'),
                  width: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: TahfeezSpacing.xs,
                    children: [
                      Text(
                        '${(p.clamp(0.0, 1.0) * 100).round()}%',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: progressColor ?? accent),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                        child: LinearProgressIndicator(
                          value: p.clamp(0.0, 1.0),
                          minHeight: 4,
                          color: progressColor ?? accent,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                )
              else if (progressLabel case final label?)
                Text(
                  label,
                  key: const ValueKey('section-card-progress-label'),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                )
              else
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
