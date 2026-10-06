import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'live_quran_recognizer.dart';
import 'web_speech_result_tracker.dart';

/// [LiveQuranRecognizer] backed by the browser's Web Speech API
/// (`SpeechRecognition`, `webkitSpeechRecognition` in Chrome/Edge/Safari).
///
/// The session's own PCM ([LiveAudioInput.audio]) is replayed into a
/// `MediaStreamTrack` and passed to `SpeechRecognition.start(track)`
/// (Chrome 13x+), so recognition hears exactly what the R1 recording
/// captures, through one microphone. Browsers without track input ignore
/// the argument and listen to the default microphone themselves. In Chrome
/// the audio is recognized by Google's servers.
class WebSpeechLiveRecognizer implements LiveQuranRecognizer {
  WebSpeechLiveRecognizer({this.language = 'ar-SA'});

  final String language;

  final _events = StreamController<LiveRecognitionEvent>.broadcast();
  final _tracker = WebSpeechResultTracker();
  web.SpeechRecognition? _recognition;
  _PcmTrack? _track;
  StreamSubscription<Uint8List>? _audio;
  bool _running = false;
  int _consecutiveErrors = 0;

  @override
  String get name => 'Web Speech API';

  @override
  Stream<LiveRecognitionEvent> get events => _events.stream;

  static JSFunction? get _constructor {
    final global = globalContext;
    for (final name in ['SpeechRecognition', 'webkitSpeechRecognition']) {
      final ctor = global.getProperty<JSAny?>(name.toJS);
      if (ctor != null && ctor.isA<JSFunction>()) return ctor as JSFunction;
    }
    return null;
  }

  @override
  Future<LiveRecognizerAvailability> checkAvailability() async {
    if (_constructor == null) {
      return const LiveRecognizerAvailability(
        available: false,
        detail: 'This browser has no Web Speech recognition',
      );
    }
    return const LiveRecognizerAvailability(
      available: true,
      detail: 'app audio via MediaStreamTrack',
    );
  }

  @override
  Future<void> start(LiveAudioInput input) async {
    final ctor = _constructor;
    if (ctor == null) {
      _events
        ..add(
          const LiveRecognitionError(
            'This browser has no Web Speech recognition',
            recoverable: false,
          ),
        )
        ..add(
          const LiveRecognizerStatusChanged(LiveRecognizerStatus.unavailable),
        );
      return;
    }
    await _releaseAudio();
    _running = true;
    _consecutiveErrors = 0;
    try {
      final track = _PcmTrack(input.sampleRate, input.channels);
      _track = track;
      _audio = input.audio.listen(track.add);
    } catch (_) {
      // No Web Audio: fall back to the browser's own microphone capture.
      _track = null;
    }
    _events.add(
      LiveRecognizerStatusChanged(
        LiveRecognizerStatus.starting,
        detail: _detail,
      ),
    );
    _startSession(ctor);
  }

  String get _detail =>
      '${_track == null ? 'browser mic' : 'app audio track'}, $language';

