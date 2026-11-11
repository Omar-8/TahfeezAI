import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_models.dart';
import '../../../core/core_providers.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../memorization/application/activity_stats.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/mushaf_focus_ayah.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../../quran/application/meaning_defaults.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/application/recitation_session_controller.dart';
import '../data/word_timings_repository.dart';
import '../domain/quran_audio_sources.dart';
import '../domain/word_timings.dart';
import 'listen_options.dart';
import 'reciter_downloads.dart';
import 'reciter_controller.dart';

/// What is playing: a run of ayahs (one is current) by a reciter, or a
/// single word.
class NowPlaying {
  const NowPlaying.ayahs(
    this.ayahIds,
    this.index,
    this.reciter, {
    this.options = const ListenOptions(highlight: false, followPages: false),
    this.translations = const {},
    this.basmalas = const {},
  }) : word = null;

  const NowPlaying.word(int ayahId, int wordIndex)
    : ayahIds = const [],
      index = 0,
      reciter = null,
      options = const ListenOptions(),
      translations = const {},
      basmalas = const {},
      word = (ayahId: ayahId, wordIndex: wordIndex);

  /// The ayahs in play order, repetitions included.
  final List<int> ayahIds;
  final int index;
  final Reciter? reciter;
  final ListenOptions options;
  final ({int ayahId, int wordIndex})? word;

  /// The places in [ayahIds] that are the ayah before them translated
  /// (read aloud after it), not recited.
  final Set<int> translations;

  /// The places in [ayahIds] that are the Bismillah before the surah's
  /// first ayah (the place's id): Al-Husary's, for the reciters whose first
  /// ayahs start without it.
  final Set<int> basmalas;

  bool get isWord => word != null;

  /// The Bismillah before a surah is playing (its first ayah's id).
  bool get isBasmala => basmalas.contains(index);

  /// Its ayah's translation is playing, not the ayah.
  bool get isTranslation => translations.contains(index);

  /// Recited ayahs (not translations, nor a Bismillah) from place [from]
  /// up to [to].
  int recitedBetween(int from, int to) => [
    for (var k = from; k < to; k++)
      if (!translations.contains(k) && !basmalas.contains(k)) k,
  ].length;
  int? get ayahId => isWord ? null : ayahIds[index];

  NowPlaying at(int i) => NowPlaying.ayahs(
    ayahIds,
    i,
    reciter,
    options: options,
    translations: translations,
    basmalas: basmalas,
  );
}

/// Streams Quran audio (`docs/AUDIO_MILESTONE.md`) through the app's audio
/// controller: ayahs one after another, or a word. The playing ayah is
/// highlighted on its Mushaf page; a recitation test starting stops it.
class QuranAudioPlayer extends Notifier<NowPlaying?> {
  StreamSubscription<AudioPlaybackState>? _sub;

  /// Each playback asked for, counted: one replaced by a newer one while it
  /// was loading fails (its loading cut short) — not for want of a network,
  /// and the newer one plays (owner, 2026-11-10: "Audio needs an internet
  /// connection" on Wi-Fi, then the audio played).
  int _attempt = 0;

  final _finished = StreamController<NowPlaying>.broadcast(sync: true);

