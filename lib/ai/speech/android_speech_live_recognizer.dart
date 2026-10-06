import 'dart:async';

import 'package:flutter/services.dart';

import 'live_quran_recognizer.dart';

/// [LiveQuranRecognizer] backed by Android's platform `SpeechRecognizer`
/// (whatever recognition service the device provides — usually Google's),
/// through `LiveSpeechRecognizerChannel.kt`.
///
/// On Android 13+ the session's own microphone PCM is piped into the
/// recognizer, so the R1 recording and recognition share one microphone.
/// Older versions let the recognizer open the microphone itself.
class AndroidSpeechLiveRecognizer implements LiveQuranRecognizer {
  AndroidSpeechLiveRecognizer({
    this.language = 'ar-SA',
    this.preferOnDevice = false,
    MethodChannel? methods,
    EventChannel? events,
  }) : _methods = methods ?? const MethodChannel('tahfeez/live_speech'),
       _eventChannel =
           events ?? const EventChannel('tahfeez/live_speech/events');

  final String language;

  /// Ask for the on-device recognizer where the device has one.
  final bool preferOnDevice;

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final _events = StreamController<LiveRecognitionEvent>.broadcast();
  StreamSubscription<Object?>? _platformEvents;
  StreamSubscription<Uint8List>? _audio;

  @override
  String get name => 'Android SpeechRecognizer';

  @override
  Stream<LiveRecognitionEvent> get events => _events.stream;

  @override
  Future<LiveRecognizerAvailability> checkAvailability() async {
    try {
      final result = await _methods.invokeMapMethod<String, Object?>(
        'availability',
      );
      final available = result?['available'] == true;
      return LiveRecognizerAvailability(
        available: available,
        detail: available
            ? 'API ${result?['sdk']}, '
                  '${result?['feedsAudio'] == true ? 'shared mic' : 'own mic'}'
                  '${result?['onDevice'] == true ? ', on-device available' : ''}'
            : 'No speech recognition service on this device',
      );
    } on PlatformException catch (e) {
      return LiveRecognizerAvailability(available: false, detail: e.message);
    } on MissingPluginException {
      return const LiveRecognizerAvailability(
        available: false,
        detail: 'Native recognizer not registered',
      );
    }
  }

  @override
  Future<void> start(LiveAudioInput input) async {
    await _stopAudio();
    _platformEvents ??= _eventChannel.receiveBroadcastStream().listen(
      _onPlatformEvent,
      onError: (Object error) =>
          _events.add(LiveRecognitionError('$error', recoverable: false)),
    );
    final result = await _methods.invokeMapMethod<String, Object?>('start', {
      'language': language,
      'sampleRate': input.sampleRate,
      'channels': input.channels,
      'preferOnDevice': preferOnDevice,
    });
    if (result?['feedsAudio'] == true) {
      _audio = input.audio.listen((chunk) {
        // Fire-and-forget: chunks are queued in order on the platform side.
        _methods.invokeMethod<void>('feed', chunk).ignore();
      });
    }
  }

  void _onPlatformEvent(Object? raw) {
    if (raw is! Map) return;
    switch (raw['type']) {
      case 'partial':
        final text = raw['text'];
        if (text is String) {
          _events.add(LivePartialTranscript(normalizeTranscriptSpacing(text)));
        }
      case 'final':
        final text = raw['text'];
        final confidence = raw['confidence'];
        if (text is String) {
          _events.add(
            LiveFinalTranscript(
              normalizeTranscriptSpacing(text),
              confidence: confidence is num ? confidence.toDouble() : null,
            ),
          );
        }
      case 'status':
        final status = switch (raw['status']) {
          'starting' => LiveRecognizerStatus.starting,
          'listening' => LiveRecognizerStatus.listening,
          'restarting' => LiveRecognizerStatus.restarting,
          'stopped' => LiveRecognizerStatus.stopped,
          'error' => LiveRecognizerStatus.error,
          _ => null,
        };
        if (status != null) {
          _events.add(
            LiveRecognizerStatusChanged(
              status,
              detail: raw['detail'] as String?,
            ),
          );
        }
      case 'error':
        _events.add(
          LiveRecognitionError(
            '${raw['message']}',
            recoverable: raw['recoverable'] != false,
          ),
        );
    }
  }

  Future<void> _stopAudio() async {
    await _audio?.cancel();
    _audio = null;
  }

  @override
  Future<void> stop() async {
    await _stopAudio();
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Nothing was running.
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _platformEvents?.cancel();
    _platformEvents = null;
    await _events.close();
  }
}
