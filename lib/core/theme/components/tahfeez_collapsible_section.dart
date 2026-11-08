import 'package:flutter/material.dart';

import '../app_spacing.dart';
import 'tahfeez_section_header.dart';

/// A section that opens and closes: its header (as [TahfeezSectionHeader],
/// with a chevron) tapped shows or hides [child] below it — the section as
/// it always looks, opened. [open] (a search matching it) keeps it open.
class TahfeezCollapsibleSection extends StatefulWidget {
  const TahfeezCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.open = false,
    this.initiallyExpanded = false,
    this.spacing = TahfeezSpacing.xs,
  });

  final String title;
  final IconData? icon;
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
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                children: [
                  Expanded(
                    child: TahfeezSectionHeader(
                      title: widget.title,
                      icon: widget.icon,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
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
          duration: const Duration(milliseconds: 200),
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
