import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import 'mushaf_line_layout.dart';
import 'mushaf_word_measurer.dart';

/// The separator [MushafPageLayoutEngine] concatenates a line's tokens
/// with before measuring/shaping them as one string — also the separator
/// the real renderer must use when it later builds the same concatenated
/// text to actually shape and paint (see `mushaf_page_render_model.dart`),
/// so its real shaped text matches what this engine measured. A plain
/// space: `TextStyle.wordSpacing` (what the renderer ultimately applies,
/// derived from [MushafLineLayout.spacing] — see that field's doc
/// comment) is defined in terms of the text's own word-boundary spaces.
const mushafLineTokenSeparator = ' ';

/// Joins [tokens]' display text into the one string a whole line is
/// measured/shaped as — never per-token. Exposed so the renderer
/// (`mushaf_page_render_model.dart`) builds the exact same string this
/// engine measured, character-for-character, when it shapes the line for
/// real with the page font.
String joinMushafLineText(List<MushafToken> tokens) =>
    tokens.map((t) => t.displayText).join(mushafLineTokenSeparator);

/// UI-independent layout engine for one printed Mushaf page.
///
/// For each [MushafLine], measures its tokens **as a single concatenated
/// string** (see [joinMushafLineText]) and computes a font size plus a
/// single inter-word spacing value so the line reads at a
/// classical-Mushaf-style justified width (or, for a centered line, a
/// scaled-but-not-stretched width) — never by wrapping a paragraph, per
/// this milestone's explicit "do not render a page by placing all Quran
/// text into one wrapping widget" requirement.
///
/// Deliberately measures at line granularity, not per token: an earlier
/// design measured every token individually (real font shaping, not
/// trivial arithmetic) to reach the same decision, which cost time
/// proportional to word count — a 100-word page did 100+ measurements
/// just to decide justification. Measuring each line's tokens as one
/// (or two — see [_pureGlyphWidth]) strings instead reaches the same
/// decision in time proportional to *line* count instead (~15 per page,
/// not 100+).
///
/// Pure Dart: depends only on [MushafWordMeasurer], not on Flutter, so the
/// scaling/justification math is directly unit-testable with a fake
/// deterministic measurer.
class MushafPageLayoutEngine {
  const MushafPageLayoutEngine({
    required this.measurer,
    this.baseFontSize = 28,
    this.minScale = 0.7,
    this.maxScale = 1.4,
    this.baseInterWordSpacing = 8,
  });

  final MushafWordMeasurer measurer;

  /// The font size a line's words are first measured at, before scaling to
  /// fit — the "natural" size classical Mushaf typesetting targets.
  final double baseFontSize;

  /// Reasonable min/max scaling constraints (per this milestone's explicit
  /// requirement), so an unusually short or long line never renders
  /// illegibly small or implausibly large.
  final double minScale;
  final double maxScale;

  /// The base gap between words at [baseFontSize], scaled along with the
  /// line for centered lines, and otherwise superseded by the justified
  /// spacing computed to fill the line.
  final double baseInterWordSpacing;

