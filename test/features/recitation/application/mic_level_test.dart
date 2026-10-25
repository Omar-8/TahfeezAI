import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/recitation/application/mic_level.dart';

/// A chunk of a sine of [amplitude] (0..1 of full scale), PCM16LE.
Uint8List _tone(double amplitude, {int samples = 1600}) {
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final v = (amplitude * 32767 * math.sin(2 * math.pi * 220 * i / 16000))
        .round();
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('silence is 0, a full-scale voice 1, a quiet one in between', () {
    expect(MicLevel.of(_tone(0)), 0);
    expect(MicLevel.of(Uint8List(0)), 0);
    expect(MicLevel.of(_tone(1)), 1);
    final quiet = MicLevel.of(_tone(0.02)); // about -37 dBFS
    expect(quiet, inInclusiveRange(0.3, 0.6));
  });

  test('rises at once, falls back gently', () {
    final loud = MicLevel.next(0, _tone(1));
    expect(loud, 1);
    final after = MicLevel.next(loud, _tone(0));
    expect(after, closeTo(0.7, 1e-9));
  });
}
