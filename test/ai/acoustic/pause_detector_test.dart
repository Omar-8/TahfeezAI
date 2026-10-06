import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/pause_detector.dart';

Float32List _tone(int ms, double amp) => Float32List.fromList([
  for (var i = 0; i < 16 * ms; i++) amp * math.sin(i * 0.2),
]);

void main() {
  test('fires once when speech is followed by a pause', () {
    final d = PauseDetector();
    expect(d.add(_tone(400, 0.001)), isFalse);
    expect(d.add(_tone(600, 0.2)), isFalse);
    expect(d.add(_tone(200, 0.001)), isFalse);
    expect(d.add(_tone(200, 0.001)), isTrue);
    expect(d.add(_tone(1000, 0.001)), isFalse);
  });

  test('a short gap inside speech is not a pause', () {
    final d = PauseDetector();
    expect(d.add(_tone(600, 0.2)), isFalse);
    expect(d.add(_tone(160, 0.001)), isFalse);
    expect(d.add(_tone(600, 0.2)), isFalse);
  });

  test('a click is not speech', () {
    final d = PauseDetector();
    expect(d.add(_tone(60, 0.3)), isFalse);
    expect(d.add(_tone(800, 0.001)), isFalse);
  });
}
