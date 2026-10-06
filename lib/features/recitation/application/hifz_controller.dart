import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/acoustic/acoustic_frame_stream.dart';
import '../../../ai/hifz/hifz_judge.dart';
import '../../../ai/matching/local_quran_position_tracker.dart';
import '../../../ai/matching/quran_stream_matcher.dart';
import '../../../ai/matching/recitation_position_matcher.dart';
import '../../../ai/matching/quran_word_corpus.dart';
import '../../../ai/speech/live_quran_recognizer.dart';
import '../../../core/core_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import 'acoustic_position_providers.dart';
import 'acoustic_verification_controller.dart';
import 'local_acoustic_inference_controller.dart';
import 'recitation_ai_config.dart';
import 'recitation_position.dart';
import 'live_recognition_controller.dart';
import 'mushaf_recitation_target.dart';
import 'quran_match_controller.dart' show quranWordCorpusProvider;
import 'recitation_session_controller.dart';

/// Configurable Hifz feedback.
class HifzSettings {
  const HifzSettings({
    this.strict = true,
    this.highlightCurrent = true,
    this.showMistakes = true,
    this.vibrate = true,
    this.colorWords = true,
  });

  /// Mistakes hold the test until corrected (see [HifzConfig.strict]).
  final bool strict;

  /// Mark where the next word is.
  final bool highlightCurrent;

  /// Mark wrong, skipped and uncertain words.
  final bool showMistakes;

  /// Vibrate on a mistake (Android).
  final bool vibrate;

  /// Colour recited words: correct green, skipped yellow, wrong red.
  final bool colorWords;

  HifzSettings copyWith({
    bool? strict,
    bool? highlightCurrent,
    bool? showMistakes,
    bool? vibrate,
    bool? colorWords,
  }) => HifzSettings(
    strict: strict ?? this.strict,
    highlightCurrent: highlightCurrent ?? this.highlightCurrent,
    showMistakes: showMistakes ?? this.showMistakes,
    vibrate: vibrate ?? this.vibrate,
    colorWords: colorWords ?? this.colorWords,
  );

  Map<String, bool> toJson() => {
    'strict': strict,
    'highlightCurrent': highlightCurrent,
    'showMistakes': showMistakes,
    'vibrate': vibrate,
    'colorWords': colorWords,
  };

  static HifzSettings fromJson(Object? json) {
    if (json is! Map) return const HifzSettings();
    bool read(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    return HifzSettings(
      strict: read('strict', true),
      highlightCurrent: read('highlightCurrent', true),
      showMistakes: read('showMistakes', true),
      vibrate: read('vibrate', true),
      colorWords: read('colorWords', true),
    );
  }
}

class HifzSettingsController extends Notifier<HifzSettings> {
  static const storageKey = 'hifz.settings.v1';

  @override
  HifzSettings build() {
    unawaited(_restore());
    return const HifzSettings();
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(browserStorageProvider).getString(storageKey);
      if (raw != null && ref.mounted) {
        state = HifzSettings.fromJson(jsonDecode(raw));
      }
    } catch (_) {
      // Defaults.
    }
  }

  void update(HifzSettings settings) {
    state = settings;
    unawaited(
      ref
          .read(browserStorageProvider)
          .setString(storageKey, jsonEncode(settings.toJson())),
    );
  }
}

final hifzSettingsProvider =
    NotifierProvider<HifzSettingsController, HifzSettings>(
      HifzSettingsController.new,
    );

/// Vibrates on a mistake; overridden in tests.
final hifzHapticsProvider = Provider<void Function()>((ref) {
  final android = ref.watch(platformCapabilitiesProvider).isAndroid;
  return android ? () => unawaited(HapticFeedback.vibrate()) : () {};
});

/// A chosen memorization range (whole ayahs, inclusive).
typedef HifzRange = ({VerseRef from, VerseRef to});

class HifzState {
  const HifzState({
    this.range,
    this.running = false,
    this.first,
    this.last,
    this.revealed = const {},
    this.marked = const {},
    this.expected,
    this.reviewing,
    this.pending,
    this.counts = const {},
    this.recent = const [],
    this.completed = false,
  });

