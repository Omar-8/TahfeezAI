import 'live_quran_recognizer.dart';

/// One entry of a Web Speech `SpeechRecognitionResultList`.
typedef WebSpeechResult = ({
  bool isFinal,
  String transcript,
  double? confidence,
});

/// Turns Web Speech API `result` events into [LiveRecognitionEvent]s.
///
/// In continuous mode every event carries the whole session's result list:
/// earlier results that are already final stay in it, and only the tail
/// from `resultIndex` changed. This emits each final result exactly once
/// and a partial made of the not-yet-final tail. Browser-free so it can be
/// unit-tested.
class WebSpeechResultTracker {
  int _finalsEmitted = 0;

  /// Call when the browser starts a new recognition session (its result
  /// list starts over).
  void reset() => _finalsEmitted = 0;

  List<LiveRecognitionEvent> onResult(
    List<WebSpeechResult> results,
    int resultIndex,
  ) {
    final events = <LiveRecognitionEvent>[];
    final partial = StringBuffer();
    for (var i = resultIndex; i < results.length; i++) {
      final result = results[i];
      final text = normalizeTranscriptSpacing(result.transcript);
      if (result.isFinal) {
        if (i >= _finalsEmitted) {
          _finalsEmitted = i + 1;
          if (text.isNotEmpty) {
            events.add(
              LiveFinalTranscript(text, confidence: result.confidence),
            );
          }
        }
      } else if (text.isNotEmpty) {
        if (partial.isNotEmpty) partial.write(' ');
        partial.write(text);
      }
    }
    if (partial.isNotEmpty) {
      events.add(
        LivePartialTranscript(normalizeTranscriptSpacing(partial.toString())),
      );
    }
    return events;
  }
}