  void _startSession(JSFunction ctor) {
    final recognition = ctor.callAsConstructor<web.SpeechRecognition>()
      ..lang = language
      ..continuous = true
      ..interimResults = true
      ..maxAlternatives = 1;
    _recognition = recognition;
    _tracker.reset();

    recognition.onstart = ((web.Event _) {
      if (!identical(_recognition, recognition)) return;
      _consecutiveErrors = 0;
      _events.add(
        LiveRecognizerStatusChanged(
          LiveRecognizerStatus.listening,
          detail: _detail,
        ),
      );
    }).toJS;

    recognition.onresult = ((web.SpeechRecognitionEvent event) {
      if (!identical(_recognition, recognition)) return;
      final list = event.results;
      final results = <WebSpeechResult>[
        for (var i = 0; i < list.length; i++)
          (
            isFinal: list.item(i).isFinal,
            transcript: list.item(i).item(0).transcript,
            confidence: list.item(i).item(0).confidence,
          ),
      ];
      _tracker.onResult(results, event.resultIndex).forEach(_events.add);
    }).toJS;

    recognition.onerror = ((web.SpeechRecognitionErrorEvent event) {
      if (!identical(_recognition, recognition)) return;
      final error = event.error;
      switch (error) {
        // Silence or an aborted session: `onend` restarts it.
        case 'no-speech' || 'aborted':
          return;
        case 'not-allowed' ||
            'service-not-allowed' ||
            'language-not-supported' ||
            'audio-capture':
          _running = false;
          _events
            ..add(LiveRecognitionError(error, recoverable: false))
            ..add(
              LiveRecognizerStatusChanged(
                LiveRecognizerStatus.error,
                detail: error,
              ),
            );
        default:
          _consecutiveErrors++;
          _events.add(LiveRecognitionError(error));
      }
    }).toJS;

    // Browsers end continuous sessions on their own (silence, time limits,
    // network hiccups); keep one logical run going until stop().
    recognition.onend = ((web.Event _) {
      if (!identical(_recognition, recognition)) return;
      if (!_running) {
        _recognition = null;
        unawaited(_releaseAudio());
        _events.add(
          const LiveRecognizerStatusChanged(LiveRecognizerStatus.stopped),
        );
        return;
      }
      if (_consecutiveErrors > 5) {
        _running = false;
        _recognition = null;
        _events.add(
          const LiveRecognizerStatusChanged(
            LiveRecognizerStatus.error,
            detail: 'giving up after repeated errors',
          ),
        );
        return;
      }
      _events.add(
        const LiveRecognizerStatusChanged(
          LiveRecognizerStatus.restarting,
          detail: 'browser ended the session',
        ),
      );
      Timer(Duration(milliseconds: 100 + 300 * _consecutiveErrors), () {
        if (_running && identical(_recognition, recognition)) {
          _startSession(ctor);
        }
      });
    }).toJS;

    try {
      final track = _track?.track;
      if (track == null) {
        recognition.start();
      } else {
        // `start(MediaStreamTrack)` isn't in package:web's bindings yet.
        recognition.callMethod<JSAny?>('start'.toJS, track);
      }
    } catch (e) {
      _events.add(LiveRecognitionError('$e'));
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    // stop() (not abort()) lets the browser deliver a last final result
    // before `onend`.
    _recognition?.stop();
  }

  Future<void> _releaseAudio() async {
    await _audio?.cancel();
    _audio = null;
    _track?.close();
    _track = null;
  }

  @override
  Future<void> dispose() async {
    _running = false;
    _recognition?.abort();
    _recognition = null;
    await _releaseAudio();
    await _events.close();
  }
}

/// Plays PCM16LE chunks, gaplessly and in order, into a `MediaStreamTrack`
/// (never to the speakers).
class _PcmTrack {
  _PcmTrack(this.sampleRate, this.channels)
    : _context = web.AudioContext(
        web.AudioContextOptions(sampleRate: sampleRate.toDouble()),
      ) {
    _destination = _context.createMediaStreamDestination();
    track = _destination.stream.getAudioTracks().toDart.first;
    unawaited(_context.resume().toDart);
  }

  /// Scheduling lead that absorbs chunk-arrival jitter without gaps.
  static const _lead = 0.05;

  final int sampleRate;
  final int channels;
  final web.AudioContext _context;
  late final web.MediaStreamAudioDestinationNode _destination;
  late final web.MediaStreamTrack track;
  double _nextTime = 0;

  void add(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    final frames = chunk.length ~/ (2 * channels);
    if (frames == 0) return;
    final mono = Float32List(frames);
    for (var f = 0; f < frames; f++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        sum += data.getInt16((f * channels + c) * 2, Endian.little);
      }
      mono[f] = sum / (channels * 32768);
    }
    final buffer = _context.createBuffer(1, frames, sampleRate.toDouble())
      ..copyToChannel(mono.toJS, 0);
    final source = _context.createBufferSource()..buffer = buffer;
    source.connect(_destination);
    final now = _context.currentTime;
    final at = _nextTime < now + _lead ? now + _lead : _nextTime;
    source.start(at);
    _nextTime = at + frames / sampleRate;
  }

  void close() {
    track.stop();
    unawaited(_context.close().toDart);
  }
}