  /// The range chosen, or `null` for "from the visible page to the end of
  /// its surah".
  final HifzRange? range;

  /// A session is testing right now.
  final bool running;

  /// First and last word of the range being (or last) tested; `null` when
  /// no test has started.
  final WordRef? first, last;
  final Set<WordRef> revealed;
  final Map<WordRef, HifzVerdict> marked;

  /// The next word the reciter should say.
  final WordRef? expected;

  /// While going back over recited words: the next word of that review.
  final WordRef? reviewing;

  /// A mistake on [expected] awaiting correction.
  final HifzVerdict? pending;
  final Map<HifzVerdict, int> counts;

  /// The latest few judgements, newest last.
  final List<HifzEvent> recent;
  final bool completed;

  /// Whether a test's masks are on the page (running or just finished).
  bool get active => first != null && last != null;

  bool isHidden(WordRef ref) =>
      active &&
      compareWordRefs(ref, first!) >= 0 &&
      compareWordRefs(ref, last!) <= 0 &&
      !revealed.contains(ref);

  HifzState copyWith({HifzRange? Function()? range, bool? running}) =>
      HifzState(
        range: range == null ? this.range : range(),
        running: running ?? this.running,
        first: first,
        last: last,
        revealed: revealed,
        marked: marked,
        expected: expected,
        pending: pending,
        counts: counts,
        recent: recent,
        completed: completed,
      );
}

/// Milestone R5: Live Hifz Mode — a memorization test over live
/// recitation. Every recitation session is a test: a [HifzJudge] tracks
/// the expected word and every mistake. With hide mode on, the words
/// ahead are hidden and each is revealed as it is recited; with the page
/// visible, only the next word is highlighted. Hide mode's reveal/hide
/// buttons drive the test while it runs.
class HifzController extends Notifier<HifzState> {
  /// Follows the reciter: from recognized text ([QuranStreamMatcher]) or,
  /// on the device, from acoustic frames ([LocalQuranPositionTracker]).
  RecitationPositionMatcher? _matcher;
  HifzJudge? _judge;
  QuranWordCorpus? _corpus;
  StreamSubscription<LiveRecognitionEvent>? _recognition;
  StreamSubscription<TimedAcousticFrames>? _frames;
  LocalAcousticInferenceController? _inference;
  PhonemeResources? _phonemes;
  bool _acousticPosition = false;
  String? _sessionId;
  bool _listening = false;
  int? _turnedFor;

  /// With the page visible the reciter may start anywhere: the test begins
  /// once the matcher has located them.
  bool _locating = false;

  @override
  HifzState build() {
    ref.onDispose(() {
      unawaited(_recognition?.cancel());
      unawaited(_frames?.cancel());
    });
    ref.listen(quranWordCorpusProvider, (_, next) {
      _corpus = next.value;
    }, fireImmediately: true);
    ref.listen(recitationSessionControllerProvider, (_, next) {
      _onSession(next);
    });
    ref.listen(hifzSettingsProvider, (_, _) => _updateOverlay());
    // Share the reciter's position (see recitationPositionProvider).
    listenSelf((_, next) {
      ref
          .read(recitationPositionProvider.notifier)
          .set(
            next.running || next.completed ? next.expected ?? next.last : null,
          );
    });
    // Pronunciation verdicts from the acoustic verifier colour words too.
    ref.listen(acousticVerificationControllerProvider, (previous, next) {
      if (!identical(previous?.words, next.words)) _updateOverlay();
    });
    ref.listen(mushafHideModeProvider, (previous, next) {
      if (previous?.enabled == next.enabled) return;
      // Turning hide mode on or off clears a finished recitation's colours.
      if (_results) {
        _results = false;
        _judge = null;
        ref.read(mushafWordOverlayProvider.notifier).set(null);
      }
      _updateOverlay();
    });
    // Turning pages by hand: listen for the reciter on the new page(s).
    ref.listen(mushafRecitationTargetProvider, (_, _) => _onPagesChanged());
    ref.listen(mushafPageWordRangesProvider, (_, _) => _onPagesChanged());
    ref.listen(fullBleedContentProvider, (_, _) => _onPagesChanged());
    _acousticPosition =
        ref.watch(recitationAiConfigProvider).position ==
        RecitationPositionSource.acoustic;
    if (_acousticPosition) {
      // On the device: the reciter is followed from the acoustic frames.
      ref.listen(quranPhonemeResourcesProvider, (_, next) {
        _phonemes = next.value;
      }, fireImmediately: true);
      final inference = ref.watch(
        localAcousticInferenceControllerProvider.notifier,
      );
      _inference = inference;
      _frames = inference.frames.listen(_onFrames);
    } else {
      final recognition = ref.watch(liveRecognitionControllerProvider.notifier);
      _recognition = recognition.events.listen(_onRecognition);
    }
    return const HifzState();
  }

