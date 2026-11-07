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
/// What is playing, as the media notification and lock screen show it.
class AudioItemInfo {
  const AudioItemInfo({
    required this.title,
    this.subtitle,
    this.group,
    this.part,
    this.kbps,
  });

  final String title;
  final String? subtitle;

  /// What a run of items is, shown as one in the media session (a surah);
  /// [part] this item's place in it (an ayah's number). Without them, the
  /// item alone ([title]).
  final String? group, part;

  /// The file's constant bitrate, if known: its length from its size.
  final int? kbps;
}

class AudioPlaybackState {
  const AudioPlaybackState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs,
    this.speed = 1.0,
    this.contentOption = AudioContentOption.quranOnly,
    this.endBehaviour = AudioEndBehaviour.stopPlayback,
    this.repeatCount = 1,
    this.currentIndex,
    this.completed = false,
    this.stopped = false,
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

  /// The item of a queue ([AudioController.playQueue]) playing now.
  final int? currentIndex;

  /// Played to the end.
  final bool completed;

  /// Stopped (nothing loaded) — e.g. from the media notification.
  final bool stopped;

  AudioPlaybackState copyWith({
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    double? speed,
    AudioContentOption? contentOption,
    AudioEndBehaviour? endBehaviour,
    int? repeatCount,
    int? currentIndex,
    bool? completed,
    bool? stopped,
  }) {
    return AudioPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      speed: speed ?? this.speed,
      contentOption: contentOption ?? this.contentOption,
      endBehaviour: endBehaviour ?? this.endBehaviour,
      repeatCount: repeatCount ?? this.repeatCount,
      currentIndex: currentIndex ?? this.currentIndex,
      completed: completed ?? this.completed,
      stopped: stopped ?? this.stopped,
    );
  }
}
