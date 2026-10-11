import 'dart:async';

import 'package:tahfeez_ai/core/audio/audio_controller.dart';
import 'package:tahfeez_ai/core/audio/audio_models.dart';

/// A trivial in-memory [AudioController] for widget tests.
///
/// The real [JustAudioController] wraps `package:just_audio`, which talks
/// to a platform channel that `flutter test` does not provide an
/// implementation for — unlike `drift`'s in-memory `NativeDatabase`, there
/// is no equivalent "real but test-safe" backend for it, so this fake
/// stands in wherever a widget test renders something that watches
/// `audioControllerProvider` (e.g. `MiniPlayerRegion`) without exercising
/// actual playback.
class FakeAudioController implements AudioController {
  final _controller = StreamController<AudioPlaybackState>.broadcast();
  AudioPlaybackState _current = const AudioPlaybackState();

  @override
  Stream<AudioPlaybackState> get state => _controller.stream;

  void _emit(AudioPlaybackState Function(AudioPlaybackState) transform) {
    _current = transform(_current);
    _controller.add(_current);
  }

  @override
  Future<void> playUrl(String url, {AudioItemInfo? info}) async {
    _emit((s) => s.copyWith(isPlaying: true, durationMs: 60000));
  }

  /// The last queue played.
  List<String> queue = const [];

  /// The last queue's titles.
  List<AudioItemInfo>? items;

  @override
  Future<void> playQueue(
    List<String> urls, {
    List<AudioItemInfo>? items,
  }) async {
    queue = urls;
    this.items = items;
    _emit(
      (s) => s.copyWith(isPlaying: true, durationMs: 60000, currentIndex: 0),
    );
  }

  /// Stopped from outside the app (the media notification's stop).
  void stopFromOutside() =>
      _emit((s) => s.copyWith(isPlaying: false, stopped: true));

  /// Moves the queue on, as the player would.
  void advanceTo(int index) => _emit((s) => s.copyWith(currentIndex: index));

  /// Plays to the end, as the player would — which then keeps reporting
  /// `completed` until something new loads.
  void finish() => _emit((s) => s.copyWith(isPlaying: false, completed: true));

  @override
  Future<void> pause() async => _emit((s) => s.copyWith(isPlaying: false));

  @override
  Future<void> resume() async => _emit((s) => s.copyWith(isPlaying: true));

  @override
  Future<void> stop() async => _emit((_) => const AudioPlaybackState());

  @override
  Future<void> seek(Duration position) async {
    _emit((s) => s.copyWith(positionMs: position.inMilliseconds));
  }

  @override
  Future<void> setSpeed(double speed) async {
    _emit((s) => s.copyWith(speed: speed));
  }

  @override
  Future<void> setContentOption(AudioContentOption option) async {
    _emit((s) => s.copyWith(contentOption: option));
  }

  @override
  Future<void> setEndBehaviour(AudioEndBehaviour behaviour) async {
    _emit((s) => s.copyWith(endBehaviour: behaviour));
  }

  @override
  Future<void> setRepeatCount(int count) async {
    _emit((s) => s.copyWith(repeatCount: count));
  }

  @override
  Future<void> dispose() async => _controller.close();
}
