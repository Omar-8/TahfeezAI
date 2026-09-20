import 'package:flutter/rendering.dart';

import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../quran/domain/models/surah_header_glyph_models.dart';
import '../application/mushaf_page_providers.dart';
import '../domain/mushaf_line_layout.dart';
import '../domain/mushaf_page_layout_engine.dart';

/// One real Quran word's on-screen hit rectangle, recovered from the
/// line's single shaped [TextPainter] via
/// [TextPainter.getBoxesForSelection] — never computed by hand. [rect] is
/// in the owning [MushafPageRenderModel]'s own coordinate space (i.e. the
/// page's [CustomPainter] canvas), not the line's.
class MushafTokenHitRect {
  const MushafTokenHitRect({
    required this.rect,
    required this.sourceTokenId,
    required this.tokenType,
    required this.canonicalAyahId,
    required this.canonicalWordIndex,
    required this.text,
  });

  final Rect rect;
  final int sourceTokenId;
  final MushafTokenType tokenType;
  final int? canonicalAyahId;
  final int? canonicalWordIndex;
  final String text;
}

/// One printed line's fully-shaped render output — the unit the page's one
/// [CustomPainter] paints and hit-tests against. `sealed` because the
/// three [MushafLineType]s render through genuinely different mechanisms
/// (see each subclass), never all through the ordinary Quran-word path.
sealed class MushafLineRenderModel {
  const MushafLineRenderModel({
    required this.lineNumber,
    required this.top,
    required this.height,
  });

  final int lineNumber;

  /// This line's top edge, in the page's own coordinate space.
  final double top;

  /// This line's allotted vertical slot.
  final double height;
}

/// An ordinary printed Quran-text line: every token shaped together, once,
/// as a single paragraph in the page's own QCF font — see
/// `mushaf_page_render_model.dart`'s top-level `buildMushafPageRenderModel`
/// for how [painter] and [tokenRects] are produced.
final class MushafQuranTextLineRenderModel extends MushafLineRenderModel {
  const MushafQuranTextLineRenderModel({
    required super.lineNumber,
    required super.top,
    required super.height,
    required this.painter,
    required this.paintOffset,
    required this.tokenRects,
    this.strokePainter,
  });

  /// The line's entire token sequence, shaped as one paragraph. `null`
  /// only when the line legitimately has no tokens to shape (shouldn't
  /// happen for a real `quranText` line, but guards against malformed
  /// data rather than throwing).
  final TextPainter? painter;

  /// The optional stroke-behind-fill pass (see
  /// `buildMushafPageRenderModel`'s `quranTextStrokeWidth` parameter),
  /// shaped identically to [painter] — same text/font/fontSize/wordSpacing,
  /// only the `Paint` differs — and painted at the same [paintOffset]
  /// immediately before it. `null` whenever the stroke pass is disabled
  /// (`quranTextStrokeWidth <= 0`).
  final TextPainter? strokePainter;

  /// Where to paint [painter] (and [strokePainter], when present) within
  /// the page's canvas.
  final Offset paintOffset;

  final List<MushafTokenHitRect> tokenRects;
}

/// The decorative line marking where a chapter's Bismillah belongs —
/// rendered through its own mechanism, never the ordinary Quran-word path
/// (see `mushaf_bismillah_renderer.dart`'s doc comment for why: QUL's data
/// has no glyph/word range for this line at all, on any page).
final class MushafBismillahLineRenderModel extends MushafLineRenderModel {
  const MushafBismillahLineRenderModel({
    required super.lineNumber,
    required super.top,
    required super.height,
    this.painter,
    this.paintOffset,
    this.isDecorative = false,
    this.semanticLabel,
  });

  /// `null` before either the decorative glyph's font or (for the
  /// fallback) the canonical Bismillah text (sourced from Al-Fatiha's own
  /// ayah 1) has loaded.
  final TextPainter? painter;
  final Offset? paintOffset;

  /// `true` when [painter] draws the real `quran_common.ttf` U+FDFD glyph
  /// (`docs/QURAN_DATA_PROVENANCE.md` §13), `false` for the plain-text
  /// fallback shown while that font isn't bundled — a dev-only, clearly
  /// non-final state.
  final bool isDecorative;