  void setRange(HifzRange? range) => state = state.copyWith(range: () => range);

  /// Reveals the expected word (or the rest of its ayah) without it being
  /// recited — it counts as skipped.
  void revealNext({bool wholeAyah = false}) {
    final judge = _judge;
    if (judge == null) return;
    _publish(judge.revealManually(wholeAyah: wholeAyah));
    _followPage();
  }

  /// Hides the last revealed word (or back to the start of its ayah) and
  /// expects it next.
  void hideBack({bool wholeAyah = false}) {
    final judge = _judge;
    if (judge == null || !judge.hideBack(wholeAyah: wholeAyah)) return;
    _turnedFor = null;
    _publish(const []);
    _followPage();
  }

  /// A finished test's colours are still on the page (until hide mode is
  /// toggled or the next recitation starts).
  bool _results = false;

  /// Ends the test, carrying its progress into hide mode. The recited
  /// words keep their colours — verdicts still arriving for its last words
  /// included — while the page is otherwise back to normal.
  void _clear() {
    _syncToHideMode();
    _matcher = null;
    _locating = false;
    state = HifzState(range: state.range);
    _results = _judge != null && ref.read(hifzSettingsProvider).colorWords;
    if (_results) {
      _updateOverlay();
    } else {
      _judge = null;
      ref.read(mushafWordOverlayProvider.notifier).set(null);
    }
  }

  /// Pushes the test onto the page: the next word marked and, with hide
  /// mode on, the range hidden except the words revealed.
  void _updateOverlay() {
    final s = state;
    if (_results) {
      _showResults();
      return;
    }
    if (!s.active) return;
    final settings = ref.read(hifzSettingsProvider);
    final expected = s.expected;
    // Recited words coloured by how they went; the word to recite next
    // marked with a band — red while a mistake on it awaits correction.
    final judge = _judge;
    final review = judge?.reviewing;
    final reviewing = review == null ? null : judge!.corpus.words[review].ref;
    final acoustic = ref.read(acousticVerificationControllerProvider).words;
    final marks = <WordRef, MushafWordMark>{
      if (settings.colorWords && judge != null)
        for (final p in judge.revealed)
          if (!judge.given.contains(p))
            judge.corpus.words[p].ref: switch (judge.marked[p]) {
              HifzVerdict.skipped => MushafWordMark.skipped,
              HifzVerdict.wrong ||
              HifzVerdict.selfCorrected => MushafWordMark.wrong,
              // The right word — was it pronounced right? (acoustic check)
              // Only a mistake is marked: "uncertain" (the on-device model
              // could not tell) was a fifth of a good reciter's words on
              // the phone — noise, not feedback.
              _ => _pronunciationMark(acoustic[judge.corpus.words[p].ref]),
            },
      // Going back over revealed words: the band follows the reciter.
      if (reviewing != null && settings.highlightCurrent)
        reviewing: MushafWordMark.current
      else if (expected != null && s.pending != null && settings.showMistakes)
        expected: MushafWordMark.mistake
      else if (expected != null && settings.highlightCurrent)
        expected: MushafWordMark.current,
    };
    ref
        .read(mushafWordOverlayProvider.notifier)
        .set(
          MushafWordOverlay(
            first: s.first!,
            last: s.last!,
            revealed: s.revealed,
            marks: marks,
            hideUnrevealed: ref.read(mushafHideModeProvider).enabled,
          ),
        );
  }

