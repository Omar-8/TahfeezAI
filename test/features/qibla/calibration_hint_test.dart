import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/qibla/presentation/calibration_hint.dart';

/// The compass's calibration hint: a phone going round a figure 8 without
/// a stop while shown (owner, 2026-11-20) — in tests, rounds with a breath
/// between (screens with it settle); still with animations off.
void main() {
  Widget host({bool still = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: const Scaffold(body: CalibrationHint(text: 'Move in an 8')),
    ),
  );

  /// Where on the 8 the phone is (0–1).
  double where(WidgetTester tester) {
    final builder = tester.widget<AnimatedBuilder>(
      find.descendant(
        of: find.byKey(const ValueKey('qibla-calibration')),
        matching: find.byType(AnimatedBuilder),
      ),
    );
    return (builder.listenable as Animation<double>).value;
  }

  testWidgets('in tests: round and round the 8, resting a moment between', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump(CalibrationHint.round * 0.25);
    expect(where(tester), closeTo(0.25, 0.02), reason: 'on its way');
    // The round over: at rest — nothing to draw, the screen settles.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    // …then round again, and again.
    for (var i = 0; i < 3; i++) {
      await tester.pump(CalibrationHint.rest);
      await tester.pump(CalibrationHint.round * 0.5);
      expect(where(tester), closeTo(0.5, 0.02), reason: 'round ${i + 2}');
      await tester.pumpAndSettle();
    }
    // Gone: no timer left behind (the test would fail on one).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('in the app: round and round, never stopping', (tester) async {
    CalibrationHint.endless = true;
    addTearDown(() => CalibrationHint.endless = false);
    await tester.pumpWidget(host());
    for (var i = 0; i < 20; i++) {
      await tester.pump(CalibrationHint.round * 0.25);
      expect(where(tester), closeTo((i + 1) * 0.25 % 1, 0.02), reason: '$i');
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'moving');
    }
    // Left: it stops with the screen.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('animations off: still, on the path', (tester) async {
    await tester.pumpWidget(host(still: true));
    expect(where(tester), 0.125);
    await tester.pump(CalibrationHint.round * 3);
    expect(where(tester), 0.125);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