  /// The real canonical Bismillah text ("بِسْمِ اللَّهِ الرَّحْمَٰنِ
  /// الرَّحِيمِ", sourced from Al-Fatiha's own ayah 1 — never a fresh
  /// literal), always carried as a real accessibility node
  /// (`MushafPagePainter.semanticsBuilder`) regardless of [isDecorative] —
  /// the private-use glyph this line paints is visual only and must never
  /// itself be exposed to a screen reader.
  final String? semanticLabel;
}

/// The chapter-name heading line — rendered through its own mechanism,
/// never the ordinary Quran-word path.
final class MushafSurahHeaderLineRenderModel extends MushafLineRenderModel {
  const MushafSurahHeaderLineRenderModel({
    required super.lineNumber,
    required super.top,
    required super.height,
    this.painter,
    this.paintOffset,
    this.surahNo,
    this.semanticLabel,
    this.isDecorative = false,
    this.inkColor,
    this.achievedWidthFraction,
    this.framePainter,
    this.frameOffset,
    this.namePainter,
    this.nameOffset,
  });

  /// The QUL COLR full-artwork glyph (`docs/QURAN_DATA_PROVENANCE.md` §10)
  /// — kept as an unused development resource, no longer produced by the
  /// active render-model builder (superseded by [framePainter]/
  /// [namePainter] below), but the field/mechanism stays intact so that
  /// path remains testable rather than deleted outright.
  final TextPainter? painter;
  final Offset? paintOffset;
  final int? surahNo;

  /// The single color the QUL glyph above was tinted to at paint time —
  /// same "unused development resource" status as [painter].
  final Color? inkColor;

  /// The fraction of the line's available width the QUL glyph actually
  /// occupied — same "unused development resource" status as [painter].
  final double? achievedWidthFraction;

  /// The QuranApp-style decorative title frame (`quran_common.ttf`,
  /// U+E000) — the active mechanism. Already tinted at shape time (this
  /// font is not a color font, so no `saveLayer`/`ColorFilter` is needed —
  /// see `MushafPagePainter`'s doc comment). `null` when that font isn't
  /// bundled, in which case the whole line falls back to plain text via
  /// [painter] instead.
  final TextPainter? framePainter;
  final Offset? frameOffset;

  /// The QuranApp-style calligraphic Surah name + prefix glyph
  /// (`suracon.ttf`), painted on top of [framePainter] — see
  /// `_buildQuranAppSurahHeaderLine`'s doc comment for the exact
  /// composition. `null` exactly when [framePainter] is `null`.
  final TextPainter? namePainter;
  final Offset? nameOffset;

  /// The localized chapter name — carried alongside the painted glyph(s)
  /// specifically so this can be exposed as an accessibility label
  /// without any visible private-use glyph ever being the semantic source
  /// of truth. Set for every case: the active QuranApp-style decoration,
  /// the unused QUL path, and the plain-text fallback alike.
  final String? semanticLabel;

  /// `true` when this line paints through either decorative mechanism
  /// ([framePainter]/[namePainter] — the active one — or, in principle,
  /// [painter] — the unused QUL one), `false` for the plain-text fallback
  /// shown while no decorative font is bundled at all.
  final bool isDecorative;
}

/// One page's fully-shaped, ready-to-paint render output — the unit
/// [mushafPageRenderModelProvider] caches. Painting this never re-shapes
/// anything; it only draws [lines]' already-shaped painters at their
/// already-computed offsets.
class MushafPageRenderModel {
  const MushafPageRenderModel({
    required this.pageNumber,
    required this.lines,
    required this.size,
  });

  final int pageNumber;
  final List<MushafLineRenderModel> lines;

  /// The full page content area this was shaped for — the [CustomPainter]
  /// this feeds should be given exactly this size.
  final Size size;
}