  /// Lays out every line of one page.
  ///
  /// Every line is measured and painted at one shared, page-wide
  /// [MushafLineLayout.fontSize] — never a size chosen independently per
  /// line. A real printed Mushaf page's line breaks were hand-typeset so
  /// every line reads at one constant size; scaling font size line-by-line
  /// to fill [availableWidth] (this engine's original design) makes a
  /// page's shortest lines — Al-Fatiha's short ayat, the Mushaf's final
  /// short surahs, any Bismillah-length verse — balloon toward [maxScale]
  /// while denser neighboring lines stay near 1.0, so verses on the same
  /// page visibly render at different sizes. The page-wide size is
  /// calibrated to the page's own *widest* line (the binding constraint:
  /// any smaller and that line would overflow); every other line is then
  /// justified at that same size via inter-word spacing alone, the same
  /// tool classical Mushaf typesetting varies to fill a line — never by
  /// changing letter size.
  ///
  /// [tokensByLineNumber] must already contain each line's exact token
  /// sequence (e.g. from batch-loading a whole page's tokens via
  /// `QuranRepository.getPageTokens` and slicing per line — see
  /// `lib/features/mushaf/application/mushaf_page_providers.dart`); this
  /// engine does no data loading of its own.
  ///
  /// [availableHeight], when given, can only ever *raise* the effective
  /// [maxScale] ceiling for this page, never lower it: if [lines] leaves
  /// more vertical room per line than [maxScale] alone would use, the page
  /// is allowed to grow into that slack rather than sit smaller than the
  /// screen has room for. It never shrinks a page below what [minScale]/
  /// [maxScale] already produce.
  MushafPageLayout layoutPage({
    required int pageNumber,
    required List<MushafLine> lines,
    required Map<int, List<MushafToken>> tokensByLineNumber,
    required double availableWidth,
    String? fontFamily,
    double? availableHeight,
  }) {
    var maxNaturalWidth = 0.0;
    for (final line in lines) {
      final tokens = tokensByLineNumber[line.lineNumber] ?? const [];
      if (tokens.isEmpty) continue;
      final natural = _naturalWidthWithBaseGap(
        tokens,
        baseFontSize,
        fontFamily: fontFamily,
      );
      if (natural > maxNaturalWidth) maxNaturalWidth = natural;
    }

    var effectiveMaxScale = maxScale;
    if (availableHeight != null && lines.isNotEmpty) {
      final lineHeight = availableHeight / lines.length;
      // A reasonable line-height-to-font-size ratio for Arabic text with
      // diacritics (tashkil extends above/below the base letter shapes),
      // avoiding vertical clipping or lines crowding into each other —
      // close to a typical font's own natural line-height metric (~1.2x),
      // not padded further: a more conservative 1.35 left visible unused
      // vertical slack per line once the page footer's space was
      // reclaimed for the text itself.
      const heightToFontSizeRatio = 1.2;
      final maxFontSizeFromHeight = lineHeight / heightToFontSizeRatio;
      final heightScale = maxFontSizeFromHeight / baseFontSize;
      if (heightScale > effectiveMaxScale) effectiveMaxScale = heightScale;
    }

    var pageScale = maxNaturalWidth <= 0
        ? 1.0
        : availableWidth / maxNaturalWidth;
    pageScale = pageScale.clamp(minScale, effectiveMaxScale);
    final pageFontSize = baseFontSize * pageScale;

    final laidOutLines = [
      for (final line in lines)
        layoutLine(
          line: line,
          tokens: tokensByLineNumber[line.lineNumber] ?? const [],
          availableWidth: availableWidth,
          fontFamily: fontFamily,
          fontSize: pageFontSize,
        ),
    ];
    return MushafPageLayout(pageNumber: pageNumber, lines: laidOutLines);
  }

  /// The sum of [tokens]' own glyph widths, with **no** gap between them
  /// at all — not even the separator's own natural width. Measuring the
  /// joined string directly (a single call) would otherwise bake in
  /// however wide *this specific font* happens to render a bare separator
  /// character: normally a thin gap for a real font, but some fonts
  /// (test/placeholder fonts in particular, which can render every glyph
  /// including space as a full glyph-width box) render it far wider,
  /// which would silently inflate this value and push lines toward
  /// [minScale] far more aggressively than intended. This measures the
  /// joined string once, measures a single bare separator once, and
  /// subtracts the latter's contribution out — two measurement calls per
  /// line, never one per token, and the result is exactly what summing
  /// each token's own individually-measured width would give.
  double _pureGlyphWidth(
    List<MushafToken> tokens,
    double fontSize, {
    String? fontFamily,
  }) {
    if (tokens.isEmpty) return 0;
    if (tokens.length == 1) {
      return measurer.measure(
        tokens.single.displayText,
        fontSize,
        fontFamily: fontFamily,
      );
    }
    final joined = measurer.measure(
      joinMushafLineText(tokens),
      fontSize,
      fontFamily: fontFamily,
    );
    final separatorWidth = measurer.measure(
      mushafLineTokenSeparator,
      fontSize,
      fontFamily: fontFamily,
    );
    return joined - separatorWidth * (tokens.length - 1);
  }

  /// [_pureGlyphWidth] plus a small, controlled, font-independent gap
  /// ([baseInterWordSpacing], scaled to [fontSize]) between each pair of
  /// tokens — the reference "how wide would this line read at a
  /// comfortable, un-justified gap" used only to *choose a font size*
  /// (the page-wide calibration scan, and [layoutLine]'s own standalone
  /// scale decision) — never used for the actual inter-token [spacing]
  /// decision, which starts from [_pureGlyphWidth] alone.
  double _naturalWidthWithBaseGap(
    List<MushafToken> tokens,
    double fontSize, {
    String? fontFamily,
  }) {
    if (tokens.isEmpty) return 0;
    final pure = _pureGlyphWidth(tokens, fontSize, fontFamily: fontFamily);
    return pure +
        baseInterWordSpacing * (fontSize / baseFontSize) * (tokens.length - 1);
  }

