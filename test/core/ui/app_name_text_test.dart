import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_colors.dart';
import 'package:tahfeez_ai/core/ui/app_name_text.dart';

/// The name's "AI" in the brand's green: the accent in light, the mint in
/// dark — the rest of the name as its style says.
void main() {
  for (final (brightness, green) in [
    (Brightness.light, TahfeezExplorationPalette.lightPrimaryAccent),
    (Brightness.dark, TahfeezExplorationPalette.darkPrimary),
  ]) {
    for (final name in ['TahfeezAI', 'تحفيظ AI']) {
      testWidgets('${brightness.name}, $name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(body: AppNameText(name)),
          ),
        );
        expect(find.text(name), findsOneWidget);
        final text = tester.widget<Text>(find.byType(Text));
        final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
        final ai = spans.firstWhere((s) => s.text == 'AI');
        expect(ai.style?.color, green);
        expect(spans.where((s) => s.text != 'AI').map((s) => s.style), [
          null,
          null,
        ]);
      });
    }
  }
}
