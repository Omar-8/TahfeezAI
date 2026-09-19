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

  /// Builds one line's visual content at [availableWidth] × [lineHeight],
  /// rendered using [fontFamily]. [onWordTap], when given, is called with
  /// the tapped word's placement — the seam word-by-word taps (Milestone
  /// 8), playback highlighting (Milestone 12), and memorization overlays
  /// (Milestone 17) all need.
  ///
  /// `null` [fontFamily] means "no page-specific font" (a
  /// `MushafRenderingType.unicodeText` Mushaf, which has none by
  /// definition) — falls back to the platform default. For a
  /// `MushafRenderingType.pageSpecificGlyphFont` Mushaf, a page's Quran
  /// glyph text is only meaningful when drawn with that exact page's own
  /// font (`docs/QURAN_DATA_PROVENANCE.md` §8 — the same codepoint draws a
  /// different glyph on a different page), so the caller
  /// (`lib/features/mushaf/presentation/mushaf_page_view.dart`) must
  /// confirm that font is loaded via `QpcPageFontManager.ensureLoaded`
  /// and pass its real family — never call this with `null` for a
  /// glyph-font Mushaf, and never with a fallback/previous-page font.
  Widget buildLine(
    BuildContext context, {
    required MushafLineLayout layout,
    required double availableWidth,
    required double lineHeight,
    required Color textColor,
    String? fontFamily,
    ValueChanged<MushafWordPlacement>? onWordTap,
  });
}