/// Builds a page's complete [MushafPageRenderModel]: resolves the page's
/// justification decisions once via [engine] (line-level measurement, not
/// per-token — see [MushafPageLayoutEngine]'s doc comment), then shapes
/// each line's real [TextPainter] exactly once and recovers per-token hit
/// rectangles from it. This is the entire cost of preparing a page for
/// paint; nothing here happens again per frame or per unrelated rebuild —
/// see `mushaf_layout_providers.dart`'s `mushafPageRenderModelProvider`,
/// which caches the result this function returns.
MushafPageRenderModel buildMushafPageRenderModel({
  required MushafPageLayoutEngine engine,
  required MushafPageBundle bundle,
  required double availableWidth,
  required double availableHeight,
  required String? fontFamily,
  required Color textColor,
  required Color headerInkColor,
  required String? bismillahText,

  /// Resolves a Surah number to its localized display name — called once
  /// per `surahHeader` line on the page (a transition page can have more
  /// than one), never hard-coded into this builder.
  required String? Function(int surahNo) surahHeaderNameResolver,

  /// `quran_common.ttf`'s verified family name — the active mechanism for
  /// both the Bismillah glyph (U+FDFD) and the Surah-header title frame
  /// (U+E000). `null` when that font isn't bundled
  /// (`SHIP_BLOCKED_LICENSE`, see `docs/QURAN_DATA_PROVENANCE.md` §12/§13),
  /// in which case both lines fall back to plain text, never a fabricated
  /// substitute glyph.
  String? quranCommonFontFamily,

  /// Resolves a Surah number to its verified `suracon.ttf` calligraphic
  /// name glyph (already concatenated with the shared prefix glyph, in the
  /// same order QuranApp's own reference composition uses — name then
  /// prefix), or `null` when that font isn't bundled — in which case the
  /// header falls back to plain localized text.
  String? Function(int surahNo)? suraconInputTextResolver,
  String? suraconFontFamily,

  /// Resolves a Surah number to its verified QUL Surah Header decorative
  /// glyph — kept only as an unused development resource
  /// (`docs/QURAN_DATA_PROVENANCE.md` §10): no longer supplied by the
  /// active provider chain (`mushaf_layout_providers.dart`), but the
  /// mechanism itself stays intact and testable rather than deleted.
  SurahHeaderGlyphEntry? Function(int surahNo)? surahHeaderGlyphResolver,

  /// The Quran-glyph stroke-behind-fill optical-emboldening width (logical
  /// px) — see `MushafTextBoldness`/`strokeWidthForMushafBoldness`
  /// (`lib/features/mushaf/domain/mushaf_text_boldness.dart`) for the
  /// user-facing Light/Medium/Bold preference this comes from. `<= 0`
  /// disables it entirely, reproducing the QCF page font's own original,
  /// unmodified `FontWeight.w400` rendering with zero visual difference.
  /// Never a `FontWeight` value: an earlier `FontWeight.w600` attempt
  /// proved visually inconsistent across a real page's full diacritic/mark
  /// density (small marks didn't gain weight proportionally with base
  /// letterforms, reading as muddy/uneven) — see `_buildQuranTextLine`'s
  /// own doc comment for the paint-only mechanism this uses instead, which
  /// never touches `fontWeight`, the font file, or
  /// [MushafPageLayoutEngine]/[TextPainterWordMeasurer]'s layout math.
  double quranTextStrokeWidth = 0.0,
}) {
  final pageLayout = engine.layoutPage(
    pageNumber: bundle.pageNumber,
    lines: bundle.lines,
    tokensByLineNumber: bundle.tokensByLineNumber,
    availableWidth: availableWidth,
    availableHeight: availableHeight,
    fontFamily: fontFamily,
  );

  final lineHeight = pageLayout.lines.isEmpty
      ? 0.0
      : availableHeight / pageLayout.lines.length;

  final lineModels = <MushafLineRenderModel>[];
  for (var i = 0; i < pageLayout.lines.length; i++) {
    final lineLayout = pageLayout.lines[i];
    final top = i * lineHeight;
    final tokens = bundle.tokensByLineNumber[lineLayout.lineNumber] ?? const [];

    lineModels.add(switch (lineLayout.lineType) {
      MushafLineType.quranText => _buildQuranTextLine(
        lineLayout,
        tokens,
        availableWidth,
        lineHeight,
        top,
        fontFamily,
        textColor,
        quranTextStrokeWidth,
      ),
      MushafLineType.bismillah => _buildBismillahLine(
        lineLayout,
        availableWidth,
        lineHeight,
        top,
        textColor,
        bismillahText,
        quranCommonFontFamily,
      ),
      MushafLineType.surahHeader => _buildSurahHeaderLine(
        lineLayout,
        availableWidth,
        lineHeight,
        top,
        textColor,
        headerInkColor,
        lineLayout.surahNo == null
            ? null
            : surahHeaderNameResolver(lineLayout.surahNo!),
        quranCommonFontFamily,
        lineLayout.surahNo == null
            ? null
            : suraconInputTextResolver?.call(lineLayout.surahNo!),
        suraconFontFamily,
        lineLayout.surahNo == null
            ? null
            : surahHeaderGlyphResolver?.call(lineLayout.surahNo!),
      ),
    });
  }

  return MushafPageRenderModel(
    pageNumber: bundle.pageNumber,
    lines: lineModels,
    size: Size(availableWidth, availableHeight),
  );
}

