import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/tajweed_palette.dart';
import 'package:tahfeez_ai/quran/domain/models/tajweed_models.dart';

/// Tajweed colours over a recitation's mark: the word in the mark's colour
/// (green: said right), its tajweed letters in their own.
void main() {
  testWidgets('a word marked right: green, its qalqala letter still teal', (
    tester,
  ) async {
    const green = Color(0xFF43A047);
    await tester.pumpWidget(
      MaterialApp(
        home: AyahWordView(
          text: 'أَحَدٌ',
          meaning: null,
          hidden: false,
          style: (color: green, ink: true),
          colors: MushafAppearance.light.colors,
          fontFamily: 'Scheherazade New',
          fade: false,
          tajweed: const [TajweedSpan(4, 6, TajweedGroup.qalqala)],
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.color, green);
    final runs = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(runs.map((r) => r.text), ['أَحَ', 'دٌ']);
    expect(runs.first.style?.color, isNull, reason: 'the word\'s green');
    expect(
      runs.last.style?.color,
      tajweedColor(TajweedGroup.qalqala, dark: false),
    );
  });
}
