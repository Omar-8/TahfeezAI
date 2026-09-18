import 'package:freezed_annotation/freezed_annotation.dart';

part 'recitation_models.freezed.dart';

/// What a recognition session is currently listening against: a specific
/// Quran range, in a specific script (word indices are script-scoped, per
/// `docs/reference/06_DATA_MODEL_SPEC.md` §2).
@freezed
abstract class RecitationContext with _$RecitationContext {
  const factory RecitationContext({
    required int chapterNo,
    required int fromVerseNo,
    required int toVerseNo,
    required String scriptCode,
  }) = _RecitationContext;
}

/// Everything a future recitation-recognition engine can report while a
/// session is active.
///
/// This union is the *contract*, not an implementation — Milestone 1
/// defines it so the memorization/AI product area
/// (`docs/PROJECT_BRIEF.md` §"AI") has a stable event shape to design UI
/// against well before any real recognizer exists. Enumerated per this
/// milestone's own required event list; no recognition logic is implied or
/// implemented here.
@freezed
sealed class RecitationEvent with _$RecitationEvent {
  const factory RecitationEvent.started({required DateTime timestamp}) =
      RecitationStarted;

  /// A candidate Quran location the engine believes the reciter is at,
  /// before it is confident enough to call it a firm [ayahDetected].
  const factory RecitationEvent.positionCandidate({
    required int chapterNo,
    required int verseNo,
    required double confidence,
  }) = RecitationPositionCandidate;

  const factory RecitationEvent.ayahDetected({
    required int chapterNo,
    required int verseNo,
  }) = RecitationAyahDetected;

  const factory RecitationEvent.wordMatched({required int wordIndex}) =
      RecitationWordMatched;

  const factory RecitationEvent.wordSkipped({required int wordIndex}) =
      RecitationWordSkipped;

  const factory RecitationEvent.wordIncorrect({
    required int wordIndex,
    String? heardText,
  }) = RecitationWordIncorrect;

  const factory RecitationEvent.hesitation({
    required int wordIndex,
    required Duration duration,
  }) = RecitationHesitation;

  const factory RecitationEvent.selfCorrection({required int wordIndex}) =
      RecitationSelfCorrection;

  const factory RecitationEvent.confidenceUpdate({required double confidence}) =
      RecitationConfidenceUpdate;

  const factory RecitationEvent.ended({required DateTime timestamp}) =
      RecitationEnded;

  const factory RecitationEvent.recognitionError({required String message}) =
      RecitationRecognitionError;
}
