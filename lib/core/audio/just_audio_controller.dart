import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
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
    : _player = player ?? AudioPlayer(),
      _fresh = player == null && kIsWeb {
    _stateController = StreamController<AudioPlaybackState>.broadcast();
    _current = const AudioPlaybackState();
    _listen();
  }

  AudioPlayer _player;

  /// In a browser, a new player for each new source: just_audio's web side
  /// keeps the first playlist it was given (by its fixed id), so every
  /// later queue would play that one again — every ayah's Play button the
  /// first ayah's audio. The phones' players are kept.
  final bool _fresh;
  double _speed = 1;
  late final StreamController<AudioPlaybackState> _stateController;
  var _subscriptions = <StreamSubscription<void>>[];
  late AudioPlaybackState _current;

  void _listen() {
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

  /// Before a new source (in a browser): the old player gone, a new one at
  /// the same speed. Returns the player to play.
  Future<AudioPlayer> _playerForNewSource() async {
    if (!_fresh) return _player;
    final old = _player;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions = [];
    _player = AudioPlayer();
    await _player.setSpeed(_speed);
    unawaited(old.dispose());
    return _player;
  }

  /// A new player heard from once its source is loaded ([_playerForNewSource]):
  /// its first state, idle before loading, would read as playback stopped.
  void _listenIfNew() {
    if (_subscriptions.isEmpty) _listen();
  }

  /// Plays [player] until it stops or pauses; a player replaced meanwhile
  /// (a newer source) ends quietly.
  Future<void> _play(AudioPlayer player) async {
    try {
      await player.play();
    } catch (_) {
      if (identical(player, _player)) rethrow;
    }
  }

  void _update(AudioPlaybackState Function(AudioPlaybackState) transform) {
    _current = transform(_current);
    _stateController.add(_current);
  }

  @override
  Stream<AudioPlaybackState> get state => _stateController.stream;

  @override
  Future<void> playUrl(String url, {AudioItemInfo? info}) async {
    final player = await _playerForNewSource();
    await player.setAudioSource(_source(url, info));
    _listenIfNew();
    await _play(player);
  }

  @override
  Future<void> playClip(
    String url,
    Duration start,
    Duration end, {
    AudioItemInfo? info,
  }) async {
    final child = _source(url, info);
    final player = await _playerForNewSource();
    await player.setAudioSource(
      ClippingAudioSource(child: child, start: start, end: end, tag: child.tag),
    );
    _listenIfNew();
    await _play(player);
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
  static ProgressiveAudioSource _source(String url, AudioItemInfo? info) =>
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
    final player = await _playerForNewSource();
    await player.setAudioSources([
      for (var i = 0; i < urls.length; i++)
        _source(urls[i], items != null && i < items.length ? items[i] : null),
    ]);
    _listenIfNew();
    await _play(player);
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
  Future<void> setSpeed(double speed) {
    _speed = speed;
    return _player.setSpeed(speed);
  }

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
