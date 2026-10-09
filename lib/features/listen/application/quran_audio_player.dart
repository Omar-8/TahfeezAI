import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_models.dart';
import '../../../core/core_providers.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/mushaf_focus_ayah.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/application/recitation_session_controller.dart';
import '../domain/quran_audio_sources.dart';
import 'listen_options.dart';
import 'reciter_controller.dart';

/// What is playing: a run of ayahs (one is current) by a reciter, or a
/// single word.
class NowPlaying {
  const NowPlaying.ayahs(
    this.ayahIds,
    this.index,
    this.reciter, {
    this.options = const ListenOptions(highlight: false, followPages: false),
  }) : word = null;

  const NowPlaying.word(int ayahId, int wordIndex)
    : ayahIds = const [],
      index = 0,
      reciter = null,
      options = const ListenOptions(),
      word = (ayahId: ayahId, wordIndex: wordIndex);

  /// The ayahs in play order, repetitions included.
  final List<int> ayahIds;
  final int index;
  final Reciter? reciter;
  final ListenOptions options;
  final ({int ayahId, int wordIndex})? word;

  bool get isWord => word != null;
  int? get ayahId => isWord ? null : ayahIds[index];

  NowPlaying at(int i) =>
      NowPlaying.ayahs(ayahIds, i, reciter, options: options);
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
    // Its controls are the Mushaf's bar: leaving the Mushaf stops it.
    ref.listen(mushafRecitationTargetProvider, (previous, next) {
      if (previous != null && next == null) stop();
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
      _follow();
    }
  }

  /// The ayah now recited: highlighted, its page turned to, and — in hide
  /// mode — uncovered, as the options say.
  void _follow() {
    final now = state;
    final ayahId = now?.ayahId;
    final focus = ref.read(mushafFocusAyahProvider.notifier);
    if (ayahId == null || !now!.options.highlight) {
      focus.clear(this);
    } else {
      focus.focus(this, ayahId);
    }
    if (ayahId == null) return;
    final follow = now!.options.followPages;
    final hide = ref.read(mushafHideModeProvider);
    if (!follow && !hide.enabled) return;
    unawaited(() async {
      final mushaf = await ref.read(defaultMushafProvider.future);
      if (mushaf == null || !ref.mounted) return;
      final page = await ref
          .read(quranRepositoryProvider)
          .getPageForAyah(mushafId: mushaf.id, ayahId: ayahId);
      if (page == null || !ref.mounted || state?.ayahId != ayahId) return;
      if (follow && page != _turnedTo) {
        _turnedTo = page;
        ref.read(mushafPageTurnRequestsProvider.notifier).toPage(page);
      }
      _reveal(page, ayahId);
    }());
  }

  int? _turnedTo;

  /// Hide mode: uncovers [page] through [ayahId] as it is recited.
  void _reveal(int page, int ayahId) {
    final hide = ref.read(mushafHideModeProvider);
    if (!hide.enabled) return;
    final first = ref.read(mushafPageVersesProvider)[page]?.first;
    final ends = hide.ayahBoundaries[page];
    if (first == null || ends == null || ends.isEmpty) return;
    final k =
        globalAyahNumber(ayahId) -
        globalAyahNumber(first.chapterNo * 1000 + first.verseNo);
    if (k < 0 || k >= ends.length) return;
    if (hide.revealedOn(page) >= ends[k]) return;
    ref.read(mushafHideModeProvider.notifier).setRevealed({page: ends[k]});
  }

  void _clear() {
    state = null;
    _turnedTo = null;
    ref.read(mushafFocusAyahProvider.notifier).clear(this);
  }

  /// Plays [ayahIds] in order by the chosen reciter, as [options] say.
  /// `false` when the audio couldn't be reached (offline).
  Future<bool> playAyahs(
    List<int> ayahIds, {
    ListenOptions options = const ListenOptions(
      highlight: false,
      followPages: false,
    ),
  }) async {
    if (ayahIds.isEmpty) return false;
    final reciter = reciterFor(ref.read(reciterProvider));
    state = NowPlaying.ayahs(ayahIds, 0, reciter, options: options);
    _follow();
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
    return playRange(ayahId, surah * 1000 + surahAyahCounts[surah - 1]);
  }

  /// [from] through [to] (stable ids, across surahs), each ayah and the
  /// whole range repeated as [options] (default: the Listen menu's) say.
  Future<bool> playRange(int from, int to, {ListenOptions? options}) {
    final ListenOptions o = options ?? ref.read(listenOptionsProvider);
    final range = ayahRange(from, to);
    return playAyahs([
      for (var r = 0; r < o.rangeRepeats; r++)
        for (final a in range)
          for (var e = 0; e < o.ayahRepeats; e++) a,
    ], options: o);
  }

  Future<void> pause() => ref.read(audioControllerProvider).pause();
  Future<void> resume() => ref.read(audioControllerProvider).resume();

  /// The next of [listenSpeeds] after [current].
  Future<void> cycleSpeed(double current) {
    final i = listenSpeeds.indexWhere((s) => (s - current).abs() < 0.01);
    final next = listenSpeeds[(i + 1) % listenSpeeds.length];
    return ref.read(audioControllerProvider).setSpeed(next);
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
    _clear();
    await ref.read(audioControllerProvider).stop();
  }
}

/// When the offline message was last shown, so repeated taps while offline
/// show it once in a while rather than stacking.
DateTime? _offlineShownAt;

/// "Audio needs an internet connection", replacing any message showing, at
/// most once every few seconds.
void showListenOffline(ScaffoldMessengerState messenger, String message) {
  final now = DateTime.now();
  final last = _offlineShownAt;
  if (last != null && now.difference(last) < const Duration(seconds: 4)) {
    return;
  }
  _offlineShownAt = now;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

final quranAudioPlayerProvider =
    NotifierProvider<QuranAudioPlayer, NowPlaying?>(QuranAudioPlayer.new);
