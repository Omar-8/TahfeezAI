/// Which combination of Quran recitation and translation-audio should play.
///
/// Matches the reference behavior confirmed in
/// `docs/reference/08_AUDIO_SPEC.md` §2 (`AudioOption`), recorded here so the
/// Audio milestone's [AudioController] implementation and any earlier UI
/// that reads playback preferences agree on the same vocabulary from the
/// start.
enum AudioContentOption { quranOnly, translationOnly, both }

/// What happens once the current playback scope (a verse group, repeated
/// the configured number of times) finishes.
///
/// Matches `docs/reference/08_AUDIO_SPEC.md` §3 (`AudioEndBehaviour`).
enum AudioEndBehaviour { stopPlayback, nextChapter, repeatChapter }

/// Immutable snapshot of what the audio subsystem is doing right now.
class AudioPlaybackState {
  const AudioPlaybackState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs,
    this.speed = 1.0,
    this.contentOption = AudioContentOption.quranOnly,
    this.endBehaviour = AudioEndBehaviour.stopPlayback,
    this.repeatCount = 1,
  });

  final bool isPlaying;
  final int positionMs;
  final int? durationMs;
  final double speed;
  final AudioContentOption contentOption;
  final AudioEndBehaviour endBehaviour;

  /// How many times the current verse/verse-group repeats before advancing.
  /// Matches the "custom repeat" capability in
  /// `docs/reference/08_AUDIO_SPEC.md` §2.
  final int repeatCount;

  AudioPlaybackState copyWith({
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    double? speed,
    AudioContentOption? contentOption,
    AudioEndBehaviour? endBehaviour,
    int? repeatCount,
  }) {
    return AudioPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      speed: speed ?? this.speed,
      contentOption: contentOption ?? this.contentOption,
      endBehaviour: endBehaviour ?? this.endBehaviour,
      repeatCount: repeatCount ?? this.repeatCount,
    );
  }
}
