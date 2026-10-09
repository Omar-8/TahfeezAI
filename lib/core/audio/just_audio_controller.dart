import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_controller.dart';
import 'audio_models.dart';

/// Minimal [AudioController] implementation backed directly by
/// `package:just_audio`, with no background session of its own yet.
///
/// This proves the [AudioController] seam compiles and works end-to-end
/// (play/pause/seek/speed against a real player) without taking on the
/// `audio_service` background-session wiring (platform manifest entries,
/// notification channel, lock-screen controls) that belongs to the Audio
/// milestone. Swapping this out for an `audio_service`-backed
/// implementation later requires no changes outside `lib/core/audio/`.
class JustAudioController implements AudioController {
  JustAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _stateController = StreamController<AudioPlaybackState>.broadcast();
    _current = const AudioPlaybackState();
    _subscriptions = [
      _player.playingStream.listen(
        (playing) => _update((s) => s.copyWith(isPlaying: playing)),
      ),
      _player.positionStream.listen(
        (pos) => _update((s) => s.copyWith(positionMs: pos.inMilliseconds)),
      ),
      _player.durationStream.listen(
        (d) => _update((s) => s.copyWith(durationMs: d?.inMilliseconds)),
      ),
      _player.speedStream.listen(
        (speed) => _update((s) => s.copyWith(speed: speed)),
      ),
      _player.currentIndexStream.listen(
        (i) => _update((s) => s.copyWith(currentIndex: i)),
      ),
      _player.processingStateStream.listen(
        (p) => _update(
          (s) => s.copyWith(completed: p == ProcessingState.completed),
        ),
      ),
    ];
  }

  final AudioPlayer _player;
  late final StreamController<AudioPlaybackState> _stateController;
  late final List<StreamSubscription<void>> _subscriptions;
  late AudioPlaybackState _current;

  void _update(AudioPlaybackState Function(AudioPlaybackState) transform) {
    _current = transform(_current);
    _stateController.add(_current);
  }

  @override
  Stream<AudioPlaybackState> get state => _stateController.stream;

  @override
  Future<void> playUrl(String url) async {
    await _player.setUrl(url);
    await _player.play();
  }

  @override
  Future<void> playQueue(List<String> urls) async {
    await _player.setAudioSources([
      for (final url in urls) AudioSource.uri(Uri.parse(url)),
    ]);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setContentOption(AudioContentOption option) async {
    _update((s) => s.copyWith(contentOption: option));
  }

  @override
  Future<void> setEndBehaviour(AudioEndBehaviour behaviour) async {
    _update((s) => s.copyWith(endBehaviour: behaviour));
  }

  @override
  Future<void> setRepeatCount(int count) async {
    _update((s) => s.copyWith(repeatCount: count));
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _stateController.close();
    await _player.dispose();
  }
}
