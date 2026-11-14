import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';

/// The next recitation's start on a word with a colour of its own (owner,
/// 2026-11-14): the word keeps its colour, the band drawn around it too.
void main() {
  for (final (name, colour) in [
    ('red (a mistake)', Color(0xFFE53935)),
    ('orange (skipped)', Color(0xFFFB8C00)),
    ('green (said right)', Color(0xFF43A047)),
  ]) {
    testWidgets('$name: its colour, and the blue band around it', (
      tester,
    ) async {
      const blue = Color(0x552F80ED);
      await tester.pumpWidget(
        MaterialApp(
          home: AyahWordView(
            text: 'أَحَدٌ',
            meaning: null,
            hidden: false,
            style: (color: colour, ink: true),
            band: blue,
            colors: MushafAppearance.light.colors,
            fontFamily: 'Scheherazade New',
            fade: false,
          ),
        ),
      );
      expect(tester.widget<Text>(find.byType(Text)).style?.color, colour);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == blue,
        ),
        findsOne,
      );
    });
  }
}
