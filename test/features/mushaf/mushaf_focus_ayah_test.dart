import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_focus_ayah.dart';

/// The ayah a Mushaf screen was opened at — or a run of them (a topic's
/// passage), each highlighted.
void main() {
  test('an ayah: it alone; a run: each of its ayahs', () {
    final one = (owner: Object(), ayahId: 18009, lastAyahId: null);
    expect(isFocusedAyah(one, 18009), isTrue);
    expect(isFocusedAyah(one, 18010), isFalse);
    final run = (owner: Object(), ayahId: 18009, lastAyahId: 18026);
    for (var a = 18009; a <= 18026; a++) {
      expect(isFocusedAyah(run, a), isTrue, reason: '$a');
    }
    expect(isFocusedAyah(run, 18008), isFalse);
    expect(isFocusedAyah(run, 18027), isFalse);
    expect(isFocusedAyah(null, 18009), isFalse);
  });

  test('a run tinted the gold of an ayah opened alone (the page engine\'s '
      'highlight band, RGBA 0xd6a3264d)', () {
    expect(openedRunColor, const Color(0x4DD6A326));
  });
}
