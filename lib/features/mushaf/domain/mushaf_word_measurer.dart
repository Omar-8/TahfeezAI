/// Measures the rendered width of a word's text at a given font size, for
/// [MushafPageLayoutEngine]'s line-fitting math.
///
/// An abstraction — rather than the layout engine depending on Flutter's
/// `TextPainter` directly — so the engine stays pure Dart and genuinely
/// unit-testable with a fake, deterministic measurer (no widget pump, no
/// real font shaping needed to verify the scaling/justification math
/// itself). The real implementation
/// (`lib/features/mushaf/presentation/text_painter_word_measurer.dart`)
/// wraps `TextPainter`.
abstract class MushafWordMeasurer {
  /// [fontFamily] should be the exact font the text will actually be
  /// painted with (`null` falls back to the platform default) — for a
  /// page-specific-glyph Mushaf, measuring with the wrong font can shift
  /// justification/spacing math away from what the real glyphs occupy,
  /// even though it never changes which words belong to which line.
  double measure(String text, double fontSize, {String? fontFamily});
}
