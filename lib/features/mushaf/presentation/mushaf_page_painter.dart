import 'package:flutter/rendering.dart';

import 'mushaf_page_render_model.dart';

/// Paints one already-shaped [MushafPageRenderModel] — one [CustomPainter]
/// for the entire page, not a separate render object per line or per word.
/// Every line's [TextPainter] was already shaped once when the render
/// model was built (`mushaf_page_render_model.dart`); this only draws
/// them at their precomputed offsets and never re-shapes anything, so it's
/// cheap to invoke on every frame a scroll/animation requires.
class MushafPagePainter extends CustomPainter {
  MushafPagePainter(this.renderModel);

  final MushafPageRenderModel renderModel;

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in renderModel.lines) {
      switch (line) {
        case MushafQuranTextLineRenderModel(
          :final painter,
          :final strokePainter,
          :final paintOffset,
        ):
          // Stroke-behind-fill (see `mushafQuranTextStrokeWidth`'s doc
          // comment): painted first, at the identical offset, so the
          // normal filled glyphs land directly on top of it.
          strokePainter?.paint(canvas, paintOffset);
          painter?.paint(canvas, paintOffset);
        case MushafBismillahLineRenderModel(:final painter, :final paintOffset):
          if (painter != null && paintOffset != null) {
            painter.paint(canvas, paintOffset);
          }
        case MushafSurahHeaderLineRenderModel(
          :final painter,
          :final paintOffset,
          :final inkColor,
          :final framePainter,
          :final frameOffset,
          :final namePainter,
          :final nameOffset,
        ):
          if (framePainter != null && frameOffset != null) {
            // The active mechanism: quran_common.ttf's frame, then
            // suracon.ttf's name overlaid on top — both already tinted at
            // shape time (neither font is a color font), so no
            // saveLayer/ColorFilter is needed here at all.
            framePainter.paint(canvas, frameOffset);
            if (namePainter != null && nameOffset != null) {
              namePainter.paint(canvas, nameOffset);
            }
          } else if (painter != null && paintOffset != null) {
            // Unused development resource: the QUL color glyph.
            if (inkColor != null) {
              _paintMonochrome(canvas, painter, paintOffset, inkColor);
            } else {
              painter.paint(canvas, paintOffset);
            }
          }
      }
    }
  }

  /// Replaces [painter]'s own painted colors (a COLR/CPAL color glyph's
  /// embedded palette) with a single flat [inkColor], preserving every
  /// glyph layer, frame detail, and antialiased edge — never re-coloring
  /// the font data itself, only how this one paint call's *output* is
  /// tinted. `BlendMode.srcIn` keeps the glyph's own alpha (its shape) and
  /// replaces every visible pixel's color with [inkColor] — the Canvas
  /// -level equivalent of wrapping a `Text` widget in
  /// `ColorFiltered(colorFilter: ColorFilter.mode(inkColor, BlendMode.srcIn))`,
  /// necessary here because this line is painted directly onto a
  /// [CustomPainter]'s canvas, never through a widget tree.
  ///
  /// `saveLayer` allocates an offscreen buffer — real, non-free work — but
  /// this only runs inside `paint()`, which a `RepaintBoundary`-wrapped,
  /// `willChange: false` `CustomPaint` (`MushafPageView`) does not
  /// re-invoke on every scroll/composite frame for an otherwise-unchanged
  /// page; see `docs/MUSHAF_RENDERING.md` for the caveat that this has only
  /// been reasoned about, not measured with real on-device frame timing.
  void _paintMonochrome(
    Canvas canvas,
    TextPainter painter,
    Offset paintOffset,
    Color inkColor,
  ) {
    final bounds = paintOffset & painter.size;
    canvas.saveLayer(
      bounds,
      Paint()..colorFilter = ColorFilter.mode(inkColor, BlendMode.srcIn),
    );
    painter.paint(canvas, paintOffset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MushafPagePainter oldDelegate) {
    // Identity, not deep equality: `renderModel` comes from a `keepAlive`
    // Riverpod provider that only ever produces a *new* instance when its
    // cache key (page/width/height/font/text) actually changes — the same
    // cached instance is handed back on every unrelated rebuild, so an
    // identity check alone correctly skips repainting for those.
    return !identical(oldDelegate.renderModel, renderModel);
  }

  /// Exposes each Surah-header/Bismillah line's *real, canonical* text as a
  /// screen-reader-visible accessibility node — both are painted directly
  /// onto this canvas as private-use glyphs (decorative artwork, or a
  /// dev-only plain-text fallback), so without this a screen reader would
  /// see nothing there, or the raw private-use codepoint, at all. The
  /// visible glyph itself is never the semantics source of truth: this
  /// always reads the already-localized/canonical
  /// [MushafSurahHeaderLineRenderModel.semanticLabel] /
  /// [MushafBismillahLineRenderModel.semanticLabel], regardless of which
  /// rendering mechanism produced the visible glyph.
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final result = <CustomPainterSemantics>[];
    for (final line in renderModel.lines) {
      switch (line) {
        case MushafSurahHeaderLineRenderModel(:final semanticLabel?):
          final rect = switch (line) {
            MushafSurahHeaderLineRenderModel(
              :final frameOffset?,
              :final framePainter?,
            ) =>
              frameOffset & framePainter.size,
            MushafSurahHeaderLineRenderModel(
              :final paintOffset?,
              :final painter?,
            ) =>
              paintOffset & painter.size,
            _ => null,
          };
          if (rect == null) continue;
          result.add(
            CustomPainterSemantics(
              rect: rect,
              properties: SemanticsProperties(
                label: semanticLabel,
                textDirection: TextDirection.rtl,
                readOnly: true,
              ),
            ),
          );
        case MushafBismillahLineRenderModel(
          :final semanticLabel?,
          :final paintOffset?,
          :final painter?,
        ):
          result.add(
            CustomPainterSemantics(
              rect: paintOffset & painter.size,
              properties: SemanticsProperties(
                label: semanticLabel,
                textDirection: TextDirection.rtl,
                readOnly: true,
              ),
            ),
          );
        default:
          break;
      }
    }
    return result;
  };

  @override
  bool shouldRebuildSemantics(covariant MushafPagePainter oldDelegate) =>
      !identical(oldDelegate.renderModel, renderModel);
}
