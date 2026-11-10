import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';

/// A page loading shows its lines as soft bars — as many as fit the box,
/// never overflowing a short one.
void main() {
  Future<void> pump(WidgetTester tester, double height) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: height,
            child: const TahfeezPageSkeleton(),
          ),
        ),
      ),
    ),
  );

  testWidgets('a full page: its 15 lines', (tester) async {
    await pump(tester, 700);
    expect(find.byType(TahfeezSkeletonBar), findsNWidgets(15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short box: fewer lines, no overflow', (tester) async {
    await pump(tester, 200);
    final bars = find.byType(TahfeezSkeletonBar).evaluate().length;
    expect(bars, inInclusiveRange(1, 6));
    expect(tester.takeException(), isNull);
  });
}
