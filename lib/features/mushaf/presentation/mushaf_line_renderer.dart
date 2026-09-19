import 'package:flutter/widgets.dart';

import '../domain/mushaf_line_layout.dart';

/// The replaceable rendering boundary between a computed
/// [MushafLineLayout] and pixels on screen.
///
/// This milestone ships exactly one implementation
/// (`FontMushafLineRenderer`, live font shaping via `TextPainter`).
/// Milestone 7B's optional glyph-atlas renderer is meant to be a second
/// implementation of this same interface — swappable behind
/// `mushafLineRendererProvider`
/// (`lib/features/mushaf/presentation/mushaf_layout_providers.dart`)
/// without any change to `MushafPageView` or the layout engine, per this
/// milestone's explicit "define a replaceable interface for a future
/// glyph-atlas renderer without implementing it now" requirement.
abstract class MushafLineRenderer {
  const MushafLineRenderer();

  /// Builds one line's visual content at [availableWidth] × [lineHeight].
  /// [onWordTap], when given, is called with the tapped word's placement —
  /// the seam word-by-word taps (Milestone 8), playback highlighting
  /// (Milestone 12), and memorization overlays (Milestone 17) all need.
  Widget buildLine(
    BuildContext context, {
    required MushafLineLayout layout,
    required double availableWidth,
    required double lineHeight,
    required Color textColor,
    ValueChanged<MushafWordPlacement>? onWordTap,
  });
}