  /// Each run of ayahs that played to its end (not stopped), as it ends.
  Stream<NowPlaying> get finished => _finished.stream;

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
    // Hide mode turned on while an ayah plays: it and what came before it
    // on its page stay shown.
    ref.listen(mushafHideModeProvider, (previous, next) {
      if (next.enabled && !(previous?.enabled ?? false)) _revealPlaying();
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
    // The player reports the previous item's end until the new one loads:
    // only an end seen after this one started is its end.
    if (!playback.completed) _started = true;
    if (playback.isPlaying) _played = true;
    // Stopped from outside the app (the media notification): cleared too.
    if (playback.stopped && _played) {
      _clear();
      return;
    }
    if (playback.completed && _started) {
      final last = now.isWord ? null : now.ayahIds.last;
      if (!now.isWord) {
        if (!now.isTranslation) {
          ref.read(activityStatsProvider.notifier).add(heardAyahs: 1);
        }
        _finished.add(now);
      }
      _clear();
      // Going on: the next surah, whole, with the same options.
      if (last != null && now.options.continueToNextSurahs) {
        final surah = last ~/ 1000;
        final atSurahEnd = last % 1000 == surahAyahCounts[surah - 1];
        if (atSurahEnd && surah < 114) {
          final next = surah + 1;
          unawaited(
            playRange(
              next * 1000 + 1,
              next * 1000 + surahAyahCounts[next - 1],
              options: now.options,
            ),
          );
        }
      }
      return;
    }
    final i = playback.currentIndex;
    if (!now.isWord && i != null && i != now.index && i < now.ayahIds.length) {
      // The ayahs before it were heard through (translations not counted).
      if (i > now.index) {
        final heard = now.recitedBetween(now.index, i);
        if (heard > 0) {
          ref.read(activityStatsProvider.notifier).add(heardAyahs: heard);
        }
      }
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
    // The Bismillah before a surah: its page turned to, its first ayah
    // neither highlighted nor uncovered yet.
    final basmala = now?.isBasmala ?? false;
    if (ayahId == null || !now!.options.highlight || basmala) {
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
      // Turned to once per page — and again whenever the page on screen is
      // another (the reader went elsewhere since, by hand).
      final shown = ref.read(mushafRecitationTargetProvider)?.location;
      final shownPage = shown is QuranLocationPage ? shown.pageNumber : null;
      if (follow && (page != _turnedTo || page != shownPage)) {
        _turnedTo = page;
        ref.read(mushafPageTurnRequestsProvider.notifier).toPage(page);
      }
      if (!basmala) _reveal(page, ayahId);
    }());
  }

  int? _turnedTo;

  /// Whether what is playing now has been seen loading or playing (so a
  /// "completed" is its own, not the previous item's).
  var _started = false;

  /// Whether what is playing now has actually played (so "stopped" is a
  /// stop, not the player's state before loading it).
  var _played = false;

  /// Hide mode: uncovers the playing ayah's page through it.
  void _revealPlaying() {
    final ayahId = state?.ayahId;
    if (ayahId == null) return;
    unawaited(() async {
      final mushaf = await ref.read(defaultMushafProvider.future);
      if (mushaf == null || !ref.mounted) return;
      final page = await ref
          .read(quranRepositoryProvider)
          .getPageForAyah(mushafId: mushaf.id, ayahId: ayahId);
      if (page != null && ref.mounted && state?.ayahId == ayahId) {
        _reveal(page, ayahId);
      }
    }());
  }

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

  /// A word playing during a recitation: recognition hears silence, so
  /// the reciter is not taken for the reader (the mic and session go on).
  void _muteRecognition(bool mute) {
    final session = ref.read(recitationSessionControllerProvider.notifier);
    session.appAudioPlaying =
        mute && ref.read(recitationSessionControllerProvider).isActive;
  }

  void _clear() {
    _muteRecognition(false);
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
    final attempt = ++_attempt;
    final reciter = reciterFor(ref.read(reciterProvider));
    // A translation chosen: each ayah, then its translation read aloud.
    final voice = translationVoiceFor(options.translationVoice);
    // A surah's first ayah, as it starts (not its repetitions): the
    // Bismillah first, Al-Husary's, for the reciters whose first ayahs
    // start without it (all but three — measured 2026-11-06), except
    // Al-Fātiḥah's (its first ayah is the Bismillah) and At-Tawbah.
    final basmala = !reciterRecitesBasmala.contains(reciter.edition);
    final queue = <int>[];
    final translations = <int>{}, basmalas = <int>{};
    for (final (k, a) in ayahIds.indexed) {
      final surah = a ~/ 1000;
      if (basmala &&
          a % 1000 == 1 &&
          surah != 1 &&
          surah != 9 &&
          (k == 0 || ayahIds[k - 1] != a)) {
        basmalas.add(queue.length);
        queue.add(a);
      }
      queue.add(a);
      if (voice != null) {
        translations.add(queue.length);
        queue.add(a);
      }
    }
    _started = false;
    _played = false;
    state = NowPlaying.ayahs(
      queue,
      0,
      reciter,
      options: options,
      translations: translations,
      basmalas: basmalas,
    );
    _follow();
    try {
      final audio = ref.read(audioControllerProvider);
      // A downloaded reciter plays from the device (offline too).
      final downloads = ref.read(reciterDownloadsProvider.notifier);
      await downloads.ready();
      // The speed last chosen, wherever it was.
      await audio.setSpeed(ref.read(listenSpeedProvider));
      await audio.playQueue(
        [
          for (final (k, a) in queue.indexed)
            if (translations.contains(k))
              translationAudioUrl(a, voice!)
            else if (basmalas.contains(k))
              switch (downloads.localFile(1001, basmalaReciter)) {
                final path? => Uri.file(path).toString(),
                null => ayahAudioUrl(1001, basmalaReciter),
              }
            else
              switch (downloads.localFile(a, reciter)) {
                final path? => Uri.file(path).toString(),
                null => ayahAudioUrl(a, reciter),
              },
        ],
        items: [
          for (final (k, a) in queue.indexed)
            _info(
              a,
              basmalas.contains(k) ? basmalaReciter : reciter,
              translation: translations.contains(k) ? voice : null,
            ),
        ],
      );
      return true;
    } catch (_) {
      // Replaced by a newer playback meanwhile (its loading cut short):
      // not a failure — that one plays.
      if (attempt != _attempt) return true;
      _clear();
      return false;
    }
  }

  /// [ayahId] as the media notification shows it: "Al-Baqara · 255", by
  /// the reciter (names in the app's language).
  AudioItemInfo _info(
    int ayahId,
    Reciter reciter, {
    TranslationVoice? translation,
  }) {
    final surahNo = ayahId ~/ 1000;
    // (The surah names once loaded — a Mushaf open has them.)
    final names = ref.exists(indexedSurahsProvider)
        ? ref.read(indexedSurahsProvider).value
        : null;
    final surah = [
      for (final s in names ?? const <IndexedSurah>[])
        if (s.surah.surahNo == surahNo) s.localizedName ?? s.arabicName,
    ].firstOrNull;
    final language = ref.read(localeControllerProvider)?.languageCode;
    return AudioItemInfo(
      title: '${surah ?? surahNo} · ${ayahId % 1000}',
      subtitle: translation != null
          ? translation.reader
          : language != null && usesArabicScript(language)
          ? reciter.nameAr
          : reciter.nameEn,
      // The media session shows the run as its surah, the ayah playing,
      // and the whole length (from the files' sizes at their bitrate).
      group: '${surah ?? surahNo}',
      part: '${ayahId % 1000}',
      kbps: translation?.kbps ?? reciter.bitrate,
    );
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

  /// The next of [listenSpeeds] after [current], kept for next time.
  Future<void> cycleSpeed(double current) {
    final i = listenSpeeds.indexWhere((s) => (s - current).abs() < 0.01);
    final next = listenSpeeds[(i + 1) % listenSpeeds.length];
    ref.read(listenSpeedProvider.notifier).set(next);
    return ref.read(audioControllerProvider).setSpeed(next);
  }

  /// One word, as Quran.com recites it alone.
  Future<bool> playWord(int ayahId, int wordIndex) async {
    final attempt = ++_attempt;
    ref.read(mushafFocusAyahProvider.notifier).clear(this);
    _started = false;
    _played = false;
    state = NowPlaying.word(ayahId, wordIndex);
    _muteRecognition(true);
    try {
      await ref
          .read(audioControllerProvider)
          .playUrl(wordAudioUrl(ayahId, wordIndex));
      return true;
    } catch (_) {
      if (attempt != _attempt) return true; // (replaced: see playAyahs)
      _clear();
      return false;
    }
  }

  /// A recitation mistake's correction: word [wordIndex] of [ayahId] as the
  /// chosen reciter recites it, with the next word (and the one before
  /// when [fromPrevious]) — [correctionClip]. A reciter without word
  /// timings, or a word without one, gets the word alone ([playWord]).
  Future<CorrectionPlayback> playCorrection(
    int ayahId,
    int wordIndex, {
    bool fromPrevious = false,
  }) async {
    final reciter = reciterFor(ref.read(reciterProvider));
    WordSpan? clip;
    AyahWordTimings? timings;
    try {
      timings = await ref
          .read(wordTimingsRepositoryProvider)
          .timings(reciter.edition, ayahId);
      if (timings != null) {
        clip = correctionClip(
          timings,
          quranComWordPosition(ayahId, wordIndex),
          fromPrevious: fromPrevious,
        );
      }
    } catch (_) {
      // Not fetched (offline, or the service down): the word alone, which
      // says offline itself if it is.
    }
    if (clip == null) {
      return await playWord(ayahId, wordIndex)
          ? CorrectionPlayback.wordAlone
          : CorrectionPlayback.failed;
    }
    final attempt = ++_attempt;
    ref.read(mushafFocusAyahProvider.notifier).clear(this);
    _started = false;
    _played = false;
    state = NowPlaying.word(ayahId, wordIndex);
    _muteRecognition(true);
    try {
      final audio = ref.read(audioControllerProvider);
      final downloads = ref.read(reciterDownloadsProvider.notifier);
      await downloads.ready();
      await audio.setSpeed(ref.read(listenSpeedProvider));
      await audio.playClip(
        // A reciter timed by surah: cut from that surah's recording.
        timings?.surahUrl ??
            switch (downloads.localFile(ayahId, reciter)) {
              final path? => Uri.file(path).toString(),
              null => ayahAudioUrl(ayahId, reciter),
            },
        Duration(milliseconds: clip.startMs),
        Duration(milliseconds: clip.endMs),
        info: _info(ayahId, reciter),
      );
      return CorrectionPlayback.reciter;
    } catch (_) {
      // (Replaced: see playAyahs.)
      if (attempt != _attempt) return CorrectionPlayback.reciter;
      _clear();
      return CorrectionPlayback.failed;
    }
  }

  Future<void> stop() async {
    _clear();
    await ref.read(audioControllerProvider).stop();
  }
}

/// How a correction played: cut from the reciter's ayah, the word alone
/// (no timings), or not at all (offline).
enum CorrectionPlayback { reciter, wordAlone, failed }

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
