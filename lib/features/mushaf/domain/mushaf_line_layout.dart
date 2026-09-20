import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../quran/domain/models/mushaf_models.dart';

part 'mushaf_line_layout.freezed.dart';

/// One physical line's computed justification: a font size plus a single
/// per-gap inter-word spacing value, both shared by every token on the
/// line — never individual per-token positions.
///
/// This is deliberately *not* a list of per-token placements (an earlier
/// design this replaced): computing one placement per token required
/// measuring every token individually, which is real, non-trivial cost
/// (font shaping, not arithmetic) that scaled with word count — a page
/// with 100+ words did 100+ measurements just to decide justification, and
/// the real renderer then re-measured every word again to actually paint
/// it. [MushafPageLayoutEngine] now measures each line's tokens as one (or
/// two — see `_pureGlyphWidth`'s doc comment) concatenated strings to
/// reach the same font size and spacing decision — the renderer
/// (`lib/features/mushaf/presentation/mushaf_page_render_model.dart`) then
/// shapes that same concatenated line exactly once with the real page
/// font and recovers each token's own on-screen rectangle from that one
/// shaped paragraph via `TextPainter.getBoxesForSelection` — never by
/// computing positions by hand. [lineWidth] is that shaped line's own
/// resulting width, always `<=` the `availableWidth`
/// [MushafPageLayoutEngine.layoutLine] was given.
@freezed
abstract class MushafLineLayout with _$MushafLineLayout {
  const factory MushafLineLayout({
    required int lineNumber,
    required MushafLineType lineType,
    required bool isCentered,
    int? surahNo,
    required double fontSize,
    required double lineWidth,

    /// The full visual gap that should appear between each pair of
    /// adjacent tokens — **not** directly a `TextStyle.wordSpacing` value.
    /// `wordSpacing` adds *on top of* however wide the font renders a
    /// bare separator character, rather than replacing it, so the
    /// renderer (`mushaf_page_render_model.dart`) must subtract that
    /// separator's own measured width from this before passing it to
    /// `TextStyle.wordSpacing` — never this value directly. `0` for a
    /// centered or single-token line, which is never stretched to fill
    /// [lineWidth]'s available width.
    required double spacing,

    /// How many tokens this line has — the renderer needs this to know
    /// how many gaps [spacing] applies to (`tokenCount - 1`) without
    /// re-deriving it from the token list itself.
    required int tokenCount,
  }) = _MushafLineLayout;
}

/// One page's computed layout: every line, in printed order.
@freezed
abstract class MushafPageLayout with _$MushafPageLayout {
  const factory MushafPageLayout({
    required int pageNumber,
    required List<MushafLineLayout> lines,
  }) = _MushafPageLayout;
}
