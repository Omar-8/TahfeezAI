import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
          (s) => s.copyWith(
            completed: p == ProcessingState.completed,
            stopped: p == ProcessingState.idle,
          ),
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
  Future<void> playUrl(String url, {AudioItemInfo? info}) async {
    await _player.setAudioSource(_source(url, info));
    await _player.play();
  }

  /// The recitation files are constant-bitrate MP3s, some (Ahmad al-Ajamy's
  /// first ayah of a surah, cdn.islamic.network) with a Xing header from a
  /// longer recording: 183,901 bytes claimed for a 39,618-byte 106:1.
  /// ExoPlayer trusts the header ("Data size mismatch … using Xing value")
  /// and waits for the rest — about 9 s of silence after the ayah. Seeking
  /// by the constant bitrate always takes the file's real length instead.
  static const _options = ProgressiveAudioSourceOptions(
    androidExtractorOptions: AndroidExtractorOptions(
      constantBitrateSeekingEnabled: true,
      constantBitrateSeekingAlwaysEnabled: true,
    ),
  );

  /// [url] tagged for the media session (notification, lock screen).
  static AudioSource _source(String url, AudioItemInfo? info) =>
      ProgressiveAudioSource(
        Uri.parse(url),
        options: _options,
        tag: MediaItem(
          id: url,
          title: info?.title ?? 'TahfeezAI',
          artist: info?.subtitle,
          album: 'TahfeezAI',
        ),
      );

  @override
  Future<void> playQueue(
    List<String> urls, {
    List<AudioItemInfo>? items,
  }) async {
    await _player.setAudioSources([
      for (var i = 0; i < urls.length; i++)
        _source(urls[i], items != null && i < items.length ? items[i] : null),
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
