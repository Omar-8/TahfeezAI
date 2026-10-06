import 'dart:typed_data';

/// Live microphone audio handed to a [LiveQuranRecognizer]: raw
/// little-endian PCM16 chunks in capture order.
class LiveAudioInput {
  const LiveAudioInput({
    required this.sampleRate,
    required this.channels,
    required this.audio,
  });

  final int sampleRate;
  final int channels;
  final Stream<Uint8List> audio;
}

/// Collapses the doubled/leading/trailing spaces some engines produce when
/// joining stable and still-changing text. Spacing only — the recognized
/// words themselves are never altered.
String normalizeTranscriptSpacing(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

enum LiveRecognizerStatus {
  idle,
  starting,
  listening,

  /// Between two recognition segments/sessions of one continuous run (the
  /// underlying engine ended a segment and is being restarted).
  restarting,
  stopped,
  unavailable,
  error,
}

/// What a recognizer reports while running. Plain speech-to-text only —
/// no Quran alignment, word matching or mistake detection happens at this
/// layer.
sealed class LiveRecognitionEvent {
  const LiveRecognitionEvent();
}

/// The engine's current best guess for the segment in progress. Each
/// partial replaces the previous one (it is not a delta).
class LivePartialTranscript extends LiveRecognitionEvent {
  const LivePartialTranscript(this.text);
  final String text;
}

/// A finished segment. The next partial starts a new segment.
class LiveFinalTranscript extends LiveRecognitionEvent {
  const LiveFinalTranscript(this.text, {this.confidence});
  final String text;

  /// 0–1 where the engine reports one.
  final double? confidence;
}

class LiveRecognizerStatusChanged extends LiveRecognitionEvent {
  const LiveRecognizerStatusChanged(this.status, {this.detail});
  final LiveRecognizerStatus status;

  /// Human-readable engine detail (mode, reason for a restart…), for
  /// diagnostics only.
  final String? detail;
}

class LiveRecognitionError extends LiveRecognitionEvent {
  const LiveRecognitionError(this.message, {this.recoverable = true});
  final String message;

  /// `false` when the engine gave up (no permission, language unsupported,
  /// engine missing); `true` when it keeps going after this.
  final bool recoverable;
}

class LiveRecognizerAvailability {
  const LiveRecognizerAvailability({required this.available, this.detail});
  final bool available;
  final String? detail;
}

/// Streaming Arabic speech recognition for live recitation.
///
/// The app depends only on this interface; each engine (a platform
/// recognizer, a cloud stream, an on-device model) is one replaceable
/// implementation. Implementations run continuously from [start] to
/// [stop], restarting their underlying engine between segments as needed,
/// and never touch Quran data.
abstract class LiveQuranRecognizer {
  /// Short engine name for diagnostics, e.g. "Android SpeechRecognizer".
  String get name;

  /// Broadcast stream of events for every run of this recognizer.
  Stream<LiveRecognitionEvent> get events;

  Future<LiveRecognizerAvailability> checkAvailability();

  /// Starts recognizing [input]. An engine that can't consume external
  /// audio (and listens to the microphone itself) may ignore
  /// [LiveAudioInput.audio]; it must say so in its status detail.
  Future<void> start(LiveAudioInput input);

  /// Ends the run, letting the engine deliver a final transcript for any
  /// audio it already has.
  Future<void> stop();

  Future<void> dispose();
}
