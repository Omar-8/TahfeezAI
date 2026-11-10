// A surah card's progress: in the accent whatever the share (half memorized
// is progress, not a warning), and grown to a new value, not jumped to.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';

void main() {
  Widget card(double progress) => MaterialApp(
    home: Scaffold(
      body: TahfeezQuranSectionCard(
        number: 2,
        title: 'Al-Baqara',
        subtitle: '286',
        progress: progress,
        onTap: () {},
      ),
    ),
  );

  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget(find.byType(LinearProgressIndicator));

  testWidgets('half memorized: in the accent, shown at once', (tester) async {
    await tester.pumpWidget(card(0.5));
    final context = tester.element(find.byType(LinearProgressIndicator));
    expect(bar(tester).value, 0.5, reason: 'no growth from empty when shown');
    expect(bar(tester).color, Theme.of(context).colorScheme.primary);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('an ayah memorized meanwhile: the bar grows to it', (
    tester,
  ) async {
    await tester.pumpWidget(card(0.2));
    await tester.pumpWidget(card(0.6));
    await tester.pump(const Duration(milliseconds: 120));
    expect(bar(tester).value, inExclusiveRange(0.2, 0.6));
    await tester.pumpAndSettle();
    expect(bar(tester).value, 0.6);
    expect(find.text('60%'), findsOneWidget);
  });
}
