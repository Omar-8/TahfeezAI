import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/mushaf_page_layout_engine.dart';
import 'font_mushaf_line_renderer.dart';
import 'mushaf_line_renderer.dart';
import 'text_painter_word_measurer.dart';

part 'mushaf_layout_providers.g.dart';

/// The active [MushafLineRenderer]. Always [FontMushafLineRenderer] today —
/// this is the one seam Milestone 7B's optional glyph-atlas renderer would
/// override, per [MushafLineRenderer]'s own doc comment.
@riverpod
MushafLineRenderer mushafLineRenderer(Ref ref) =>
    const FontMushafLineRenderer();

/// The [MushafPageLayoutEngine] instance every Mushaf page in the app lays
/// out with, backed by the real [TextPainterWordMeasurer].
///
/// Lives in `presentation/`, not `application/`: the engine itself
/// (`lib/features/mushaf/domain/mushaf_page_layout_engine.dart`) is pure
/// Dart, but the concrete measurer it needs wraps Flutter's `TextPainter`
/// — a rendering concern — so wiring the two together belongs on the
/// presentation side of the `domain → application → presentation`
/// dependency direction (`docs/ARCHITECTURE.md` §1), not the other way
/// around.
///
/// A plain (non-async) provider: layout itself is a pure, fast, in-memory
/// computation, not something that needs its result cached by Riverpod —
/// the widget that actually renders a page calls `layoutPage`/`layoutLine`
/// directly once it knows the available width (a widget-tree concern this
/// provider doesn't need to know about).
@riverpod
MushafPageLayoutEngine mushafPageLayoutEngine(Ref ref) {
  return const MushafPageLayoutEngine(measurer: TextPainterWordMeasurer());
}