  /// A recited word's colour from its pronunciation check.
  static MushafWordMark _pronunciationMark(AcousticWordResult? a) =>
      a != null && a.isMistake
      ? MushafWordMark.tashkeel
      : MushafWordMark.correct;

  /// A finished test's colours: every recited word as it went, no band on
  /// a next word, and the page hidden only as hide mode hides it.
  void _showResults() {
    final judge = _judge;
    if (judge == null) return;
    final corpus = judge.corpus;
    final acoustic = ref.read(acousticVerificationControllerProvider).words;
    ref
        .read(mushafWordOverlayProvider.notifier)
        .set(
          MushafWordOverlay(
            first: corpus.words[judge.start].ref,
            last: corpus.words[judge.end].ref,
            marks: {
              for (final p in judge.revealed)
                if (!judge.given.contains(p))
                  corpus.words[p].ref: switch (judge.marked[p]) {
                    HifzVerdict.skipped => MushafWordMark.skipped,
                    HifzVerdict.wrong ||
                    HifzVerdict.selfCorrected => MushafWordMark.wrong,
                    _ => _pronunciationMark(acoustic[corpus.words[p].ref]),
                  },
            },
            hideUnrevealed: false,
            followHideMode: true,
          ),
        );
  }

  void _onSession(RecitationSessionState session) {
    final id = session.session?.id;
    final listening = session.phase == RecitationPhase.listening;
    // Every recitation session is a Hifz test.
    if (id != null && id != _sessionId && listening) {
      _sessionId = id;
      _begin();
    }
    if (_listening && !listening && _matcher is QuranStreamMatcher) {
      _judgeAll(_matcher?.flush() ?? const []); // pause/stop
    }
    // (The acoustic tracker flushes once the paused audio's last frames
    // arrive — see [_onFrames].)
    // Session over: back to the normal page.
    if (!session.isActive && (state.active || _locating)) _clear();
    _listening = listening;
  }

  /// Starts the test: at the chosen range; with hide mode on, at the first
  /// word not yet uncovered on the visible page; with the page visible,
  /// wherever the reciter turns out to start.
  void _begin() {
    // A new recitation: the last one's colours go.
    if (_results) {
      _results = false;
      _judge = null;
      ref.read(mushafWordOverlayProvider.notifier).set(null);
    }
    final corpus = _corpus;
    if (corpus == null) return;
    _turnedFor = null;
    _seenPages = _visiblePages();
    _relocating = false;
    final chosen = state.range;
    if (chosen != null) {
      final start = corpus.verseStartPosition(chosen.from);
      final end = corpus.verseEndPosition(chosen.to);
      if (start != null && end != null && end >= start) {
        _startJudge(start, end);
      }
      return;
    }
    final pages = _visiblePages();
    final ranges = ref.read(mushafPageWordRangesProvider);
    final firstRange = pages == null ? null : ranges[pages.$1];
    if (firstRange == null) return;
    final pageStart = corpus.positionOf(firstRange.first);
    if (pageStart == null) return;
    final hideMode = ref.read(mushafHideModeProvider);
    if (hideMode.enabled) {
      var already = hideMode.revealedOn(pages!.$1);
      if (pages.$2 != pages.$1 && hideMode.fullyRevealed(pages.$1)) {
        already += hideMode.revealedOn(pages.$2);
      }
      _startJudge(pageStart, _corpus!.length - 1, preRevealed: already);
      return;
    }
    // The page is visible: locate the reciter first.
    final lastRange = ranges[pages!.$2] ?? firstRange;
    _matcher = _newMatcher()
      ..start(anchor: pageStart)
      ..setFocus(pageStart, corpus.positionOf(lastRange.last) ?? pageStart);
    _judge = null;
    _locating = true;
    state = HifzState(range: state.range, running: true);
  }

  void _startJudge(int start, int end, {int preRevealed = 0}) {
    final judge = HifzJudge(
      _corpus!,
      start: start,
      end: end,
      config: HifzConfig(strict: ref.read(hifzSettingsProvider).strict),
    )..preReveal(preRevealed);
    _judge = judge;
    _locating = false;
    _matcher = _newMatcher()..start(anchor: judge.expected, trustAnchor: true);
    _publish(const [], running: true);
  }

