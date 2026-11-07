import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import 'audio_controller.dart';
import 'audio_models.dart';
import 'file_length.dart';
import 'media_session.dart';

/// Minimal [AudioController] implementation backed directly by
/// `package:just_audio`, with no background session of its own yet.
///
/// This proves the [AudioController] seam compiles and works end-to-end
/// (play/pause/seek/speed against a real player) without taking on the
/// `audio_service` background-session wiring (platform manifest entries,
/// notification channel, lock-screen controls) that belongs to the Audio
/// milestone. Swapping this out for an `audio_service`-backed
/// implementation later requires no changes outside `lib/core/audio/`.
class JustAudioController implements AudioController, MediaSessionTarget {
  JustAudioController({AudioPlayer? player, TahfeezMediaSession? session})
    : _player = player ?? AudioPlayer(),
      _fresh = player == null && kIsWeb,
      _session = session ?? TahfeezMediaSession.instance {
    _stateController = StreamController<AudioPlaybackState>.broadcast();
    _current = const AudioPlaybackState();
    _session?.target = this;
    _listen();
  }

  /// The system's media session (the phones'; `null` in a browser).
  final TahfeezMediaSession? _session;

  /// What is playing, for the media session: each item's info and URL, its
  /// length as measured from its file (size at its bitrate) and as loaded.
  var _items = <AudioItemInfo?>[];
  var _urls = <String>[];
  var _measured = <int?>[];
  var _loaded = <int?>[];

  /// Counts the runs: a measuring for an older one stops.
  var _run = 0;
  DateTime _published = DateTime(0);

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
      _player.durationStream.listen((d) {
        final i = _player.currentIndex ?? 0;
        if (d != null && i < _loaded.length) _loaded[i] = d.inMilliseconds;
        _update((s) => s.copyWith(durationMs: d?.inMilliseconds));
      }),
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
    final before = _current;
    _current = transform(_current);
    _stateController.add(_current);
    // The media session: at once for a change of state, at most every
    // second for the position alone (the system moves it along itself).
    final moved =
        before.isPlaying == _current.isPlaying &&
        before.durationMs == _current.durationMs &&
        before.speed == _current.speed &&
        before.currentIndex == _current.currentIndex &&
        before.completed == _current.completed &&
        before.stopped == _current.stopped;
    if (!moved ||
        DateTime.now().difference(_published) >
            const Duration(milliseconds: 1000)) {
      _publish();
    }
  }

  List<int> _lengths() => timelineLengths(_loaded, _measured);

  /// Where [index] starts on the run's timeline.
  int _offsetOf(int index, List<int> lengths) {
    var offset = 0;
    for (var i = 0; i < index && i < lengths.length; i++) {
      offset += lengths[i];
    }
    return offset;
  }

  /// Shows what plays in the media session, the run as one item.
  void _publish() {
    final session = _session;
    if (session == null || _items.isEmpty) return;
    _published = DateTime.now();
    // Stopped, or played to its end: the notification goes (as the app's
    // own player bar), not left "playing" on.
    if (_current.stopped || _current.completed) {
      session.clear();
      return;
    }
    final index = (_current.currentIndex ?? 0).clamp(0, _items.length - 1);
    final lengths = _lengths();
    final info = _items[index];
    session.show(
      MediaItem(
        id: 'run-$_run',
        title: info?.group ?? info?.title ?? 'TahfeezAI',
        artist: [
          ?info?.subtitle,
          if (info?.group != null) ?info?.part,
        ].join(' · '),
        album: 'TahfeezAI',
        duration: Duration(milliseconds: lengths.fold(0, (a, b) => a + b)),
      ),
    );
    session.update(
      playing: _current.isPlaying,
      processing: _current.completed
          ? AudioProcessingState.completed
          : AudioProcessingState.ready,
      // (The player's own position: the stream's can still be the last
      // ayah's for a moment as the next one starts — a jump.)
      position: Duration(
        milliseconds:
            _offsetOf(index, lengths) +
            _player.position.inMilliseconds.clamp(0, lengths[index]),
      ),
      speed: _current.speed,
      index: index,
      count: _items.length,
    );
  }

  /// A new run: its items, their lengths measured in the background — a
  /// downloaded file's from its size, a streamed one's from the size the
  /// server gives (constant-bitrate recitation files), a few at a time.
  void _begin(List<String> urls, List<AudioItemInfo?> items) {
    final run = ++_run;
    _urls = urls;
    _items = items;
    _measured = List<int?>.filled(urls.length, null);
    _loaded = List<int?>.filled(urls.length, null);
    if (_session == null || urls.length < 2) return;
    unawaited(_measure(run));
  }

  Future<void> _measure(int run) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    var next = 0;
    Future<void> worker() async {
      while (run == _run && next < _urls.length) {
        final i = next++;
        final kbps = _items[i]?.kbps;
        if (kbps == null) continue;
        final url = _urls[i];
        int? bytes;
        if (url.startsWith('file:')) {
          bytes = await localFileLength(Uri.parse(url).toFilePath());
        } else {
          try {
            final head = await dio.head<void>(url);
            bytes = int.tryParse(
              head.headers.value(Headers.contentLengthHeader) ?? '',
            );
          } catch (_) {
            bytes = null;
          }
        }
        if (run != _run || bytes == null) continue;
        _measured[i] = bytes * 8 ~/ kbps;
        // (Shown as they come: every few, and the last.)
        if (i % 8 == 0 || i == _urls.length - 1) _publish();
      }
    }

    await Future.wait([for (var k = 0; k < 6; k++) worker()]);
    dio.close();
    if (run == _run) _publish();
  }

  @override
  Future<void> play() => resume();

  @override
  Future<void> seekTimeline(Duration position) async {
    final at = timelinePlace(_lengths(), position.inMilliseconds);
    if (at == null) return;
    await _player.seek(Duration(milliseconds: at.offsetMs), index: at.index);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    // Some way in: back to the ayah's start (as a music player).
    if (_player.position > const Duration(seconds: 3)) {
      return _player.seek(Duration.zero);
    }
    return _player.seekToPrevious();
  }

  @override
  Stream<AudioPlaybackState> get state => _stateController.stream;

  @override
  Future<void> playUrl(String url, {AudioItemInfo? info}) async {
    _begin([url], [info]);
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
    _begin([url], [info]);
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

  /// [url] tagged with its [info] (the media session shows the run).
  static ProgressiveAudioSource _source(String url, AudioItemInfo? info) =>
      ProgressiveAudioSource(Uri.parse(url), options: _options, tag: info);

  @override
  Future<void> playQueue(
    List<String> urls, {
    List<AudioItemInfo>? items,
  }) async {
    _begin(urls, [
      for (var i = 0; i < urls.length; i++)
        items != null && i < items.length ? items[i] : null,
    ]);
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
    if (_session?.target == this) _session?.target = null;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _stateController.close();
    await _player.dispose();
  }
}

