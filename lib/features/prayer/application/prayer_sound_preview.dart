import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../athkar/application/athkar_audio.dart'
    show AthkarPlayer, athkarPlayerFactoryProvider;
import '../../listen/application/quran_audio_player.dart';
import '../data/prayer_sounds.dart';

/// The adhan heard before choosing it (its first 30 s): the id playing,
/// `null`: none.
class PrayerSoundPreview extends Notifier<String?> {
  AthkarPlayer? _player;

  @override
  String? build() {
    ref.onDispose(() => unawaited(_player?.dispose()));
    return null;
  }

  /// Plays adhan [id] — or stops it, if it is the one playing.
  Future<void> toggle(String id) async {
    if (state == id) return stop();
    final player = _player ??= ref.read(athkarPlayerFactoryProvider)();
    // Not over the reciter.
    if (ref.read(reciterAyahProvider) != null) {
      await ref.read(quranAudioPlayerProvider.notifier).stop();
    }
    state = id;
    try {
      await player.play(Uri.parse('asset:///${adhanPreviewAsset(id)}'));
    } on Object {
      // (Nothing heard: the row's button back as it was.)
    }
    if (ref.mounted && state == id) state = null;
  }

  Future<void> stop() async {
    state = null;
    await _player?.stop();
  }
}

final prayerSoundPreviewProvider =
    NotifierProvider.autoDispose<PrayerSoundPreview, String?>(
      PrayerSoundPreview.new,
    );
