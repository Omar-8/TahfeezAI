import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';

/// One action in a [TahfeezVerseActionBar].
class TahfeezVerseAction {
  const TahfeezVerseAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Whether this action represents an already-active state (e.g. the
  /// bookmark icon for an already-bookmarked verse) — tinted with the
  /// primary color instead of the neutral default.
  final bool isActive;
}

/// The compact icon row shown per-verse in the reader
/// (`docs/reference/04_READER_SPEC.md` §5: verse options, play, tafsir,
/// bookmark). Presentational/generic — the Reader milestone (6) supplies
/// the real actions and a verse-serial badge; this component only owns the
/// shared icon-row layout and styling.
class TahfeezVerseActionBar extends StatelessWidget {
  const TahfeezVerseActionBar({
    super.key,
    required this.actions,
    this.trailing,
  });

  final List<TahfeezVerseAction> actions;

  /// E.g. a verse-serial badge, right-aligned.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            spacing: TahfeezSpacing.sm,
            children: [
              for (final action in actions)
                Tooltip(
                  message: action.tooltip,
                  child: IconButton(
                    icon: Icon(action.icon),
                    iconSize: TahfeezIconSize.lg,
                    color: action.isActive
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    onPressed: action.onPressed,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
