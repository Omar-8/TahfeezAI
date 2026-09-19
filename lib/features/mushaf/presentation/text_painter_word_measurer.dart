import 'package:flutter/material.dart';

import '../domain/mushaf_word_measurer.dart';

/// The real [MushafWordMeasurer]: measures a word's rendered width using
/// Flutter's own [TextPainter], the same mechanism that later paints it
/// (`FontMushafLineRenderer`) — so a placement the layout engine computes
/// is guaranteed to match what actually gets drawn.
class TextPainterWordMeasurer implements MushafWordMeasurer {
  const TextPainterWordMeasurer();

  @override
  double measure(String text, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    return painter.width;
  }
}
