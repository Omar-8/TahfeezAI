import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_elevation.dart';
import '../tahfeez_icon_sizes.dart';

/// A compact, always-reachable audio player bar shell: artwork slot,
/// title/subtitle, and a play/pause button.
///
/// Presentational only — no `AudioController` wiring here. Matches
/// `docs/DESIGN_DIRECTION.md`'s "compact audio-player integration" and
/// `docs/reference/08_AUDIO_SPEC.md` §6's mini-player concept, reused as a
/// generic shell the Audio milestone (12) fills in with real playback
/// state. Per `docs/reference/18_VISUAL_REFERENCE_NOTES.md` §6, Tahfeez's
/// shell is meant to be mountable at the app-shell level so it can persist
/// across every top-level screen, not just one Activity/route.
class TahfeezMiniPlayerShell extends StatelessWidget {
  const TahfeezMiniPlayerShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.isPlaying,
    required this.onPlayPause,
    this.progress,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  /// 0.0-1.0 playback progress, shown as a thin bar along the top edge.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: TahfeezElevation.high,
      borderRadius: BorderRadius.circular(TahfeezSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              LinearProgressIndicator(value: progress, minHeight: 2),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TahfeezSpacing.md,
                vertical: TahfeezSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(TahfeezSpacing.sm),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: TahfeezSpacing.smPlus),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                    iconSize: TahfeezIconSize.xl,
                    color: scheme.primary,
                    onPressed: onPlayPause,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
