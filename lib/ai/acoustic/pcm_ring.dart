import 'dart:math' as math;
import 'dart:typed_data';

/// The session's most recent audio as model input: PCM16 mono decoded to
/// [-1, 1], high-passed at 80 Hz (rumble, handling noise, wind), indexed by
/// stream position (samples since the session started).
class PcmRing {
  PcmRing({this.sampleRate = 16000, int seconds = 90})
    : _ring = Float32List(seconds * sampleRate),
      _hpA = 1 / (1 + 2 * math.pi * 80 / sampleRate);

  final int sampleRate;
  final Float32List _ring;
  final double _hpA;
  double _hp = 0, _hpPrev = 0;
  int _written = 0;

  /// Samples received so far.
  int get written => _written;

  /// The first sample still held.
  int get oldest => math.max(0, _written - _ring.length);

  void reset() {
    _written = 0;
    _hp = 0;
    _hpPrev = 0;
  }

  /// Appends little-endian PCM16 [chunk].
  void addPcm16(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    for (var k = 0; k + 1 < chunk.length; k += 2) {
      final x = data.getInt16(k, Endian.little) / 32768.0;
      // First-order high-pass at 80 Hz.
      _hp = _hpA * (_hp + x - _hpPrev);
      _hpPrev = x;
      _ring[_written++ % _ring.length] = _hp;
    }
  }

  /// Samples [from]..[to] (exclusive), clamped to what is held.
  Float32List samples(int from, int to) {
    final start = math.max(from, oldest);
    final end = math.min(to, _written);
    final out = Float32List(math.max(0, end - start));
    for (var t = start; t < end; t++) {
      out[t - start] = _ring[t % _ring.length];
    }
    return out;
  }
}