  RecitationPositionMatcher _newMatcher() => _acousticPosition
      ? LocalQuranPositionTracker(
          _corpus!,
          () => _phonemes,
          log: kReleaseMode ? null : (l) => debugPrint('Hifz (acoustic): $l'),
        )
      : QuranStreamMatcher(
          _corpus!,
          log: kReleaseMode ? null : (l) => debugPrint('Hifz: $l'),
        );

  static const WordRef _noWord = (ayahId: 0, wordIndex: 0);

  /// The pages last seen on screen during this test.
  (int, int)? _seenPages;

  /// With the page visible, the reciter must be found again before the
  /// test continues (after turning pages by hand).
  bool _relocating = false;

  /// When the visible pages change and the expected word is not on them —
  /// the reciter turned the page themselves, rather than the test following
  /// them — the test moves to the new pages: with hide mode on, to their
  /// first hidden word; with the page visible, to wherever the reciter is
  /// found next.
  void _onPagesChanged() {
    final judge = _judge;
    final pages = _visiblePages();
    if (pages == null) return;
    if (judge == null && _locating) {
      // Still finding the reciter: look on the new pages.
      final ranges = ref.read(mushafPageWordRangesProvider);
      final corpus = _corpus;
      final from = corpus?.positionOf(ranges[pages.$1]?.first ?? _noWord);
      final to = corpus?.positionOf(ranges[pages.$2]?.last ?? _noWord);
      if (from != null && to != null) _matcher?.setFocus(from, to);
      return;
    }
    if (judge == null || !state.running) return;
    if (pages == _seenPages) return;
    final ranges = ref.read(mushafPageWordRangesProvider);
    final first = ranges[pages.$1], last = ranges[pages.$2];
    if (first == null || last == null) return; // wait for the pages to load
    _seenPages = pages;
    final corpus = judge.corpus;
    final from = corpus.positionOf(first.first);
    final to = corpus.positionOf(last.last);
    if (from == null || to == null) return;
    if (judge.current >= from && judge.current <= to + 1) return;
    _turnedFor = null;
    final hideOn = ref.read(mushafHideModeProvider).enabled;
    if (hideOn) {
      judge.jumpTo(from);
      _matcher = _newMatcher()
        ..start(anchor: judge.expected, trustAnchor: true);
      _publish(const []);
    } else {
      _relocating = true;
      _matcher = _newMatcher()
        ..start(anchor: from)
        ..setFocus(from, to);
    }
  }

  /// First and last visible page (the same page outside a spread).
  (int, int)? _visiblePages() {
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return null;
    final spread = ref.read(fullBleedContentProvider);
    final first = firstVisiblePage(location.pageNumber, spread: spread);
    return (first, spread ? first + 1 : first);
  }

  void _onRecognition(LiveRecognitionEvent event) {
    final matcher = _matcher;
    if (matcher is! QuranStreamMatcher || !state.running) return;
    _judgeAll(switch (event) {
      LivePartialTranscript(:final text) => matcher.onPartial(text),
      LiveFinalTranscript(:final text) => matcher.onFinal(text),
      _ => const <QuranMatchEvent>[],
    });
  }

  /// New acoustic frames: the tracker places the words they hold.
  void _onFrames(TimedAcousticFrames chunk) {
    final tracker = _matcher;
    if (tracker is! LocalQuranPositionTracker || !state.running) return;
    final placedBefore = tracker.lastPlacedFrame;
    final out = [
      ...tracker.onFrames(chunk),
      // The audio paused: what was held back is final now.
      if (chunk.last) ...tracker.flush(),
    ];
    if (out.any((e) => e is MatchRelocated) && _judge == null) {
      _inference?.recordLocated();
    }
    _judgeAll(out);
    if (tracker.placements.isNotEmpty || chunk.last) {
      _inference?.recordPlacements([...tracker.placements], paused: chunk.last);
      tracker.placements.clear();
    }
    final placed = tracker.lastPlacedFrame;
    if (placed != null && placed != placedBefore) {
      _inference?.recordFollow(placed - 1);
    }
  }

