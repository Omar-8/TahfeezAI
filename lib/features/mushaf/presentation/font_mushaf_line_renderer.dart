import 'package:flutter/material.dart';

import '../domain/mushaf_line_layout.dart';
import 'mushaf_line_renderer.dart';

/// The font-based [MushafLineRenderer] this milestone ships: paints each
/// word's [MushafWordPlacement] as its own positioned [TextPainter] call
/// inside one [CustomPainter], rather than any wrapping [Text]/[RichText]
/// widget — the concrete form of this milestone's "do not render a page by
/// placing all Quran text into one wrapping widget" requirement, and what
/// makes "prevent accidental wrap" true by construction (each word is
/// placed at an explicit, pre-computed position; nothing here can ever
/// reflow across lines).
class FontMushafLineRenderer extends MushafLineRenderer {
  const FontMushafLineRenderer();

  @override
  Widget buildLine(
    BuildContext context, {
    required MushafLineLayout layout,
    required double availableWidth,
    required double lineHeight,
    required Color textColor,
    String? fontFamily,
    ValueChanged<MushafWordPlacement>? onWordTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: onWordTap == null
          ? null
          : (details) {
              final placement = _placementAt(
                layout,
                availableWidth,
                details.localPosition.dx,
              );
              if (placement != null) onWordTap(placement);
            },
      child: SizedBox(
        width: availableWidth,
        height: lineHeight,
        child: CustomPaint(
          painter: _MushafLinePainter(
            layout: layout,
            availableWidth: availableWidth,
            color: textColor,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }

  MushafWordPlacement? _placementAt(
    MushafLineLayout layout,
    double availableWidth,
    double tapX,
  ) {
    final boxLeft = (availableWidth - layout.lineWidth) / 2;
    for (final placement in layout.placements) {
      final screenX =
          boxLeft + (layout.lineWidth - placement.x - placement.width);
      if (tapX >= screenX && tapX <= screenX + placement.width) {
        return placement;
      }
    }
    return null;
  }
}

class _MushafLinePainter extends CustomPainter {
  _MushafLinePainter({
    required this.layout,
    required this.availableWidth,
    required this.color,
    required this.fontFamily,
  });

  final MushafLineLayout layout;
  final double availableWidth;
  final Color color;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.placements.isEmpty) return;

    // Each word's placement.x is a reading-order offset from the line's
    // own leading edge; since Arabic reads right-to-left, the leading
    // edge is the box's right side. The box itself is horizontally
    // centered within `availableWidth` (a no-op for a fully-justified
    // line, where lineWidth ≈ availableWidth).
    final boxLeft = (availableWidth - layout.lineWidth) / 2;

    for (final placement in layout.placements) {
      final painter = TextPainter(
        text: TextSpan(
          text: placement.text,
          style: TextStyle(
            fontSize: layout.fontSize,
            color: color,
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();

      final screenX =
          boxLeft + (layout.lineWidth - placement.x - placement.width);
      final dy = (size.height - painter.height) / 2;
      painter.paint(canvas, Offset(screenX, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _MushafLinePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.availableWidth != availableWidth ||
        oldDelegate.color != color ||
        oldDelegate.fontFamily != fontFamily;
  }
}
