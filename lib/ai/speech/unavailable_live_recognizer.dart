import 'dart:async';

import 'live_quran_recognizer.dart';

/// Used where no recognition engine exists for the platform: reports itself
/// unavailable and never produces transcripts.
class UnavailableLiveRecognizer implements LiveQuranRecognizer {
  UnavailableLiveRecognizer([this.reason = 'No recognizer on this platform']);

  final String reason;
  final _events = StreamController<LiveRecognitionEvent>.broadcast();

  @override
  String get name => 'None';

  @override
  Stream<LiveRecognitionEvent> get events => _events.stream;

  @override
  Future<LiveRecognizerAvailability> checkAvailability() async =>
      LiveRecognizerAvailability(available: false, detail: reason);

  @override
  Future<void> start(LiveAudioInput input) async {
    _events.add(
      LiveRecognizerStatusChanged(
        LiveRecognizerStatus.unavailable,
        detail: reason,
      ),
    );
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _events.close();
}
