import 'dart:math' as math;
import 'dart:typed_data';

/// Notices the reciter stopping: speech, then [minPause] of quiet. Fires
/// once per stop, so the pipeline can compute the audio up to the stop at
/// once — the look-ahead it would otherwise wait for is only silence — and
/// the last word before a pause (typically an ayah's last word) is placed as
/// soon as it is said, not when the next one begins.
///
/// Quiet is relative to the room: below 3× an adaptive noise floor (and an
/// absolute floor), on 20 ms frames.
class PauseDetector {
  PauseDetector({
    this.sampleRate = 16000,
    this.minSpeech = const Duration(milliseconds: 200),
    this.minPause = const Duration(milliseconds: 300),
  });

  final int sampleRate;
  final Duration minSpeech, minPause;

  int get _frame => sampleRate ~/ 50;
  double _noise = 0.003;
  int _speechFrames = 0, _quietFrames = 0;
  bool _armed = false;
  final _pending = <double>[];

  /// Feeds [samples] (in [-1, 1]); true if a stop was just heard.
  bool add(Float32List samples) {
    var fired = false;
    for (final s in samples) {
      _pending.add(s);
      if (_pending.length < _frame) continue;
      var sum = 0.0;
      for (final x in _pending) {
        sum += x * x;
      }
      _pending.clear();
      fired = _onFrame(math.sqrt(sum / _frame)) || fired;
    }
    return fired;
  }

  /// The level (RMS) above which a 20 ms frame is speech: 3× the room's
  /// noise floor, at least 0.006.
  double get speechLevel => math.max(0.006, 3 * _noise);

  /// Whether every 20 ms frame of [samples] is below [speechLevel].
  bool isQuiet(Float32List samples) {
    final level = speechLevel;
    for (var i = 0; i + _frame <= samples.length; i += _frame) {
      var sum = 0.0;
      for (var k = i; k < i + _frame; k++) {
        sum += samples[k] * samples[k];
      }
      if (math.sqrt(sum / _frame) > level) return false;
    }
    return true;
  }

  bool _onFrame(double rms) {
    final speech = rms > speechLevel;
    if (speech) {
      _speechFrames++;
      _quietFrames = 0;
      if (_speechFrames * 20 >= minSpeech.inMilliseconds) _armed = true;
      return false;
    }
    // Quiet: track the noise floor (slowly up, quickly down).
    _noise = rms < _noise
        ? 0.9 * _noise + 0.1 * rms
        : 0.995 * _noise + 0.005 * rms;
    _quietFrames++;
    if (_armed && _quietFrames * 20 >= minPause.inMilliseconds) {
      _armed = false;
      _speechFrames = 0;
      return true;
    }
    if (_quietFrames * 20 >= minPause.inMilliseconds) _speechFrames = 0;
    return false;
  }
}