MushafQuranTextLineRenderModel _buildQuranTextLine(
  MushafLineLayout lineLayout,
  List<MushafToken> tokens,
  double availableWidth,
  double lineHeight,
  double top,
  String? fontFamily,
  Color textColor,
  double strokeWidth,
) {
  if (tokens.isEmpty) {
    return MushafQuranTextLineRenderModel(
      lineNumber: lineLayout.lineNumber,
      top: top,
      height: lineHeight,
      painter: null,
      paintOffset: Offset.zero,
      tokenRects: const [],
    );
  }

  // The exact same string+separator `MushafPageLayoutEngine` measured
  // (`joinMushafLineText`), with each token's own character range tracked
  // so its on-screen rectangle can be recovered after shaping.
  final buffer = StringBuffer();
  final ranges = <(int start, int end)>[];
  for (var i = 0; i < tokens.length; i++) {
    final start = buffer.length;
    buffer.write(tokens[i].displayText);
    ranges.add((start, buffer.length));
    if (i < tokens.length - 1) buffer.write(mushafLineTokenSeparator);
  }
  final lineText = buffer.toString();

  // [foreground] is the *only* thing allowed to differ between the fill
  // pass and the optional stroke-behind-fill pass (see
  // `buildMushafPageRenderModel`'s `quranTextStrokeWidth` parameter) —
  // passing the same [wordSpacing] to both calls guarantees byte-identical
  // shaping (font/fontSize/text/spacing),
  // so the stroke can never drift out of alignment with the fill it sits
  // beneath, or influence the justification/layout math in any way (both
  // passes are shaped *after* `MushafPageLayoutEngine` already decided
  // [lineLayout.spacing] — neither one feeds back into it).
  TextPainter shape(double wordSpacing, {Paint? foreground}) => TextPainter(
    text: TextSpan(
      text: lineText,
      style: TextStyle(
        fontSize: lineLayout.fontSize,
        color: foreground == null ? textColor : null,
        foreground: foreground,
        fontFamily: fontFamily,
        wordSpacing: wordSpacing,
      ),
    ),
    textDirection: TextDirection.rtl,
    // No `maxWidth` constraint: this line can structurally never wrap —
    // wrapping is only possible when a paragraph is laid out within a
    // width it doesn't fit, and this is deliberately laid out unconstrained
    // (`double.infinity`), so it fills exactly however wide the shaped
    // text plus spacing makes it, never reflowing onto another visual row.
  )..layout();

  // `TextStyle.wordSpacing` adds *on top of* however wide this font
  // renders a bare separator character, rather than replacing it — so to
  // make the *total* gap between tokens equal `lineLayout.spacing` (what
  // the engine actually decided), the natural separator width has to be
  // subtracted out first. Skipping this would silently double-count
  // whatever gap the font's own bare space glyph already contributes.
  final separatorWidth = tokens.length > 1
      ? (TextPainter(
          text: TextSpan(
            text: mushafLineTokenSeparator,
            style: TextStyle(
              fontSize: lineLayout.fontSize,
              fontFamily: fontFamily,
            ),
          ),
          textDirection: TextDirection.rtl,
        )..layout()).width
      : 0.0;
  // Never negative: a real page font's bare space glyph is a thin sliver
  // (confirmed against the actual QCF page fonts — a few percent of the
  // font size), so this essentially never engages in production. It
  // exists because Skia does not reliably honor a *negative* wordSpacing
  // large enough to fully cancel out an unusually wide separator glyph
  // (a real risk only for a degenerate font whose bare space renders far
  // wider than normal, e.g. a placeholder/test font that draws every
  // glyph, space included, as a full glyph-width box) — rather than
  // depend on that undocumented, unreliable behavior, this simply accepts
  // the font's own natural separator width as a floor in that case.
  final wordSpacingToApply = (lineLayout.spacing - separatorWidth).clamp(
    0.0,
    double.infinity,
  );

  var appliedWordSpacing = wordSpacingToApply;
  var painter = shape(appliedWordSpacing);
  // The engine's own natural-width estimate already guards against
  // overflow from its side, but the *real* shaped width is authoritative —
  // if it still exceeds the available width (font hinting/rounding), fall
  // back to natural (unstretched) spacing rather than let the line clip.
  if (painter.width > availableWidth + 0.5 && lineLayout.spacing > 0) {
    appliedWordSpacing = 0;
    painter = shape(appliedWordSpacing);
  }

  // Stroke-behind-fill: shaped from the exact [appliedWordSpacing] the
  // fill pass ended up using (including the overflow fallback above, if it
  // triggered), so the two passes' glyphs land at identical positions —
  // see [buildMushafPageRenderModel]'s `quranTextStrokeWidth` doc comment.
  final strokePainter = strokeWidth <= 0
      ? null
      : shape(
          appliedWordSpacing,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = textColor,
        );

  final boxLeft = (availableWidth - painter.width) / 2;
  final dy = top + (lineHeight - painter.height) / 2;
  final paintOffset = Offset(boxLeft, dy);

  final tokenRects = <MushafTokenHitRect>[];
  for (var i = 0; i < tokens.length; i++) {
    final (start, end) = ranges[i];
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) continue;
    var rect = Rect.fromLTRB(
      boxes.first.left,
      boxes.first.top,
      boxes.first.right,
      boxes.first.bottom,
    );
    for (final box in boxes.skip(1)) {
      rect = rect.expandToInclude(
        Rect.fromLTRB(box.left, box.top, box.right, box.bottom),
      );
    }
    tokenRects.add(
      MushafTokenHitRect(
        rect: rect.shift(paintOffset),
        sourceTokenId: tokens[i].sourceTokenId,
        tokenType: tokens[i].tokenType,
        canonicalAyahId: tokens[i].canonicalAyahId,
        canonicalWordIndex: tokens[i].canonicalWordIndex,
        text: tokens[i].displayText,
      ),
    );
  }

  return MushafQuranTextLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    painter: painter,
    strokePainter: strokePainter,
    paintOffset: paintOffset,
    tokenRects: tokenRects,
  );
}

