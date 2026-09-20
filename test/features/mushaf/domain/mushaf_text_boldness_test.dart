import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_text_boldness.dart';

void main() {
  test('Light resolves to a stroke width of 0.25', () {
    expect(strokeWidthForMushafBoldness(MushafTextBoldness.light), 0.25);
  });

  test('Medium resolves to a stroke width of 0.30', () {
    expect(strokeWidthForMushafBoldness(MushafTextBoldness.medium), 0.30);
  });

  test('Bold resolves to a stroke width of 0.40', () {
    expect(strokeWidthForMushafBoldness(MushafTextBoldness.bold), 0.40);
  });

  test('labels describe visual strength, never a FontWeight/numeric value', () {
    expect(MushafTextBoldness.light.label, 'Light');
    expect(MushafTextBoldness.medium.label, 'Medium');
    expect(MushafTextBoldness.bold.label, 'Bold');
  });
}
