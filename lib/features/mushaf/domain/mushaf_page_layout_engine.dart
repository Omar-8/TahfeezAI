import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import 'mushaf_line_layout.dart';
import 'mushaf_word_measurer.dart';

/// UI-independent layout engine for one printed Mushaf page.
///
/// For each [MushafLine], resolves its exact words, measures them, and
/// computes a font size plus inter-word spacing so the line reads at a
/// classical-Mushaf-style justified width (or, for a centered line, a
/// scaled-but-not-stretched width) — never by wrapping a paragraph, per
/// this milestone's explicit "do not render a page by placing all Quran
/// text into one wrapping widget" requirement. Every line is placed as an
/// explicit sequence of individually-positioned words instead.
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
  /// [tokensByLineNumber] must already contain each line's exact token
  /// sequence (e.g. from batch-loading a whole page's tokens via
  /// `QuranRepository.getPageTokens` and slicing per line — see
  /// `lib/features/mushaf/application/mushaf_page_providers.dart`); this
  /// engine does no data loading of its own.
  MushafPageLayout layoutPage({
    required int pageNumber,
    required List<MushafLine> lines,
    required Map<int, List<MushafToken>> tokensByLineNumber,
    required double availableWidth,
  }) {
    final laidOutLines = [
      for (final line in lines)
        layoutLine(
          line: line,
          tokens: tokensByLineNumber[line.lineNumber] ?? const [],
          availableWidth: availableWidth,
        ),
    ];
    return MushafPageLayout(pageNumber: pageNumber, lines: laidOutLines);
  }

  /// Lays out one line. Deterministic: the same [line]/[tokens]/
  /// [availableWidth] always produce the same [MushafLineLayout].
  MushafLineLayout layoutLine({
    required MushafLine line,
    required List<MushafToken> tokens,
    required double availableWidth,
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
        fontSize: baseFontSize,
        lineWidth: 0,
        placements: const [],
      );
    }

    double naturalWidthAt(double fontSize) {
      var total = 0.0;
      for (final token in tokens) {
        total += measurer.measure(token.displayText, fontSize);
      }
      total += baseInterWordSpacing * (tokens.length - 1);
      return total;
    }

    final naturalWidth = naturalWidthAt(baseFontSize);
    var scale = naturalWidth <= 0 ? 1.0 : availableWidth / naturalWidth;
    scale = scale.clamp(minScale, maxScale);
    final fontSize = baseFontSize * scale;

    final tokenWidths = [
      for (final token in tokens) measurer.measure(token.displayText, fontSize),
    ];
    final totalTokenWidth = tokenWidths.fold<double>(0, (a, b) => a + b);

    double spacing;
    if (tokens.length > 1 && !line.isCentered) {
      // Justify: distribute the remaining space as inter-token gaps,
      // clamped so a very short line doesn't stretch into absurd gaps.
      final remaining = availableWidth - totalTokenWidth;
      final rawSpacing = remaining / (tokens.length - 1);
      spacing = rawSpacing.clamp(0.0, baseInterWordSpacing * scale * 3);
    } else {
      spacing = tokens.length > 1 ? baseInterWordSpacing * scale : 0;
    }

    var lineWidth = totalTokenWidth + spacing * (tokens.length - 1);
    // Prevent clipping: in the rare case scaling still leaves the line
    // wider than available (e.g. a single very long token at minScale),
    // drop the extra spacing rather than let it overflow further.
    if (lineWidth > availableWidth && tokens.length > 1) {
      spacing = 0;
      lineWidth = totalTokenWidth;
    }

    final placements = <MushafWordPlacement>[];
    var cursor = 0.0;
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final width = tokenWidths[i];
      placements.add(
        MushafWordPlacement(
          sourceTokenId: token.sourceTokenId,
          tokenType: token.tokenType,
          canonicalAyahId: token.canonicalAyahId,
          canonicalWordIndex: token.canonicalWordIndex,
          text: token.displayText,
          x: cursor,
          width: width,
        ),
      );
      cursor += width + spacing;
    }

    return MushafLineLayout(
      lineNumber: line.lineNumber,
      lineType: line.lineType,
      isCentered: line.isCentered,
      surahNo: line.surahNo,
      fontSize: fontSize,
      lineWidth: lineWidth,
      placements: placements,
    );
  }
}