  void _judgeAll(List<QuranMatchEvent> out) {
    if (_judge == null && _locating) {
      // The first located word starts the test.
      final located = out.whereType<WordHeard>().where((h) => h.ref != null);
      final first = located.isEmpty ? null : located.first.ref;
      final corpus = _corpus;
      final start = first == null ? null : corpus?.positionOf(first);
      if (start == null) return;
      _judge = HifzJudge(
        corpus!,
        start: start,
        end: corpus.length - 1,
        config: HifzConfig(strict: ref.read(hifzSettingsProvider).strict),
      );
      _locating = false;
    }
    final judge = _judge;
    if (judge == null) return;
    if (_relocating) {
      final located = out.whereType<WordHeard>().where((h) => h.ref != null);
      final at = located.isEmpty
          ? null
          : judge.corpus.positionOf(located.first.ref!);
      if (at == null) return;
      judge.jumpTo(at);
      _relocating = false;
    }
    final reviewBefore = judge.reviewing;
    final events = [
      for (final heard in out.whereType<WordHeard>()) ...judge.onHeard(heard),
    ];
    if (events.isEmpty && state.active && judge.reviewing == reviewBefore) {
      return;
    }
    final settings = ref.read(hifzSettingsProvider);
    final mistake = events.any(
      (e) => e.verdict == HifzVerdict.wrong || e.verdict == HifzVerdict.skipped,
    );
    if (mistake && settings.vibrate) ref.read(hifzHapticsProvider)();
    _publish(events, running: true);
    _followPage();
  }

  void _publish(List<HifzEvent> events, {bool? running}) {
    final judge = _judge!;
    final corpus = judge.corpus;
    final recent = [...state.recent, ...events];
    state = HifzState(
      range: state.range,
      running: (running ?? state.running) && !judge.completed,
      first: corpus.words[judge.start].ref,
      last: corpus.words[judge.end].ref,
      revealed: {for (final p in judge.revealed) corpus.words[p].ref},
      marked: {
        for (final e in judge.marked.entries) corpus.words[e.key].ref: e.value,
      },
      expected: judge.expectedRef,
      reviewing: judge.reviewing == null
          ? null
          : corpus.words[judge.reviewing!].ref,
      pending: judge.pending,
      counts: Map.of(judge.counts),
      recent: recent.length > 5 ? recent.sublist(recent.length - 5) : recent,
      completed: judge.completed,
    );
    _updateOverlay();
  }

  /// Turns the page when the expected word has moved off what is shown —
  /// forward as recitation continues, back after hiding back.
  void _followPage() {
    final judge = _judge;
    final pages = _visiblePages();
    if (judge == null || judge.completed || pages == null) return;
    final ranges = ref.read(mushafPageWordRangesProvider);
    final first = ranges[pages.$1], last = ranges[pages.$2];
    if (first == null || last == null) return;
    // Follow where the reciter is — the reviewed word when going back.
    final at = judge.current;
    final here = judge.corpus.words[at].ref;
    final turns = ref.read(mushafPageTurnRequestsProvider.notifier);
    if (_turnedFor == at) return;
    if (compareWordRefs(here, last.last) > 0) {
      _turnedFor = at;
      turns.next();
    } else if (compareWordRefs(here, first.first) < 0) {
      _turnedFor = at;
      turns.previous();
    }
  }

  /// Carries the test's progress into hide mode: on each rendered page,
  /// how many words from its start are revealed.
  void _syncToHideMode() {
    final judge = _judge;
    if (judge == null || !ref.read(mushafHideModeProvider).enabled) return;
    final corpus = judge.corpus;
    final revealed = <int, int>{};
    for (final MapEntry(key: page, value: range)
        in ref.read(mushafPageWordRangesProvider).entries) {
      final from = corpus.positionOf(range.first);
      final to = corpus.positionOf(range.last);
      if (from == null || to == null || to < judge.start || from > judge.end) {
        continue;
      }
      var count = 0;
      for (var q = from; q <= to; q++) {
        if (q >= judge.start && !judge.revealed.contains(q)) break;
        count++;
      }
      revealed[page] = count;
    }
    ref.read(mushafHideModeProvider.notifier).setRevealed(revealed);
  }
}

final hifzControllerProvider =
    NotifierProvider.autoDispose<HifzController, HifzState>(HifzController.new);
