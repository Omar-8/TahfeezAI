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
  double measure(String text, double fontSize);
}
