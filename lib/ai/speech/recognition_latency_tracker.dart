import 'dart:math' as math;
import 'dart:typed_data';

/// Measures recognition latency against the live audio itself, independent
/// of which engine produced the transcripts.
///
/// A small energy-based voice-activity detector runs over the PCM16 chunks:
///
/// - **first-partial latency**: from the moment voice starts (after a
///   pause) to the first partial transcript that follows;
/// - **final latency**: from the moment voice stops to the final
///   transcript for that segment (only when the final arrives during a
///   pause — a final delivered mid-speech has no meaningful "end").
///
/// Timestamps are chunk arrival times, so figures include capture
/// buffering (about one chunk). Diagnostics only.
class RecognitionLatencyTracker {
  RecognitionLatencyTracker({
    this.hangover = const Duration(milliseconds: 400),
    this.minThresholdDb = -50,
    this.marginDb = 12,
  });

  /// How long the level must stay below the threshold before voice is
  /// considered to have stopped (bridges gaps between syllables).
  final Duration hangover;
  final double minThresholdDb;

  /// How far above the tracked noise floor counts as voice.
  final double marginDb;

  double _noiseFloorDb = -60;
  bool _speaking = false;
  DateTime? _voiceStart;
  DateTime? _lastVoiceAt;
  bool _awaitingPartial = false;

  bool get speaking => _speaking;
  double get noiseFloorDb => _noiseFloorDb;

  void reset() {
    _speaking = false;
    _voiceStart = null;
    _lastVoiceAt = null;
    _awaitingPartial = false;
  }

  /// Level of a PCM16LE chunk in dBFS (−96 for digital silence).
  static double levelDb(Uint8List chunk) {
    final samples = chunk.length ~/ 2;
    if (samples == 0) return -96;
    final data = ByteData.sublistView(chunk);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples);
    return rms <= 0 ? -96 : math.max(-96, 20 * math.log(rms) / math.ln10);
  }

  void onAudio(Uint8List chunk, DateTime now) {
    final db = levelDb(chunk);
    final threshold = math.max(minThresholdDb, _noiseFloorDb + marginDb);
    if (db >= threshold) {
      if (!_speaking) {
        _speaking = true;
        _voiceStart = now;
        _awaitingPartial = true;
      }
      _lastVoiceAt = now;
    } else {
      final last = _lastVoiceAt;
      if (_speaking && last != null && now.difference(last) >= hangover) {
        _speaking = false;
      }
    }
    // Floor follows quiet levels down immediately and creeps up slowly, so
    // a noisy room raises it but continuous speech barely does.
    _noiseFloorDb = db < _noiseFloorDb ? db : math.min(_noiseFloorDb + 0.1, db);
  }

  /// Returns the first-partial latency if this partial is the first since
  /// voice started.
  Duration? onPartial(DateTime now) {
    final start = _voiceStart;
    if (!_awaitingPartial || start == null) return null;
    _awaitingPartial = false;
    return now.difference(start);
  }

  /// Returns the final latency if voice had already stopped.
  Duration? onFinal(DateTime now) {
    final last = _lastVoiceAt;
    if (_speaking || last == null) return null;
    return now.difference(last);
  }
}