/// A run's items' lengths in ms: each as loaded; else as measured from its
/// file, scaled as the loaded ones came out against their measures (a
/// file's bitrate a little off its nominal one: the times would jump as each
/// loads); else the others' mean (10 s before any is known).
List<int> timelineLengths(List<int?> loaded, List<int?> measured) {
  final ratios = [
    for (var i = 0; i < loaded.length; i++)
      if (loaded[i] != null && (measured[i] ?? 0) > 0)
        loaded[i]! / measured[i]!,
  ]..sort();
  final scale = ratios.isEmpty ? 1.0 : ratios[ratios.length ~/ 2];
  final estimated = [
    for (var i = 0; i < loaded.length; i++)
      loaded[i] ??
          (measured[i] == null ? null : (measured[i]! * scale).round()),
  ];
  final known = [for (final ms in estimated) ?ms];
  final mean = known.isEmpty
      ? 10000
      : known.reduce((a, b) => a + b) ~/ known.length;
  return [for (final ms in estimated) ms ?? mean];
}

/// Where [positionMs] on a run's timeline falls: its item and the place in
/// it (past the end: the last item's end); `null` for an empty run.
({int index, int offsetMs})? timelinePlace(List<int> lengths, int positionMs) {
  var start = 0;
  for (var i = 0; i < lengths.length; i++) {
    if (positionMs < start + lengths[i] || i == lengths.length - 1) {
      return (index: i, offsetMs: (positionMs - start).clamp(0, lengths[i]));
    }
    start += lengths[i];
  }
  return null;
}