/// QuranApp's own Bismillah reference size (36sp) against this project's
/// `MushafPageLayoutEngine.baseFontSize` (28) — kept as a ratio, not a
/// fixed logical-pixel value, so the decorative Bismillah scales with
/// [MushafLineLayout.fontSize] (the page's own real, already-calibrated
/// font scale) rather than a hard-coded size that ignores it.
const _bismillahReferenceRatio = 36 / 28;

MushafBismillahLineRenderModel _buildBismillahLine(
  MushafLineLayout lineLayout,
  double availableWidth,
  double lineHeight,
  double top,
  Color textColor,
  String? bismillahText,
  String? quranCommonFontFamily,
) {
  if (bismillahText == null) {
    return MushafBismillahLineRenderModel(
      lineNumber: lineLayout.lineNumber,
      top: top,
      height: lineHeight,
    );
  }

  if (quranCommonFontFamily != null) {
    return _buildDecorativeBismillahLine(
      lineLayout,
      availableWidth,
      lineHeight,
      top,
      textColor,
      quranCommonFontFamily,
      bismillahText,
    );
  }

  // Dev-only fallback while quran_common.ttf isn't bundled
  // (SHIP_BLOCKED_LICENSE, docs/QURAN_DATA_PROVENANCE.md §13) — the real
  // canonical text in a plain system font, never a guessed QCF2BSML glyph
  // mapping (see §11) and never silently treated as production-equivalent.
  final painter = TextPainter(
    text: TextSpan(
      text: bismillahText,
      style: TextStyle(fontSize: lineLayout.fontSize, color: textColor),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final offset = Offset(
    (availableWidth - painter.width) / 2,
    top + (lineHeight - painter.height) / 2,
  );
  return MushafBismillahLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    painter: painter,
    paintOffset: offset,
    semanticLabel: bismillahText,
  );
}

/// Renders the real, verified `quran_common.ttf` U+FDFD glyph — QuranApp's
/// own decorative Bismillah, reimplemented independently (never a ported
/// Kotlin/Compose `Bismillah.kt`): centered, sized relative to the page's
/// own calibrated font scale (never a hard-coded 36 logical pixels), and
/// never exceeding the authoritative `basmallah` line's own box — no extra
/// line height is ever added, and surrounding lines never move, since this
/// only ever shrinks to fit within [lineHeight]/[availableWidth], never
/// grows the line itself. Already tinted at shape time via `TextStyle`:
/// `quran_common.ttf` is an ordinary (non-color) outline font, confirmed by
/// its own table directory lacking `COLR`/`CPAL` — no
/// `saveLayer`/`ColorFilter` is needed the way the QUL color font required.
MushafBismillahLineRenderModel _buildDecorativeBismillahLine(
  MushafLineLayout lineLayout,
  double availableWidth,
  double lineHeight,
  double top,
  Color inkColor,
  String quranCommonFontFamily,
  String semanticLabel,
) {
  TextPainter shapeAt(double fontSize) => TextPainter(
    text: TextSpan(
      text: '﷽',
      style: TextStyle(
        fontFamily: quranCommonFontFamily,
        fontSize: fontSize,
        color: inkColor,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();

  var fontSize = lineLayout.fontSize * _bismillahReferenceRatio;
  var painter = shapeAt(fontSize);
  if (painter.width > 0 &&
      painter.height > 0 &&
      (painter.width > availableWidth || painter.height > lineHeight)) {
    final scale =
        (availableWidth / painter.width) < (lineHeight / painter.height)
        ? availableWidth / painter.width
        : lineHeight / painter.height;
    fontSize *= scale;
    painter = shapeAt(fontSize);
  }

  final offset = Offset(
    (availableWidth - painter.width) / 2,
    top + (lineHeight - painter.height) / 2,
  );
  return MushafBismillahLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    painter: painter,
    paintOffset: offset,
    isDecorative: true,
    semanticLabel: semanticLabel,
  );
}

MushafSurahHeaderLineRenderModel _buildSurahHeaderLine(
  MushafLineLayout lineLayout,
  double availableWidth,
  double lineHeight,
  double top,
  Color textColor,
  Color headerInkColor,
  String? surahHeaderName,
  String? quranCommonFontFamily,
  String? suraconInputText,
  String? suraconFontFamily,
  SurahHeaderGlyphEntry? glyphEntry,
) {
  if (surahHeaderName == null) {
    return MushafSurahHeaderLineRenderModel(
      lineNumber: lineLayout.lineNumber,
      top: top,
      height: lineHeight,
      surahNo: lineLayout.surahNo,
    );
  }

  // The active mechanism: QuranApp-style frame + calligraphic name.
  if (quranCommonFontFamily != null &&
      suraconInputText != null &&
      suraconFontFamily != null) {
    return _buildQuranAppSurahHeaderLine(
      lineLayout,
      availableWidth,
      lineHeight,
      top,
      surahHeaderName,
      quranCommonFontFamily,
      headerInkColor,
      suraconInputText,
      suraconFontFamily,
      textColor,
    );
  }

  // Unused development resource (docs/QURAN_DATA_PROVENANCE.md §10): the
  // QUL COLR full-artwork glyph, never supplied by the active provider
  // chain any more, but kept functional rather than deleted.
  if (glyphEntry != null) {
    return _buildDecorativeSurahHeaderLine(
      lineLayout,
      availableWidth,
      lineHeight,
      top,
      surahHeaderName,
      glyphEntry,
      headerInkColor,
    );
  }

  // Dev-only fallback while neither decorative font is bundled
  // (SHIP_BLOCKED_LICENSE) — a plain, clearly non-decorative localized
  // name, never a fabricated ornamental substitute for the real artwork.
  final painter = TextPainter(
    text: TextSpan(
      text: surahHeaderName,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final offset = Offset(
    (availableWidth - painter.width) / 2,
    top + (lineHeight - painter.height) / 2,
  );
  return MushafSurahHeaderLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    painter: painter,
    paintOffset: offset,
    surahNo: lineLayout.surahNo,
    semanticLabel: surahHeaderName,
  );
}

/// The decorative header's target width, as a fraction of the line's
/// available width — the middle of the requested 94-98% band, leaving a
/// small, even safety margin on both sides so the glyph never touches or
/// crosses the page's own content margins.
const _surahHeaderTargetWidthFraction = 0.96;

/// QuranApp's own reference sizes (`compose/components/reader/
/// ChapterTitle.kt`/`ChapterIcon.kt`, studied for behavior only — never
/// ported line-by-line, per `docs/CLEAN_ROOM_RULES.md`): the title frame
/// at 46sp, the Surah name overlay at 30sp. Kept as *ratios* against this
/// project's `MushafPageLayoutEngine.baseFontSize` (28), so both scale with
/// the page's real, already-calibrated font scale rather than a hard-coded
/// logical-pixel/dp/sp constant.
///
/// QuranApp's own reference shifts the name 8dp down from the frame's
/// center to compensate for *its own* frame artwork's cavity sitting
/// slightly above center — Tahfeez's `quran_common.ttf` frame does not
/// have that same offset cavity, so reproducing that exact 8dp shift here
/// visibly leans the name below true center instead of matching it.
///
/// A shift of exactly 0 isn't quite right either: centering
/// `namePainter`'s *layout box* (font ascent+descent) inside the frame's
/// own box optically leans the name slightly high, because `suracon.ttf`'s
/// diacritic marks sit further above the letter body than the letters'
/// descenders extend below it, so the visible ink sits higher within its
/// own layout box than the box's true center. A small downward nudge
/// (measured against real rendered ink, not assumed) corrects that without
/// reintroducing QuranApp's much larger 8dp-equivalent lean.
const _surahHeaderFrameReferenceRatio = 46 / 28;
const _surahHeaderNameReferenceRatio = 30 / 28;
const _surahHeaderNameVerticalShiftRatio = 0.1;

/// Renders QuranApp's own Surah-header composition, reimplemented
/// independently in Flutter (never a ported Kotlin/Compose `ChapterTitle`/
/// `ChapterIcon`): a decorative title frame (`quran_common.ttf`, U+E000)
/// with the calligraphic Surah name + shared prefix glyph (`suracon.ttf`)
/// layered on top — conceptually the same `Stack { frame; name }`
/// composition, built here from two independently-shaped [TextPainter]s
/// rather than a widget tree, since this line is painted directly onto
/// `MushafPagePainter`'s canvas.
///
/// The frame is uniform-scaled (one factor for both axes, so its aspect
/// ratio is always exactly preserved) to reach [_surahHeaderTargetWidthFraction]
/// of the line's width or the authoritative line height's limit, whichever
/// binds first — exactly the same scale-to-fit approach already verified
/// for the unused QUL mechanism, just applied to a plain glyph instead of a
/// color one. The name glyph is then sized by applying that *same* scale
/// factor to its own reference ratio, keeping the two proportional at any
/// page scale, exactly like QuranApp's fixed 46:30 relationship — never
/// independently sized in a way that could visually drift from the frame.
///
/// Both glyphs are already tinted at shape time via `TextStyle.color`:
/// neither `quran_common.ttf` nor `suracon.ttf` is a color font (confirmed:
/// neither has `COLR`/`CPAL` tables), so no `saveLayer`/`ColorFilter` is
/// needed the way the QUL color font required — a real, measurable
/// performance win, not just a visual preference.
MushafSurahHeaderLineRenderModel _buildQuranAppSurahHeaderLine(
  MushafLineLayout lineLayout,
  double availableWidth,
  double lineHeight,
  double top,
  String surahHeaderName,
  String quranCommonFontFamily,
  Color frameInkColor,
  String suraconInputText,
  String suraconFontFamily,
  Color nameInkColor,
) {
  TextPainter shapeFrame(double fontSize) => TextPainter(
    text: TextSpan(
      text: '',
      style: TextStyle(
        fontFamily: quranCommonFontFamily,
        fontSize: fontSize,
        color: frameInkColor,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();

  final targetWidth = availableWidth * _surahHeaderTargetWidthFraction;
  var frameFontSize = lineLayout.fontSize * _surahHeaderFrameReferenceRatio;
  var framePainter = shapeFrame(frameFontSize);
  if (framePainter.width > 0 && framePainter.height > 0) {
    final scale =
        (targetWidth / framePainter.width) < (lineHeight / framePainter.height)
        ? targetWidth / framePainter.width
        : lineHeight / framePainter.height;
    if ((scale - 1.0).abs() > 0.001) {
      frameFontSize *= scale;
      framePainter = shapeFrame(frameFontSize);
    }
  }
  final achievedWidthFraction = availableWidth > 0
      ? framePainter.width / availableWidth
      : 0.0;
  final frameOffset = Offset(
    (availableWidth - framePainter.width) / 2,
    top + (lineHeight - framePainter.height) / 2,
  );

  final nameFontSize =
      frameFontSize *
      (_surahHeaderNameReferenceRatio / _surahHeaderFrameReferenceRatio);
  final namePainter = TextPainter(
    text: TextSpan(
      text: suraconInputText,
      style: TextStyle(
        fontFamily: suraconFontFamily,
        fontSize: nameFontSize,
        color: nameInkColor,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  final verticalShift = frameFontSize * _surahHeaderNameVerticalShiftRatio;
  final nameOffset = Offset(
    (availableWidth - namePainter.width) / 2,
    frameOffset.dy +
        (framePainter.height - namePainter.height) / 2 +
        verticalShift,
  );

  return MushafSurahHeaderLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    framePainter: framePainter,
    frameOffset: frameOffset,
    namePainter: namePainter,
    nameOffset: nameOffset,
    surahNo: lineLayout.surahNo,
    semanticLabel: surahHeaderName,
    isDecorative: true,
    achievedWidthFraction: achievedWidthFraction,
  );
}

/// Renders the real, verified QUL Surah Header decorative glyph: a single
/// codepoint that already draws the complete frame+name artwork as one
/// unit. Only uniform scaling (never stretching one axis independently)
/// and centering are applied — no custom frame is drawn around it, and its
/// own font-embedded shape is used unmodified; only the *color* it's
/// painted with is replaced, at paint time (`MushafPagePainter`), never by
/// altering the shaped glyph or re-coloring the font data itself.
MushafSurahHeaderLineRenderModel _buildDecorativeSurahHeaderLine(
  MushafLineLayout lineLayout,
  double availableWidth,
  double lineHeight,
  double top,
  String surahHeaderName,
  SurahHeaderGlyphEntry glyphEntry,
  Color inkColor,
) {
  const referenceFontSize = 48.0;
  TextPainter shapeAt(double fontSize) => TextPainter(
    text: TextSpan(
      text: glyphEntry.inputText,
      style: TextStyle(fontFamily: glyphEntry.fontFamily, fontSize: fontSize),
    ),
    textDirection: TextDirection.rtl,
  )..layout();

  final reference = shapeAt(referenceFontSize);
  // scale = min(targetWidth / naturalWidth, availableHeight / naturalHeight)
  // -- uniform (one scale factor for both axes), so the aspect ratio is
  // always exactly preserved. The authoritative `surah_name` line's own
  // height (`lineHeight`) is never grown to accommodate the glyph: if it
  // limits how wide the glyph can get without distortion, the achieved
  // width is honestly whatever that constraint allows, not forced to the
  // target by stretching.
  final targetWidth = availableWidth * _surahHeaderTargetWidthFraction;
  var painter = reference;
  var achievedWidthFraction = 0.0;
  if (reference.width > 0 && reference.height > 0) {
    final scale =
        (targetWidth / reference.width) < (lineHeight / reference.height)
        ? targetWidth / reference.width
        : lineHeight / reference.height;
    if ((scale - 1.0).abs() > 0.01) {
      painter = shapeAt(referenceFontSize * scale);
    }
    achievedWidthFraction = painter.width / availableWidth;
  }

  final offset = Offset(
    (availableWidth - painter.width) / 2,
    top + (lineHeight - painter.height) / 2,
  );
  return MushafSurahHeaderLineRenderModel(
    lineNumber: lineLayout.lineNumber,
    top: top,
    height: lineHeight,
    painter: painter,
    paintOffset: offset,
    surahNo: lineLayout.surahNo,
    semanticLabel: surahHeaderName,
    isDecorative: true,
    inkColor: inkColor,
    achievedWidthFraction: achievedWidthFraction,
  );
}
