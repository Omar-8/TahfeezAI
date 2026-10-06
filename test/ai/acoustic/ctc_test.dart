import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/ctc.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

import 'acoustic_test_support.dart';

void main() {
  final r = phoneticClassOf('ر');
  final b = phoneticClassOf('ب');
  final fatha = ShortVowel.fatha.token;
  final kasra = ShortVowel.kasra.token;

  test('forced alignment finds each token\'s frames', () {
    final tokens = [r, fatha, b, b, kasra]; // رَبِّ
    final a = ctcForcedAlign(clearFrames(tokens), tokens);
    expect(a.spans, [
      (start: 1, end: 2),
      (start: 4, end: 5),
      (start: 7, end: 8),
      (start: 10, end: 11),
      (start: 13, end: 14),
    ]);
    expect(a.score, closeTo(0, 1e-6));
  });

  test('an optional token not heard is skipped', () {
    final heard = [r, fatha, b];
    final expected = [r, fatha, b, kasra];
    final a = ctcForcedAlign(
      clearFrames(heard),
      expected,
      optional: [false, false, false, true],
    );
    expect(a.spans.last, isNull);
    expect(a.score, closeTo(0, 1e-6));
  });

  test('the CTC probability prefers what was said', () {
    final frames = clearFrames([r, fatha, b, b, kasra]);
    final right = ctcLogProbability(frames, [r, fatha, b, b, kasra]);
    final wrongVowel = ctcLogProbability(frames, [
      r,
      fatha,
      b,
      b,
      ShortVowel.damma.token,
    ]);
    final noShadda = ctcLogProbability(frames, [r, fatha, b, kasra]);
    expect(right, greaterThan(-1));
    expect(wrongVowel, lessThan(right - 10));
    expect(noShadda, lessThan(right - 10));
  });
}
