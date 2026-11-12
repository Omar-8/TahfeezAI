import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/components/components.dart';

/// A page loading shows its lines of words with ayah ends here and there,
/// justified right to left — as many lines as fit the box, never
/// overflowing a short one; the same arrangement for the same page.
void main() {
  Future<void> pump(WidgetTester tester, double height, {int seed = 0}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: height,
                child: TahfeezPageSkeleton(seed: seed),
              ),
            ),
          ),
        ),
      );

  TahfeezMushafSkeletonPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<TahfeezMushafSkeletonPainter>()
      .single;

  testWidgets('a full page: its 15 lines', (tester) async {
    await pump(tester, 700);
    expect(painter(tester).lines, 15);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short box: fewer lines, no overflow', (tester) async {
    await pump(tester, 200);
    expect(painter(tester).lines, inInclusiveRange(1, 6));
    expect(tester.takeException(), isNull);
  });

  test('every line is words filling the width, with ayah ends between', () {
    const p = TahfeezMushafSkeletonPainter(
      lines: 15,
      color: Colors.black,
      seed: 2,
    );
    const w = 320.0, t = 12.0;
    final rows = p.layout(w, t);
    expect(rows, hasLength(15));
    var ends = 0;
    for (final row in rows) {
      expect(row.length, greaterThanOrEqualTo(2));
      expect(row.first.$2, isFalse, reason: 'a line starts with a word');
      final natural =
          row.fold(0.0, (s, i) => s + i.$1) +
          (row.length - 1) * t * TahfeezMushafSkeletonPainter.gapFactor;
      expect(natural, lessThanOrEqualTo(w));
      // Close enough to full that justifying doesn't open wide gaps.
      expect(natural, greaterThan(w - t * 5.2));
      for (var i = 1; i < row.length; i++) {
        expect(row[i].$2 && row[i - 1].$2, isFalse, reason: 'no two ends');
      }
      ends += row.where((i) => i.$2).length;
    }
    expect(ends, inInclusiveRange(3, 20), reason: 'ayah ends now and then');
  });

  test('the same page, the same arrangement; another page, another', () {
    List<List<(double, bool)>> of(int seed) => TahfeezMushafSkeletonPainter(
      lines: 15,
      color: Colors.black,
      seed: seed,
    ).layout(320, 12);
    expect(of(5), of(5));
    expect(of(5), isNot(of(6)));
  });

  test('a box too narrow for two words: one word, fitted', () {
    const p = TahfeezMushafSkeletonPainter(lines: 3, color: Colors.black);
    for (final row in p.layout(10, 12)) {
      expect(row.fold(0.0, (s, i) => s + i.$1), lessThanOrEqualTo(10));
    }
  });
}
