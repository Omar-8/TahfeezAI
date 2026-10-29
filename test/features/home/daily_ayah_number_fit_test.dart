// The daily ayah's number never left alone on a line when shrinking the
// ayah a little (to 85%) keeps it on the last one. The test font's glyphs
// (spaces too) are as wide as the font is large, so the widths are exact.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/home/presentation/sections/home_daily_ayah_section.dart';

void main() {
  TextStyle styleAt(double size) => TextStyle(fontSize: size, height: 2);
  double fit(String text, double width) => fitNumberOnLastLine(
    text: text,
    styleAt: styleAt,
    size: 32,
    width: width,
    textScaler: TextScaler.noScaling,
  );

  testWidgets('room for the number at the end: the size unchanged', (
    tester,
  ) async {
    expect(fit('aaaa', 320), 32);
  });

  testWidgets('the number alone on a new line: the ayah a little smaller, '
      'so it ends the last line', (tester) async {
    // 9 letters + a space (320) leave no room for the 30.4 star at 32.
    final size = fit('aaaaaaaaa', 320);
    expect(size, lessThan(32));
    expect(size, greaterThanOrEqualTo(32 * 0.85));
    // Ten glyphs and the star in 320.
    expect(10 * size + size * 0.95, lessThanOrEqualTo(320));
  });

  testWidgets('too far to fit at 85%: the size unchanged (the number on its '
      'own line, as before)', (tester) async {
    // 9 letters fill 290 at 32; the star needs the ayah at 26.5 (< 85%).
    expect(fit('aaaaaaaaa', 290), 32);
  });

  testWidgets('a number already on a line with words: unchanged', (
    tester,
  ) async {
    // Two lines either way: the star joins the second line's words.
    expect(fit('aaaaaaaaaa aaa', 320), 32);
  });
}
