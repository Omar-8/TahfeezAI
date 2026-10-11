import 'audio_models.dart';

/// Transport-level control surface for recitation/translation audio
/// playback.
///
/// This interface is the seam between UI (mini player, expanded player,
/// verse play buttons) and the concrete playback engine. Milestone 1 wires
/// only a minimal `just_audio`-backed implementation to prove the seam is
/// real; the Audio milestone (12) is responsible for the full
/// `audio_service`-backed background session (lock-screen controls, verse
/// clip planning, verse-group repeat, reciter switching) described in
/// `docs/reference/08_AUDIO_SPEC.md`, behind this same interface.
abstract class AudioController {
  Stream<AudioPlaybackState> get state;

  Future<void> playUrl(String url, {AudioItemInfo? info});

  /// Plays [urls] one after another; [AudioPlaybackState.currentIndex] says
  /// which. Throws when the first can't be loaded (e.g. offline). [items]:
  /// each one's title for the media notification and lock screen.
  Future<void> playQueue(List<String> urls, {List<AudioItemInfo>? items});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setContentOption(AudioContentOption option);
  Future<void> setEndBehaviour(AudioEndBehaviour behaviour);
  Future<void> setRepeatCount(int count);

  Future<void> dispose();
}
