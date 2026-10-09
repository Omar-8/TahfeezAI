import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_models.dart';
import '../../../core/core_providers.dart';
import '../../mushaf/application/mushaf_focus_ayah.dart';
import '../../recitation/application/recitation_session_controller.dart';
import '../domain/quran_audio_sources.dart';
import 'reciter_controller.dart';

/// What is playing: a run of ayahs (one is current) by a reciter, or a
/// single word.
class NowPlaying {
  const NowPlaying.ayahs(this.ayahIds, this.index, this.reciter) : word = null;

  const NowPlaying.word(int ayahId, int wordIndex)
    : ayahIds = const [],
      index = 0,
      reciter = null,
      word = (ayahId: ayahId, wordIndex: wordIndex);

  final List<int> ayahIds;
  final int index;
  final Reciter? reciter;
  final ({int ayahId, int wordIndex})? word;

  bool get isWord => word != null;
  int? get ayahId => isWord ? null : ayahIds[index];

  NowPlaying at(int i) => NowPlaying.ayahs(ayahIds, i, reciter);
}

/// Streams Quran audio (`docs/AUDIO_MILESTONE.md`) through the app's audio
/// controller: ayahs one after another, or a word. The playing ayah is
/// highlighted on its Mushaf page; a recitation test starting stops it.
class QuranAudioPlayer extends Notifier<NowPlaying?> {
  StreamSubscription<AudioPlaybackState>? _sub;

  @override
  NowPlaying? build() {
    final controller = ref.watch(audioControllerProvider);
    _sub?.cancel();
    _sub = controller.state.listen(_onPlayback);
    ref.onDispose(() => _sub?.cancel());
    // The microphone is the recitation test's: stop listening when one
    // starts.
    ref.listen(recitationSessionControllerProvider, (previous, next) {
      if (next.isActive && !(previous?.isActive ?? false)) stop();
    });
    return null;
  }

  void _onPlayback(AudioPlaybackState playback) {
    final now = state;
    if (now == null) return;
    if (playback.completed) {
      _clear();
      return;
    }
    final i = playback.currentIndex;
    if (!now.isWord && i != null && i != now.index && i < now.ayahIds.length) {
      state = now.at(i);
      _focus();
    }
  }

  void _focus() {
    final ayahId = state?.ayahId;
    final focus = ref.read(mushafFocusAyahProvider.notifier);
    if (ayahId == null) {
      focus.clear(this);
    } else {
      focus.focus(this, ayahId);
    }
  }

  void _clear() {
    state = null;
    ref.read(mushafFocusAyahProvider.notifier).clear(this);
  }

  /// Plays [ayahIds] in order by the chosen reciter. `false` when the audio
  /// couldn't be reached (offline).
  Future<bool> playAyahs(List<int> ayahIds) async {
    if (ayahIds.isEmpty) return false;
    final reciter = reciterFor(ref.read(reciterProvider));
    state = NowPlaying.ayahs(ayahIds, 0, reciter);
    _focus();
    try {
      await ref.read(audioControllerProvider).playQueue([
        for (final a in ayahIds) ayahAudioUrl(a, reciter),
      ]);
      return true;
    } catch (_) {
      _clear();
      return false;
    }
  }

  /// From [ayahId] to the end of its surah.
  Future<bool> playFrom(int ayahId) {
    final surah = ayahId ~/ 1000;
    final last = surahAyahCounts[surah - 1];
    return playAyahs([
      for (var v = ayahId % 1000; v <= last; v++) surah * 1000 + v,
    ]);
  }

  /// One word, as Quran.com recites it alone.
  Future<bool> playWord(int ayahId, int wordIndex) async {
    ref.read(mushafFocusAyahProvider.notifier).clear(this);
    state = NowPlaying.word(ayahId, wordIndex);
    try {
      await ref
          .read(audioControllerProvider)
          .playUrl(wordAudioUrl(ayahId, wordIndex));
      return true;
    } catch (_) {
      _clear();
      return false;
    }
  }

  Future<void> stop() async {
    if (state == null) return;
    _clear();
    await ref.read(audioControllerProvider).stop();
  }
}

final quranAudioPlayerProvider =
    NotifierProvider<QuranAudioPlayer, NowPlaying?>(QuranAudioPlayer.new);
