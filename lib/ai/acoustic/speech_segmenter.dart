import 'dart:math' as math;
import 'dart:typed_data';

/// A stretch of speech between pauses.
class SpeechSegment {
  const SpeechSegment(
    this.startSample,
    this.samples, {
    this.cutStart = false,
    this.cutEnd = false,
  });

  /// Position of the first sample in the whole stream.
  final int startSample;

  /// 16 kHz mono, range [-1, 1].
  final Float32List samples;

  /// It continues / was ended by a cut in running speech, not a pause.
  final bool cutStart, cutEnd;

  int get endSample => startSample + samples.length;
}

/// Cuts a live 16 kHz mono PCM16 stream into utterances at the reciter's
/// pauses. A 20 ms frame is voiced when its loudness is well above the
/// recent noise floor; an utterance ends after [pause] of silence. One
/// running past [maxLength] is cut at its quietest moment in the last few
/// seconds, and the next part starts [overlap] earlier so a word cut in two
/// is whole in one of them.
class SpeechSegmenter {
  SpeechSegmenter({
    this.pause = const Duration(milliseconds: 360),
    this.maxLength = const Duration(seconds: 15),
    this.minSpeech = const Duration(milliseconds: 200),
    this.overlap = const Duration(milliseconds: 1500),
  });

  static const sampleRate = 16000;
  static const _frame = 320; // 20 ms
  static const _headFrames = 5; // 100 ms kept before speech
  static const _tailFrames = 15; // 300 ms kept after it

  final Duration pause;
  final Duration maxLength;
  final Duration minSpeech;
  final Duration overlap;

  int get _pauseFrames => pause.inMilliseconds ~/ 20;
  int get _maxFrames => maxLength.inMilliseconds ~/ 20;
  int get _minVoiced => minSpeech.inMilliseconds ~/ 20;

  /// Samples consumed so far — the stream's clock.
  int get samplesSeen => _seen;
  int _seen = 0;

  int? _oddByte;
  final _partial = <double>[];
  double _noise = 0.002;

  final _frames = <Float32List>[];
  final _loudness = <double>[];
  int _startSample = 0;
  bool _inSpeech = false;
  bool _cutStart = false;
  int _voiced = 0;
  int _silentRun = 0;

  /// Someone is speaking: an utterance is in progress.
  bool get inSpeech => _inSpeech;

  /// Where the utterance in progress starts (with [inSpeech]).
  int get utteranceStart => _startSample;

  /// The utterance in progress continues one cut in running speech.
  bool get utteranceCutStart => _cutStart;

  /// PCM16LE bytes as samples in [-1, 1]; an odd trailing byte is kept for
  /// the next call.
  Float32List decodePcm16(Uint8List bytes) {
    var data = bytes;
    if (_oddByte != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = _oddByte!
        ..setRange(1, bytes.length + 1, bytes);
      _oddByte = null;
    }
    final whole = data.length ~/ 2 * 2;
    if (whole < data.length) _oddByte = data[data.length - 1];
    final view = ByteData.sublistView(data, 0, whole);
    final samples = Float32List(whole ~/ 2);
    for (var k = 0; k < samples.length; k++) {
      samples[k] = view.getInt16(k * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  List<SpeechSegment> addPcm16(Uint8List bytes) =>
      addSamples(decodePcm16(bytes));

  List<SpeechSegment> addSamples(Float32List samples) {
    final out = <SpeechSegment>[];
    for (final s in samples) {
      _partial.add(s);
      if (_partial.length == _frame) {
        final frame = Float32List.fromList(_partial);
        _partial.clear();
        final done = _onFrame(frame);
        if (done != null) out.add(done);
      }
    }
    return out;
  }

  /// Ends the utterance in progress (the session paused or stopped).
  SpeechSegment? flush() {
    _partial.clear();
    if (!_inSpeech) {
      _reset(_seen);
      return null;
    }
    return _close(_frames.length - math.max(0, _silentRun - _tailFrames));
  }

  SpeechSegment? _onFrame(Float32List frame) {
    var sum = 0.0;
    for (final s in frame) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / frame.length);
    final frameStart = _seen;
    _seen += frame.length;
    // The noise floor follows quiet frames at once, louder ones slowly.
    _noise = rms < _noise ? rms : _noise * 1.002 + 1e-6;
    final voiced = rms > math.max(_noise * 3, 0.003);

    if (!_inSpeech) {
      if (_frames.isEmpty) _startSample = frameStart;
      _frames.add(frame);
      _loudness.add(rms);
      if (_frames.length > _headFrames) {
        _frames.removeAt(0);
        _loudness.removeAt(0);
        _startSample += _frame;
      }
      if (voiced) {
        _inSpeech = true;
        _voiced = 1;
        _silentRun = 0;
      }
      return null;
    }
    _frames.add(frame);
    _loudness.add(rms);
    if (voiced) {
      _voiced++;
      _silentRun = 0;
    } else {
      _silentRun++;
    }
    if (_silentRun >= math.max(_pauseFrames, _tailFrames)) {
      return _close(_frames.length - (_silentRun - _tailFrames));
    }
    if (_frames.length >= _maxFrames) {
      final from = math.max(1, _frames.length - 150);
      var cut = from;
      for (var k = from; k < _frames.length; k++) {
        if (_loudness[k] < _loudness[cut]) cut = k;
      }
      return _close(cut, keepRest: true);
    }
    return null;
  }

  SpeechSegment? _close(int count, {bool keepRest = false}) {
    final n = count.clamp(0, _frames.length);
    final samples = Float32List(n * _frame);
    for (var k = 0; k < n; k++) {
      samples.setRange(k * _frame, (k + 1) * _frame, _frames[k]);
    }
    final segment = SpeechSegment(
      _startSample,
      samples,
      cutStart: _cutStart,
      cutEnd: keepRest,
    );
    final enough = _voiced >= _minVoiced;
    _cutStart = keepRest;
    if (keepRest) {
      final drop = math.max(0, n - overlap.inMilliseconds ~/ 20);
      _frames.removeRange(0, drop);
      _loudness.removeRange(0, drop);
      _startSample += drop * _frame;
      _voiced = _loudness.where((l) => l > math.max(_noise * 3, 0.003)).length;
    } else {
      _reset(_seen);
    }
    return enough ? segment : null;
  }

  void _reset(int at) {
    _frames.clear();
    _loudness.clear();
    _inSpeech = false;
    _voiced = 0;
    _silentRun = 0;
    _startSample = at;
  }
}
