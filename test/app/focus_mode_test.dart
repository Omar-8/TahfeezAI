import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/presentation/home_sky.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_zen_mode.dart';

import '../test_helpers/real_app.dart';

void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  testWidgets('focus mode: the Mushaf without its app bar, until left', (
    tester,
  ) async {
    final container = await RealApp.launch(tester, route: '/quran/surah/1');
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mushaf-zen')));
    await RealApp.settle(tester);
    expect(container.read(mushafZenModeProvider), isTrue);
    expect(find.byType(AppBar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('mushaf-zen-exit')));
    await RealApp.settle(tester);
    expect(container.read(mushafZenModeProvider), isFalse);
    expect(find.byType(AppBar), findsOneWidget);
    await RealApp.quit(tester);
  });

  test("Home's sky by the clock", () {
    DayPart at(int h, [int m = 0]) => DayPart.at(DateTime(2026, 10, 25, h, m));
    expect(at(2), DayPart.night);
    expect(at(5), DayPart.dawn);
    expect(at(9), DayPart.morning);
    expect(at(13), DayPart.afternoon);
    expect(at(17), DayPart.golden);
    expect(at(18, 45), DayPart.sunset);
    expect(at(21), DayPart.night);
  });
}
