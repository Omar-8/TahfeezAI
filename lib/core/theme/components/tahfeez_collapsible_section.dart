import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';
import 'tahfeez_section_header.dart';
import '../tahfeez_motion.dart';

/// A section that opens and closes: its header (as [TahfeezSectionHeader],
/// with a chevron) tapped shows or hides [child] below it — the section as
/// it always looks, opened. [open] (a search matching it) keeps it open.
class TahfeezCollapsibleSection extends StatefulWidget {
  const TahfeezCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.summary,
    this.open = false,
    this.initiallyExpanded = false,
    this.spacing = TahfeezSpacing.xs,
  });

  final String title;
  final IconData? icon;

  /// Closed, under the title: what is chosen inside (a theme's name, the
  /// reciter…), so it is known without opening the section.
  final String? summary;
  final Widget child;
  final bool open;

  /// Opened at first (closed by a tap on its header).
  final bool initiallyExpanded;

  /// Between the header and [child], opened.
  final double spacing;

  @override
  State<TahfeezCollapsibleSection> createState() =>
      _TahfeezCollapsibleSectionState();
}

class _TahfeezCollapsibleSectionState extends State<TahfeezCollapsibleSection> {
  late var _expanded =
      PageStorage.maybeOf(context)?.readState(context) as bool? ??
      widget.initiallyExpanded;

  void _toggle() {
    setState(() => _expanded = !_expanded);
    // Kept as it was when scrolled away and back.
    PageStorage.maybeOf(context)?.writeState(context, _expanded);
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded || widget.open;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            borderRadius: BorderRadius.circular(TahfeezRadii.sm),
            onTap: widget.open ? null : _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TahfeezSectionHeader(
                          title: widget.title,
                          icon: widget.icon,
                        ),
                        if (widget.summary case final summary?
                            when summary.isNotEmpty)
                          AnimatedSize(
                            duration: TahfeezMotionDuration.medium,
                            alignment: AlignmentDirectional.topStart,
                            child: expanded
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    // Under the title, past the icon.
                                    padding: EdgeInsetsDirectional.only(
                                      start: widget.icon == null
                                          ? 0
                                          : TahfeezIconSize.lg +
                                                TahfeezSpacing.sm,
                                      bottom: TahfeezSpacing.xs,
                                    ),
                                    child: Text(
                                      summary,
                                      key: ValueKey(
                                        'section-summary-${widget.title}',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: TahfeezMotionDuration.medium,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: TahfeezMotionDuration.medium,
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: expanded
              ? Padding(
                  padding: EdgeInsets.only(top: widget.spacing),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
