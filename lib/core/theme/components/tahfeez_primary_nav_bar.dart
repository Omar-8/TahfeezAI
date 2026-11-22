import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../tahfeez_icon_sizes.dart';
import '../tahfeez_motion.dart';
import 'quran_mark.dart';

/// One destination in [TahfeezPrimaryNavigationBar]/[TahfeezPrimaryNavigationRail].
class TahfeezPrimaryNavItem {
  const TahfeezPrimaryNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.mark = false,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// The bar's centre, made prominent: [QuranMark] (its green circle) in
  /// place of [icon] (owner, 2026-11-20).
  final bool mark;
}

/// The app shell's bottom navigation bar: equal destinations, each an icon
/// over its label, the selected one in the primary colour.
class TahfeezPrimaryNavigationBar extends StatelessWidget {
  const TahfeezPrimaryNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<TahfeezPrimaryNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;

    // Glass: the screen behind it (drawn on beneath the bar by the app
    // shell) blurred, a see-through frost lighter towards its top, a bright
    // hairline along it.
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: _PrimaryNavBarItem(
              item: items[i],
              selected: i == selectedIndex,
              onTap: () => onDestinationSelected(i),
            ),
          ),
      ],
    );
    final markAt = items.indexWhere((item) => item.mark);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // A faint line along its top, the arch round the mark too — seen in
    // every theme (owner, 2026-11-21: the white one vanished on white
    // pages): the text colour, faint.
    final topLine = scheme.onSurface.withValues(alpha: dark ? 0.24 : 0.20);
    // The glass behind, clipped to the bar — less, round the Quran's mark,
    // an arch cut out of it (owner, 2026-11-20): the mark floating in it,
    // rising above the bar. The items over the glass, the bar its old
    // height.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final notch = markAt < 0 || !width.isFinite
            ? null
            : Offset(
                (rtl ? items.length - 1 - markAt : markAt) *
                        width /
                        items.length +
                    width / items.length / 2,
                _markCentreY,
              );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _NotchedBar(notch),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: CustomPaint(
                    foregroundPainter: _NotchedTopLine(notch, topLine),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(
                              scheme.surface,
                              dark
                                  ? Colors.white
                                  : scheme.surfaceContainerLowest,
                              dark ? 0.04 : 0.5,
                            )!.withValues(alpha: dark ? 0.62 : 0.66),
                            Color.lerp(
                              scheme.surface,
                              scheme.surfaceContainer,
                              0.5,
                            )!.withValues(alpha: dark ? 0.78 : 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: SafeArea(
                top: false,
                child: SizedBox(height: 72, child: row),
              ),
            ),
            if (notch != null)
              Positioned(
                left: notch.dx - _markSize / 2,
                top: notch.dy - _markSize / 2,
                child: GestureDetector(
                  onTap: () => onDestinationSelected(markAt),
                  // (Its tab's own semantics name it.)
                  excludeFromSemantics: true,
                  child: QuranMark(
                    size: _markSize,
                    selected: markAt == selectedIndex,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The Quran's mark in the bar: its diameter, its centre's height from the
/// bar's top (over its tab's icon), and the room round it in the arch cut
/// out of the bar.
const _markSize = 44.0;
const _markCentreY = 12.0;
const _notchRadius = _markSize / 2 + QuranMark.trackGap + 4;

/// The bar, an arch cut out of its top round the mark at [notch] (Material's
/// notched bar's smooth notch).
class _NotchedBar extends CustomClipper<Path> {
  const _NotchedBar(this.notch);

  final Offset? notch;

  @override
  Path getClip(Size size) {
    final bar = Offset.zero & size;
    final notch = this.notch;
    if (notch == null) return Path()..addRect(bar);
    return const CircularNotchedRectangle().getOuterPath(
      bar,
      Rect.fromCircle(center: notch, radius: _notchRadius),
    );
  }

  @override
  bool shouldReclip(_NotchedBar old) => old.notch != notch;
}

/// The bar's bright top line, following the arch.
class _NotchedTopLine extends CustomPainter {
  const _NotchedTopLine(this.notch, this.colour);

  final Offset? notch;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final notch = this.notch;
    if (notch == null) {
      canvas.drawLine(const Offset(0, 0.5), Offset(size.width, 0.5), paint);
      return;
    }
    // The outline's top only: not its sides or bottom.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(1, -1, size.width - 1, notch.dy + _notchRadius + 1),
    );
    canvas.drawPath(
      _NotchedBar(notch).getClip(size).shift(const Offset(0, 0.5)),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NotchedTopLine old) =>
      old.notch != notch || old.colour != colour;
}

class _PrimaryNavBarItem extends StatelessWidget {
  const _PrimaryNavBarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TahfeezPrimaryNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    // Switches on the finger lifting over the item (it barely moved): the
    // tap recognizer alone dropped quick taps made just after a switch,
    // while the new tab was being built. The InkWell gives the ripple.
    return _LiftTap(
      onTap: onTap,
      child: InkWell(
        onTap: () {},
        // (Screen readers tap through _LiftTap's own semantics.)
        excludeFromSemantics: true,
        // No ripple across the whole item: the selected tab's pill shows it.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        // The bar keeps its height at any text size: labels grow up to 1.3×,
        // stay on one line, and the item scales down if that still doesn't
        // fit (very large text, long Arabic labels).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: TahfeezSpacing.xs,
            children: [
              // The selected one on a small glass pill.
              AnimatedContainer(
                duration: TahfeezMotionDuration.medium,
                padding: const EdgeInsets.symmetric(
                  horizontal: TahfeezSpacing.md,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: selected && !item.mark
                      ? scheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  border: Border.all(
                    color: selected && !item.mark
                        ? scheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
                  ),
                ),
                // The Quran's: its icon's room kept (its mark drawn by the
                // bar, floating in an arch cut out of it).
                child: item.mark
                    ? const SizedBox.square(dimension: TahfeezIconSize.lg)
                    : Icon(icon, size: TahfeezIconSize.lg, color: color),
              ),
              Text(
                item.label,
                maxLines: 1,
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.3),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tablet/desktop counterpart of [TahfeezPrimaryNavigationBar]: a side
/// [NavigationRail]-shaped column of the same destinations.
class TahfeezPrimaryNavigationRail extends StatelessWidget {
  const TahfeezPrimaryNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<TahfeezPrimaryNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: 96,
          // Centred; scrolling when taller than the screen (a phone on its
          // side, large text).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: TahfeezSpacing.lg,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _PrimaryNavRailItem(
                        item: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onDestinationSelected(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryNavRailItem extends StatelessWidget {
  const _PrimaryNavRailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TahfeezPrimaryNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    // Switches on the finger lifting over the item (it barely moved): the
    // tap recognizer alone dropped quick taps made just after a switch,
    // while the new tab was being built. The InkWell gives the ripple.
    return _LiftTap(
      onTap: onTap,
      child: InkWell(
        onTap: () {},
        // (Screen readers tap through _LiftTap's own semantics.)
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(TahfeezSpacing.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: TahfeezSpacing.xs,
            children: [
              if (item.mark)
                QuranMark(size: _markSize, selected: selected)
              else
                Icon(
                  icon,
                  size: TahfeezIconSize.lg,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              // As the bar's: one line, up to 1.3× the text size, scaled
              // down to the rail's width if still too wide.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.3),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calls [onTap] when a pointer that went down on [child] lifts within a
/// few pixels of where it went down — no gesture arena involved.
class _LiftTap extends StatefulWidget {
  const _LiftTap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_LiftTap> createState() => _LiftTapState();
}

class _LiftTapState extends State<_LiftTap> {
  Offset? _down;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    onTap: widget.onTap,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _down = e.position,
      onPointerCancel: (_) => _down = null,
      onPointerUp: (e) {
        final down = _down;
        _down = null;
        if (down != null && (e.position - down).distance < kTouchSlop) {
          widget.onTap();
        }
      },
      child: widget.child,
    ),
  );
}