  /// Lays out one line. Deterministic: the same [line]/[tokens]/
  /// [availableWidth]/[fontFamily]/[fontSize] always produce the same
  /// [MushafLineLayout]. [fontFamily] should be the exact font this line
  /// will be painted with, so the justification math matches real glyph
  /// widths (see [MushafWordMeasurer]'s doc comment).
  ///
  /// [fontSize] is normally supplied by [layoutPage] (the page-wide size
  /// every line on that page shares). Left `null` — as every direct,
  /// single-line caller in this engine's own tests does — this line picks
  /// its own best-fit size exactly as before, scaled independently to fill
  /// [availableWidth]; that standalone behavior is only ever exercised in
  /// isolation, never by [layoutPage] itself.
  MushafLineLayout layoutLine({
    required MushafLine line,
    required List<MushafToken> tokens,
    required double availableWidth,
    String? fontFamily,
    double? fontSize,
  }) {
    if (tokens.isEmpty) {
      // A pure surah-header or Bismillah line carries no ayah words of its
      // own — the renderer overlays the chapter name / Bismillah marker
      // separately (see `docs/reference/05_MUSHAF_SPEC.md` §2).
      return MushafLineLayout(
        lineNumber: line.lineNumber,
        lineType: line.lineType,
        isCentered: line.isCentered,
        surahNo: line.surahNo,
        fontSize: fontSize ?? baseFontSize,
        lineWidth: 0,
        spacing: 0,
        tokenCount: 0,
      );
    }

    double effectiveScale;
    double resolvedFontSize;
    if (fontSize != null) {
      resolvedFontSize = fontSize;
      effectiveScale = fontSize / baseFontSize;
    } else {
      final naturalWidth = _naturalWidthWithBaseGap(
        tokens,
        baseFontSize,
        fontFamily: fontFamily,
      );
      var scale = naturalWidth <= 0 ? 1.0 : availableWidth / naturalWidth;
      scale = scale.clamp(minScale, maxScale);
      effectiveScale = scale;
      resolvedFontSize = baseFontSize * scale;
    }

    // The *actual* gap the renderer will apply is derived from this: the
    // full visual gap that should appear between adjacent tokens (never
    // "extra beyond the separator's own natural width" — the renderer
    // (`mushaf_page_render_model.dart`) is the one that converts this
    // into the `TextStyle.wordSpacing` value that achieves it, by
    // subtracting the separator's own measured width, since Flutter's
    // `wordSpacing` adds *on top of* the separator's natural rendering
    // rather than replacing it).
    final totalTokenWidth = _pureGlyphWidth(
      tokens,
      resolvedFontSize,
      fontFamily: fontFamily,
    );

    double spacing;
    if (tokens.length > 1 && !line.isCentered) {
      // Justify: distribute the remaining space as inter-token gaps. A
      // page-wide font size (the normal, [fontSize]-supplied path) leaves
      // much more residual width for a short line to absorb this way than
      // a per-line-scaled design would, so the bound here is deliberately
      // generous — wide-but-even word spacing on a short verse reads as
      // authentic Mushaf spacing variation, unlike a visibly different
      // letter size would.
      final remaining = availableWidth - totalTokenWidth;
      final rawSpacing = remaining / (tokens.length - 1);
      spacing = rawSpacing.clamp(
        0.0,
        baseInterWordSpacing * effectiveScale * 10,
      );
    } else {
      spacing = tokens.length > 1 ? baseInterWordSpacing * effectiveScale : 0;
    }

    var lineWidth = totalTokenWidth + spacing * (tokens.length - 1);
    // Prevent clipping: in the rare case scaling still leaves the line
    // wider than available (e.g. a single very long token at minScale),
    // drop the extra spacing rather than let it overflow further.
    if (lineWidth > availableWidth && tokens.length > 1) {
      spacing = 0;
      lineWidth = totalTokenWidth;
    }
    // `lineWidth <= availableWidth` is a hard guarantee callers (e.g.
    // centering math computing `(availableWidth - lineWidth) / 2`) rely
    // on — clamped rather than left to a strict `>` comparison above,
    // since measuring a line via two string measurements
    // ([_pureGlyphWidth]) can round a hair differently than summing
    // per-token widths would, occasionally landing a fraction of a pixel
    // over even when the guard above didn't fire.
    lineWidth = lineWidth.clamp(0.0, availableWidth);

    return MushafLineLayout(
      lineNumber: line.lineNumber,
      lineType: line.lineType,
      isCentered: line.isCentered,
      surahNo: line.surahNo,
      fontSize: resolvedFontSize,
      lineWidth: lineWidth,
      spacing: spacing,
      tokenCount: tokens.length,
    );
  }
}
