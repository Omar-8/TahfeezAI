import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../listen/application/quran_audio_player.dart';
import '../domain/athkar.dart';

/// Plays a zikr's (or a category's) audio from hisnmuslim.com — streamed,
/// so only online (owner, 2026-11-21).
abstract class AthkarPlayer {
  /// Plays [uri]; done when it ends or is stopped. Throws when it can't be
  /// loaded (offline).
  Future<void> play(Uri uri);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioAthkarPlayer implements AthkarPlayer {
  AudioPlayer? _player;

  @override
  Future<void> play(Uri uri) async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    await player.setAudioSource(AudioSource.uri(uri));
    unawaited(player.play());
    await player.processingStateStream.firstWhere(
      (s) => s == ProcessingState.completed || s == ProcessingState.idle,
    );
  }

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

final athkarPlayerFactoryProvider = Provider<AthkarPlayer Function()>(
  (ref) => JustAudioAthkarPlayer.new,
);

/// What is playing: the audio file (a zikr's or a category's), `null`:
/// nothing.
class AthkarAudioController extends Notifier<String?> {
  AthkarPlayer? _player;

  @override
  String? build() {
    ref.onDispose(() => unawaited(_player?.dispose()));
    return null;
  }

  /// Plays [file] — or stops it, if it is the one playing. `false` when
  /// it could not be played (offline).
  Future<bool> toggle(String file) async {
    if (state == file) {
      await stop();
      return true;
    }
    final player = _player ??= ref.read(athkarPlayerFactoryProvider)();
    // Not over the reciter.
    if (ref.read(reciterAyahProvider) != null) {
      await ref.read(quranAudioPlayerProvider.notifier).stop();
    }
    state = file;
    var played = true;
    try {
      await player.play(athkarAudioUri(file));
    } on Object {
      played = false;
    }
    if (ref.mounted && state == file) state = null;
    return played;
  }

  Future<void> stop() async {
    state = null;
    await _player?.stop();
  }
}

final athkarAudioProvider =
    NotifierProvider.autoDispose<AthkarAudioController, String?>(
      AthkarAudioController.new,
    );
