import '../../../ai/acoustic/quran_acoustic_verifier.dart' show TajweedRule;
import '../../../memorization/application/activity_stats.dart';

import 'dart:async';
import 'dart:math' as math;
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
import '../../../quran/quran_providers.dart';
import '../../../memorization/domain/test_grading.dart';
import '../../../memorization/memorization_providers.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import 'acoustic_position_providers.dart';
import 'acoustic_settle.dart';
import 'acoustic_verification_controller.dart';
import 'local_acoustic_inference_controller.dart';
import 'recitation_ai_config.dart';
import 'recitation_providers.dart' show recitationClockProvider;
import 'recitation_position.dart';
import 'live_recognition_controller.dart';
import 'mushaf_recitation_target.dart';
import 'quran_match_controller.dart' show quranWordCorpusProvider;
import 'recitation_session_controller.dart';

/// How a mistake noticed during recitation is signalled (Android).
enum MistakeAlert {
  off,
  vibrate,
  sound,
  both;

  bool get vibrates => this == vibrate || this == both;
  bool get beeps => this == sound || this == both;

  /// The alert that vibrates and / or beeps.
  static MistakeAlert of({required bool vibrate, required bool sound}) =>
      vibrate
      ? (sound ? both : MistakeAlert.vibrate)
      : (sound ? MistakeAlert.sound : off);
}

/// How strictly pronunciation is judged: every threshold of the check — letters,
/// vowels, shadda, sukun and, with tajweed, qalqala, madd and ghunnah — shifted
/// together ([AcousticVerificationController.withStrictness]).
enum RecitationStrictness { lenient, balanced, strict }

/// The recitation modes with an explanation before their first run.
enum RecitationIntroMode { recite, loop, follow }

/// Configurable Hifz feedback.
class HifzSettings {
  const HifzSettings({
    this.strict = true,
    this.highlightCurrent = true,
    this.showMistakes = true,
    this.alert = MistakeAlert.vibrate,
    this.colorWords = true,
    this.tajweed = true,
    this.tajweedRules = defaultTajweedRules,
    this.sajdahReminder = true,
    this.strictness = RecitationStrictness.balanced,
    this.tajweedAlert = MistakeAlert.vibrate,
    this.pronunciationColor = defaultPronunciationColor,
    this.tajweedColor = defaultTajweedColor,
    this.introsSeen = const {},
  });

  /// The modes whose explanation (how the check works) was shown before
  /// their first recitation.
  final Set<RecitationIntroMode> introsSeen;

  /// The colours offered for a word with a pronunciation mistake (a letter
  /// or vowel) and for one whose only mistakes are tajweed, as ARGB — none
  /// of them green, yellow or red, which mean correct, skipped and wrong.
  static const pronunciationColors = [
    defaultPronunciationColor,
    0xFFD81B60, // pink
    0xFF8E24AA, // purple
    0xFF6D4C41, // brown
    0xFF00897B, // teal
  ];
  static const tajweedColors = [
    defaultTajweedColor,
    0xFF3949AB, // indigo
    0xFF00897B, // teal
    0xFF8E24AA, // purple
    0xFFD81B60, // pink
  ];
  static const defaultPronunciationColor = 0xFFEF6C00; // orange
  static const defaultTajweedColor = 0xFF039BE5; // light blue

  /// The ink of a word with a pronunciation mistake: one of
  /// [pronunciationColors].
  final int pronunciationColor;

  /// The ink of a word whose only mistakes are tajweed: one of
  /// [tajweedColors].
  final int tajweedColor;

  /// The page's inks for these colours: the chosen two and, with a
  /// pronunciation colour other than orange, a likely mistake still being
  /// checked in a lighter shade of it (orange's own is the page's peach).
  Map<MushafWordMark, int> get inks => {
    MushafWordMark.tashkeel: pronunciationColor,
    MushafWordMark.tajweed: tajweedColor,
    if (pronunciationColor != defaultPronunciationColor)
      MushafWordMark.checking: _lighter(pronunciationColor),
  };

  static int _lighter(int argb) {
    int channel(int shift) {
      final c = (argb >> shift) & 0xFF;
      return (c + (255 - c) * 0.55).round() << shift;
    }

    return 0xFF000000 | channel(16) | channel(8) | channel(0);
  }

  /// The rules offered before the choice was saved with them.
  static const _rulesBeforeIdghamMim = [
    'ikhfa',
    'iqlab',
    'ikhfaShafawi',
    'idgham',
    'qalqala',
    'madd',
  ];

  static const allTajweedRules = {
    TajweedRule.ikhfa,
    TajweedRule.iqlab,
    TajweedRule.ikhfaShafawi,
    TajweedRule.idghamMim,
    TajweedRule.idgham,
    TajweedRule.qalqala,
    TajweedRule.madd,
    TajweedRule.ghunnah,
  };

  /// Every rule, on until chosen.
  static const defaultTajweedRules = allTajweedRules;

  /// With [tajweed]: the rules judged (each can be turned off).
  final Set<TajweedRule> tajweedRules;

  /// Reciting an ayah of prostration: a reminder of Sujood al-Tilawah
  /// (once per app session).
  final bool sajdahReminder;

  /// How strictly pronunciation is judged (balanced: as calibrated).
  final RecitationStrictness strictness;

  /// Vibrate or beep on a tajweed mistake (a word whose only mistakes are
  /// tajweed), apart from [alert] for letters, vowels and words.
  final MistakeAlert tajweedAlert;

  /// Judge tajweed in the pronunciation check (idghām, ikhfāʾ, iqlāb …);
  /// off, only the letters and vowels.
  final bool tajweed;

  /// Mistakes hold the test until corrected (see [HifzConfig.strict]).
  final bool strict;

  /// Mark where the next word is.
  final bool highlightCurrent;

  /// Mark wrong, skipped and uncertain words.
  final bool showMistakes;

  /// Vibrate or beep on a mistake (Android).
  final MistakeAlert alert;

  /// Colour recited words: correct green, skipped yellow, wrong red.
  final bool colorWords;

  HifzSettings copyWith({
    bool? strict,
    bool? highlightCurrent,
    bool? showMistakes,
    MistakeAlert? alert,
    bool? colorWords,
    bool? tajweed,
    Set<TajweedRule>? tajweedRules,
    bool? sajdahReminder,
    RecitationStrictness? strictness,
    MistakeAlert? tajweedAlert,
    int? pronunciationColor,
    int? tajweedColor,
    Set<RecitationIntroMode>? introsSeen,
  }) => HifzSettings(
    strict: strict ?? this.strict,
    highlightCurrent: highlightCurrent ?? this.highlightCurrent,
    showMistakes: showMistakes ?? this.showMistakes,
    alert: alert ?? this.alert,
    colorWords: colorWords ?? this.colorWords,
    tajweed: tajweed ?? this.tajweed,
    tajweedRules: tajweedRules ?? this.tajweedRules,
    sajdahReminder: sajdahReminder ?? this.sajdahReminder,
    strictness: strictness ?? this.strictness,
    tajweedAlert: tajweedAlert ?? this.tajweedAlert,
    pronunciationColor: pronunciationColor ?? this.pronunciationColor,
    tajweedColor: tajweedColor ?? this.tajweedColor,
    introsSeen: introsSeen ?? this.introsSeen,
  );

  Map<String, Object> toJson() => {
    'strict': strict,
    'highlightCurrent': highlightCurrent,
    'showMistakes': showMistakes,
    'alert': alert.name,
    'colorWords': colorWords,
    'tajweed': tajweed,
    'tajweedRules': [for (final r in tajweedRules) r.name],
    // The rules offered when chosen: one added since is on (it was never
    // turned off).
    'tajweedRulesKnown': [for (final r in TajweedRule.values) r.name],
    'sajdahReminder': sajdahReminder,
    'strictness': strictness.name,
    'tajweedAlert': tajweedAlert.name,
    'pronunciationColor': pronunciationColor,
    'tajweedColor': tajweedColor,
    'introsSeen': [for (final m in introsSeen) m.name],
  };

  static HifzSettings fromJson(Object? json) {
    if (json is! Map) return const HifzSettings();
    bool read(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    // (Saved before the alert choice: a vibrate switch.)
    final alert =
        MistakeAlert.values.asNameMap()[json['alert']] ??
        (read('vibrate', true) ? MistakeAlert.vibrate : MistakeAlert.off);
    return HifzSettings(
      strict: read('strict', true),
      highlightCurrent: read('highlightCurrent', true),
      showMistakes: read('showMistakes', true),
      alert: alert,
      colorWords: read('colorWords', true),
      tajweed: read('tajweed', true),
      // (Saved before the per-rule choice: every rule. A rule added since
      // the choice — idghām into mīm, 2026-10-24 — on.)
      tajweedRules: json['tajweedRules'] is List
          ? {
              for (final n in json['tajweedRules'] as List)
                ?TajweedRule.values.asNameMap()[n],
              for (final r in defaultTajweedRules)
                if (!(json['tajweedRulesKnown'] is List
                        ? json['tajweedRulesKnown'] as List
                        : _rulesBeforeIdghamMim)
                    .contains(r.name))
                  r,
            }
          : defaultTajweedRules,
      sajdahReminder: read('sajdahReminder', true),
      strictness:
          RecitationStrictness.values.asNameMap()[json['strictness']] ??
          RecitationStrictness.balanced,
      // (Saved before the tajweed alert: as the mistake alert.)
      tajweedAlert:
          MistakeAlert.values.asNameMap()[json['tajweedAlert']] ?? alert,
      // Only a colour still offered.
      pronunciationColor:
          pronunciationColors.contains(json['pronunciationColor'])
          ? json['pronunciationColor'] as int
          : defaultPronunciationColor,
      tajweedColor: tajweedColors.contains(json['tajweedColor'])
          ? json['tajweedColor'] as int
          : defaultTajweedColor,
      introsSeen: {
        if (json['introsSeen'] is List)
          for (final n in json['introsSeen'] as List)
            ?RecitationIntroMode.values.asNameMap()[n],
        // (Saved when only Recite had one.)
        if (read('introSeen', false)) RecitationIntroMode.recite,
      },
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
/// A short vibration for a mistake (Android: the device's vibrator — the
/// touch-feedback setting MIUI and others often turn down is not used;
/// iOS: the haptic engine).
final hifzHapticsProvider = Provider<void Function()>((ref) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  final native = capabilities.isAndroid || capabilities.isIOS;
  const channel = MethodChannel('tahfeez/alert');
  return native
      ? () => unawaited(channel.invokeMethod<void>('vibrate', 120))
      : () {};
});

/// A short, soft beep for a mistake (Android and iOS).
final hifzBeepProvider = Provider<void Function()>((ref) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  final native = capabilities.isAndroid || capabilities.isIOS;
  const channel = MethodChannel('tahfeez/alert');
  return native ? () => unawaited(channel.invokeMethod<void>('beep')) : () {};
});

/// A chosen memorization range (whole ayahs, inclusive).
typedef HifzRange = ({VerseRef from, VerseRef to});

/// A range to test, chosen outside the Mushaf (the Memorize tab's tasks):
/// the Hifz test takes it as its range once the Mushaf is open.
class RequestedHifzRange extends Notifier<HifzRange?> {
  @override
  HifzRange? build() => null;

  void request(HifzRange range) => state = range;

  void clear() => state = null;
}

final requestedHifzRangeProvider =
    NotifierProvider<RequestedHifzRange, HifzRange?>(RequestedHifzRange.new);

/// How a loop repeats its range.
enum HifzLoopMode {
  /// The whole range, then from its first ayah again.
  range,

  /// Each ayah the set number of times, then the next.
  eachAyah,
}

/// Loop recitation: the range recited [count] times — whole, or ayah by
/// ayah ([mode]) — each time tested afresh (with hide mode on, hidden
/// again).
class HifzLoop {
  const HifzLoop({
    this.mode = HifzLoopMode.eachAyah,
    this.count = 3,
    this.perAyah = 1,
    this.strict = false,
  });

  final HifzLoopMode mode;
  final int count;

  /// The whole range ([HifzLoopMode.range]): within each pass, each ayah
  /// this many times before the next.
  final int perAyah;

  /// After a pass with a mistake, the loop waits — its marks in view — to
  /// be recited again or skipped ([HifzController.loopTryAgain] /
  /// [HifzController.loopSkip]).
  final bool strict;

  /// Tested an ayah at a time (each ayah, or a range pass ayah by ayah).
  bool get byAyah => mode == HifzLoopMode.eachAyah || perAyah > 1;

  static const maxCount = 99;

  HifzLoop copyWith({
    HifzLoopMode? mode,
    int? count,
    int? perAyah,
    bool? strict,
  }) => HifzLoop(
    mode: mode ?? this.mode,
    count: count ?? this.count,
    perAyah: perAyah ?? this.perAyah,
    strict: strict ?? this.strict,
  );
}

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
    this.loop,
    this.repetition = 0,
    this.loopAyah,
    this.ayahRepetition = 1,
    this.loopReview = false,
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

  /// The range (with a loop, the whole loop) has been recited.
  final bool completed;

  /// Loop recitation over [range], or `null`.
  final HifzLoop? loop;

  /// Which time the loop's range (or [loopAyah]) is being recited, from 1;
  /// `0` before a loop starts.
  final int repetition;

  /// Looping ayah by ayah: the ayah being recited.
  final VerseRef? loopAyah;

  /// A whole-range loop recited ayah by ayah ([HifzLoop.perAyah]): which
  /// time [loopAyah] is being recited in this pass, from 1.
  final int ayahRepetition;

  /// A strict loop's pass ended with mistakes: the loop waits, its marks
  /// in view, to be recited again or skipped.
  final bool loopReview;

  /// Whether a test's masks are on the page (running or just finished).
  bool get active => first != null && last != null;

  bool isHidden(WordRef ref) =>
      active &&
      compareWordRefs(ref, first!) >= 0 &&
      compareWordRefs(ref, last!) <= 0 &&
      !revealed.contains(ref);

  HifzState copyWith({
    HifzRange? Function()? range,
    bool? running,
    HifzLoop? Function()? loop,
    bool? loopReview,
  }) => HifzState(
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
    loop: loop == null ? this.loop : loop(),
    repetition: repetition,
    loopAyah: loopAyah,
    ayahRepetition: ayahRepetition,
    loopReview: loopReview ?? this.loopReview,
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
    // The page's colours belong to this controller: leaving the Mushaf
    // (which disposes it) clears them, and so does finding a finished
    // recitation's left over when it starts.
    final overlay = ref.read(mushafWordOverlayProvider.notifier);
    if (ref.read(mushafWordOverlayProvider)?.followHideMode ?? false) {
      Future.microtask(() => overlay.set(null));
    }
    ref.onDispose(() {
      _pacer?.cancel();
      unawaited(_recognition?.cancel());
      unawaited(_frames?.cancel());
      Future.microtask(() => overlay.set(null));
    });
    ref.listen(quranWordCorpusProvider, (_, next) {
      _corpus = next.value;
    }, fireImmediately: true);
    ref.listen(recitationSessionControllerProvider, (_, next) {
      _onSession(next);
    });
    ref.listen(hifzSettingsProvider, (_, _) => _updateOverlay());
    // A range chosen outside the Mushaf: taken as the test's range.
    ref.listen(requestedHifzRangeProvider, (_, next) {
      if (next == null) return;
      Future.microtask(() {
        if (!ref.mounted || state.running) return;
        setRange(next);
        ref.read(requestedHifzRangeProvider.notifier).clear();
      });
    }, fireImmediately: true);
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
      if (identical(previous?.words, next.words)) return;
      _updateOverlay();
      // A pronunciation mistake newly heard on a recited word: alert too.
      final judge = _judge;
      if (judge == null) return;
      // (A loop's previous repetition, checked once the next has begun:
      // its words were recited.)
      for (final MapEntry(key: w, value: r) in next.words.entries) {
        final before = previous?.words[w];
        // A confirmed mistake (the ayah's check), or a quick early verdict
        // of a kind rarely withdrawn ([AcousticWordResult.isSure]); others
        // are sometimes withdrawn by the ayah's check. Once per word.
        if (!r.isSure ||
            (before != null && before.isSure && before.pass == r.pass)) {
          continue;
        }
        if (r.pass < _pass ||
            (r.pass == _pass &&
                judge.revealed.contains(judge.corpus.positionOf(w)))) {
          _alert([w], pass: r.pass, tajweed: r.isTajweedOnly);
        }
      }
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

  /// The range chosen before a loop (restored when its session ends).
  HifzRange? _rangeBeforeLoop;

  /// The loop last started, for the loop sheet to offer again.
  HifzLoop lastLoop = const HifzLoop();

  /// Loops [range] in the next recitation session (started right after);
  /// the session's end ends the loop. [showBefore]: the words before the
  /// range stay shown in hide mode (Follow along).
  void setLoop(HifzRange range, HifzLoop loop, {bool showBefore = false}) {
    if (state.running) return;
    if (state.loop == null) _rangeBeforeLoop = state.range;
    _showBefore = showBefore;
    lastLoop = loop;
    state = state.copyWith(range: () => range, loop: () => loop);
  }

  /// Whether the running test has heard a word of [ayahId] recited (not
  /// revealed by hand).
  bool recitedIn(int ayahId) {
    final judge = _judge;
    if (judge == null) return false;
    final words = judge.corpus.words;
    return judge.revealed.any(
      (p) => !judge.given.contains(p) && words[p].ref.ayahId == ayahId,
    );
  }

  /// The words before the range stay shown (see [setLoop]); for one
  /// session.
  var _showBefore = false;

  /// The pass being recited: one more each time a loop starts again (see
  /// [recitationPassProvider]).
  int _pass = 0;

  void _setPass(int pass) {
    _pass = pass;
    ref.read(recitationPassProvider.notifier).set(pass);
  }

  /// Reveals the expected word (or the rest of its ayah) without it being
  /// recited — it counts as skipped.
  void revealNext({bool wholeAyah = false}) {
    final judge = _judge;
    if (judge == null) return;
    _publish(judge.revealManually(wholeAyah: wholeAyah));
    if (!_loopOn()) _followPage();
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
    _showHeld();
    if (_judge case final judge?) _record(judge);
    _syncToHideMode();
    _matcher = null;
    _locating = false;
    // A loop lasts one session.
    _showBefore = false;
    state = HifzState(
      range: state.loop != null ? _rangeBeforeLoop : state.range,
    );
    _loopEnd = null;
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
    // Words recited but still to be shown, one after another.
    final held = _held.toSet();
    final next = held.isEmpty ? expected : _held.first;
    final marks = <WordRef, MushafWordMark>{
      if (settings.colorWords && judge != null)
        for (final p in judge.revealed)
          if (!judge.given.contains(p) &&
              !held.contains(judge.corpus.words[p].ref))
            judge.corpus.words[p].ref: switch (judge.marked[p]) {
              HifzVerdict.skipped => MushafWordMark.skipped,
              HifzVerdict.wrong ||
              HifzVerdict.selfCorrected => MushafWordMark.wrong,
              // The right word — was it pronounced right? (acoustic check)
              // Only a mistake is marked: "uncertain" (the on-device model
              // could not tell) was a fifth of a good reciter's words on
              // the phone — noise, not feedback.
              _ => _pronunciationMark(
                acoustic[judge.corpus.words[p].ref],
                _pass,
              ),
            },
      // Going back over revealed words: the band follows the reciter.
      if (reviewing != null && settings.highlightCurrent)
        reviewing: MushafWordMark.current
      else if (expected != null && s.pending != null && settings.showMistakes)
        expected: MushafWordMark.mistake
      else if (next != null && settings.highlightCurrent)
        next: MushafWordMark.current,
    };
    ref
        .read(mushafWordOverlayProvider.notifier)
        .set(
          MushafWordOverlay(
            first: s.first!,
            // Looping ayah by ayah: the ayahs still to come stay hidden too.
            last: _loopEnd ?? s.last!,
            revealed: {..._loopDone, ...s.revealed}.difference(held),
            marks: _withSettings(marks, settings),
            hideUnrevealed: ref.read(mushafHideModeProvider).enabled,
            showBefore: _showBefore,
            heard: Map.of(_heardAt),
            corrected: Set.of(_correctedAt),
            inks: settings.inks,
          ),
        );
  }

  /// A recited word's colour from its pronunciation check.
  /// (Only [pass]'s verdict: a loop's earlier repetitions of the word are
  /// not this one.)
  /// (A quick early verdict shows at once: in full if it is
  /// [AcousticWordResult.isSure], else softly, as [MushafWordMark.checking],
  /// until the ayah's check confirms it — and alerts — or withdraws it.)
  static MushafWordMark _pronunciationMark(AcousticWordResult? a, int pass) =>
      a == null || !a.isMistake || a.pass != pass
      ? MushafWordMark.correct
      : a.isSure
      ? (a.isTajweedOnly ? MushafWordMark.tajweed : MushafWordMark.tashkeel)
      : MushafWordMark.checking;

  /// [marks] as the settings show them: with mistakes not shown, no word
  /// marked skipped, wrong or mispronounced (nor the band of a pending
  /// one) — those words stay plain; the rest as they are.
  static Map<WordRef, MushafWordMark> _withSettings(
    Map<WordRef, MushafWordMark> marks,
    HifzSettings settings,
  ) => settings.showMistakes
      ? marks
      : {
          for (final e in marks.entries)
            if (!_mistakeMarks.contains(e.value)) e.key: e.value,
        };

  static const _mistakeMarks = {
    MushafWordMark.mistake,
    MushafWordMark.skipped,
    MushafWordMark.wrong,
    MushafWordMark.tashkeel,
    MushafWordMark.tajweed,
    MushafWordMark.checking,
    MushafWordMark.uncertain,
  };

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
            marks: _withSettings({
              for (final p in judge.revealed)
                if (!judge.given.contains(p))
                  corpus.words[p].ref: switch (judge.marked[p]) {
                    HifzVerdict.skipped => MushafWordMark.skipped,
                    HifzVerdict.wrong ||
                    HifzVerdict.selfCorrected => MushafWordMark.wrong,
                    _ => _pronunciationMark(
                      acoustic[corpus.words[p].ref],
                      _pass,
                    ),
                  },
            }, ref.read(hifzSettingsProvider)),
            hideUnrevealed: false,
            followHideMode: true,
            heard: Map.of(_heardAt),
            corrected: Set.of(_correctedAt),
            inks: ref.read(hifzSettingsProvider).inks,
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
    if (!session.isActive &&
        (state.active || _locating || state.loop != null)) {
      _clear();
    }
    _listening = listening;
  }

  /// Starts the test: at the chosen range; with hide mode on, at the first
  /// word not yet uncovered on the visible page; with the page visible,
  /// wherever the reciter turns out to start.
  void _begin() {
    _showHeld();
    _lastBatch = null;
    _setPass(0);
    _loopEnd = null;
    _loopDone.clear();
    _checkingPass = false;
    _startWindow = null;
    _alerted.clear();
    _heardAt.clear();
    _correctedAt.clear();
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
        final loop = state.loop;
        if (loop?.byAyah ?? false) {
          _loopEnd = corpus.words[end].ref;
          _startJudge(start, corpus.verseEndPosition(chosen.from)!);
        } else {
          _startJudge(start, end);
        }
        if (loop != null) {
          state = _withLoop(state, 1, chosen.from);
        }
        _showWord(corpus.words[start].ref);
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
      // The reciter may begin further down instead: see _startWindow.
      final lastRange = ranges[pages.$2] ?? firstRange;
      final pageEnd = corpus.positionOf(lastRange.last);
      if (pageEnd != null) {
        _startWindow = (
          pageStart: pageStart,
          pageEnd: pageEnd,
          uncovered: already,
        );
      }
      return;
    }
    // The page is visible: locate the reciter first.
    final lastRange = ranges[pages!.$2] ?? firstRange;
    _matcher = _newMatcher()
      ..start(anchor: pageStart)
      ..setFocus(
        pageStart,
        corpus.positionOf(lastRange.last) ?? pageStart,
        only: true,
      );
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
      if (from != null && to != null) {
        _matcher?.setFocus(from, to, only: true);
      }
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
    // Lost and found again only on the pages on screen.
    _matcher?.setFocus(from, to, only: true);
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
        ..setFocus(from, to, only: true);
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
    // (Placed in this pass, even if a loop starts the next one now.)
    final pass = _pass;
    _judgeAll(out);
    if (tracker.placements.isNotEmpty || chunk.last) {
      _inference?.recordPlacements(
        [...tracker.placements],
        paused: chunk.last,
        pass: pass,
      );
      tracker.placements.clear();
    }
    final placed = tracker.lastPlacedFrame;
    if (placed != null && placed != placedBefore) {
      _inference?.recordFollow(placed - 1);
    }
  }

  /// Hide mode, until the reciter is settled: the page's first word, its
  /// last, and how many of its words were uncovered before the test. A
  /// reciter may begin further down than the first hidden word (a surah
  /// starting mid-page: Al-Hadid after Al-Waqi'a's last ayahs); the tracker
  /// finds them there, and the test starts again at that word — the words
  /// before it given (shown, never graded), not revealed by hand and marked
  /// for revision. Settled once a few words in a row are accepted.
  ({int pageStart, int pageEnd, int uncovered})? _startWindow;

  /// Words accepted in a row: past this the reciter is settled.
  static const _settledWords = 3;

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
    final window = _startWindow;
    if (window != null) {
      final heard = out.whereType<WordHeard>().where((h) => h.ref != null);
      final at = heard.isEmpty
          ? null
          : judge.corpus.positionOf(heard.first.ref!);
      if (at != null && at > judge.expected && at <= window.pageEnd) {
        // Further down the page than expected: the test starts again
        // there, clean — the shaky first seconds' marks dropped.
        final fresh = HifzJudge(
          judge.corpus,
          start: window.pageStart,
          end: judge.end,
          config: judge.config,
        )..preReveal(math.max(window.uncovered, at - window.pageStart));
        _judge = fresh;
        _judgeAll(out);
        return;
      }
    }
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
    if (_startWindow != null &&
        (judge.counts[HifzVerdict.correct] ?? 0) >= _settledWords) {
      _startWindow = null;
    }
    if (events.isEmpty && state.active && judge.reviewing == reviewBefore) {
      return;
    }
    final mistakes = [
      for (final e in events)
        if ((e.verdict == HifzVerdict.wrong ||
                e.verdict == HifzVerdict.skipped) &&
            e.ref != null)
          e.ref!,
    ];
    if (mistakes.isNotEmpty) _alert(mistakes);
    _publish(events, running: true, paced: _acousticPosition);
    if (!_loopOn()) _followPage();
  }

  /// Words a mistake alert was given for (once each per recitation — with
  /// a loop, per repetition).
  final _alerted = <(int, WordRef)>{};

  /// Signals a mistake on [words] — vibration or a beep, as set — once
  /// per word.
  void _alert(Iterable<WordRef> words, {int? pass, bool tajweed = false}) {
    final p = pass ?? _pass;
    if (!state.running || !words.map((w) => (p, w)).any(_alerted.add)) return;
    final settings = ref.read(hifzSettingsProvider);
    final alert = tajweed ? settings.tajweedAlert : settings.alert;
    if (alert.vibrates) ref.read(hifzHapticsProvider)();
    if (alert.beeps) ref.read(hifzBeepProvider)();
  }

  /// What was heard in place of each word marked wrong, and the words
  /// corrected after a mistake — shown in a word's detail sheet.
  final _heardAt = <WordRef, String>{};
  final _correctedAt = <WordRef>{};

  /// Recited words held back from the page, in order. The streaming model
  /// hears about 1.3 s at a time, so the tracker places two or three words
  /// at once; they are shown one after another over the time until the
  /// next batch, as they were said.
  final _held = <WordRef>[];
  Timer? _pacer;
  DateTime? _lastBatch;

  /// Holds [words] (just revealed by recitation) to show one by one.
  void _pace(List<WordRef> words) {
    final now = DateTime.now();
    final last = _lastBatch;
    _lastBatch = now;
    if (words.isEmpty) return;
    // The time the batch's words took to say: since the last batch.
    final span = last == null
        ? const Duration(milliseconds: 1000)
        : now.difference(last);
    final ms = span.inMilliseconds.clamp(300, 1600);
    final showNow = _held.isEmpty;
    _held.addAll(words);
    if (showNow) _held.removeAt(0);
    _pacer?.cancel();
    if (_held.isEmpty) return;
    final step = Duration(
      milliseconds: (ms / (_held.length + (showNow ? 1 : 0))).round().clamp(
        60,
        600,
      ),
    );
    _pacer = Timer.periodic(step, (timer) {
      if (!ref.mounted) return timer.cancel();
      if (_held.isNotEmpty) _held.removeAt(0);
      if (_held.isEmpty) {
        timer.cancel();
        _pacer = null;
        _followPage();
      }
      _updateOverlay();
    });
  }

  /// Shows every held word at once.
  void _showHeld() {
    _pacer?.cancel();
    _pacer = null;
    _held.clear();
  }

  void _publish(List<HifzEvent> events, {bool? running, bool paced = false}) {
    final shownBefore = state.revealed;
    for (final e in events) {
      final ref = e.ref;
      if (ref == null) continue;
      if (e.verdict == HifzVerdict.wrong && e.heard != null) {
        _heardAt[ref] = e.heard!;
      } else if (e.verdict == HifzVerdict.selfCorrected) {
        _correctedAt.add(ref);
      }
    }
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
      loop: state.loop,
      repetition: state.repetition,
      loopAyah: state.loopAyah,
      ayahRepetition: state.ayahRepetition,
      loopReview: state.loopReview,
    );
    // Recited words appear one after another; a mistake awaiting
    // correction, a review, or words revealed by hand show at once.
    if (paced && judge.pending == null && judge.reviewing == null) {
      _pace([
        for (final p in judge.revealed.toList()..sort())
          if (!shownBefore.contains(corpus.words[p].ref)) corpus.words[p].ref,
      ]);
    } else {
      _showHeld();
    }
    _updateOverlay();
  }

  /// [s] at repetition [repetition] of the loop ([ayah] for ayah by ayah,
  /// [ayahRepetition] its time within a whole-range pass); not in review.
  static HifzState _withLoop(
    HifzState s,
    int repetition,
    VerseRef ayah, {
    int ayahRepetition = 1,
  }) => HifzState(
    range: s.range,
    running: s.running,
    first: s.first,
    last: s.last,
    revealed: s.revealed,
    marked: s.marked,
    expected: s.expected,
    reviewing: s.reviewing,
    pending: s.pending,
    counts: s.counts,
    recent: s.recent,
    completed: s.completed,
    loop: s.loop,
    repetition: repetition,
    loopAyah: (s.loop?.byAyah ?? false) ? ayah : null,
    ayahRepetition: ayahRepetition,
  );

  /// Looping ayah by ayah: the loop's last word (the overlay keeps the
  /// ayahs after the current one hidden up to it).
  WordRef? _loopEnd;

  /// Looping ayah by ayah: the words of the ayahs done (shown in hide mode).
  final _loopDone = <WordRef>{};

  /// After each judged batch: a loop whose range (or ayah) has just been
  /// recited starts it again, or moves on to the next ayah — a strict
  /// loop first checks the pass for mistakes. Returns whether a loop is
  /// running (it then turns the page itself).
  bool _loopOn() {
    final loop = state.loop, range = state.range, judge = _judge;
    final corpus = _corpus;
    if (loop == null || range == null || judge == null || corpus == null) {
      return false;
    }
    if (!judge.completed) {
      _followPage();
      return true;
    }
    if (state.loopReview || _checkingPass) return true;
    if (loop.strict) {
      _checkingPass = true;
      unawaited(_checkPass(judge));
      return true;
    }
    _nextPass(judge);
    return true;
  }

  /// A strict loop's pass being checked for mistakes (the microphone
  /// paused meanwhile).
  var _checkingPass = false;

  /// A strict loop's finished pass: its mistakes — words wrong or skipped,
  /// and the pronunciation check of its last ayah, waited for — hold the
  /// loop in review; without, it goes on.
  Future<void> _checkPass(HifzJudge judge) async {
    final corpus = judge.corpus;
    final pass = _pass;
    final ayahs = {
      for (var p = judge.start; p <= judge.end; p++) corpus.words[p].ref.ayahId,
    };
    final words = judge.marked.values.any(
      (v) =>
          v == HifzVerdict.wrong ||
          v == HifzVerdict.skipped ||
          v == HifzVerdict.selfCorrected,
    );
    final pronunciation = await settleAcousticCheck(
      ref,
      lastAyah: corpus.words[judge.end].ref.ayahId,
      pass: pass,
    );
    if (!ref.mounted || !identical(_judge, judge) || !_checkingPass) return;
    _checkingPass = false;
    final mistake =
        words ||
        hasPronunciationMistake(pronunciation, ayahIds: ayahs, pass: pass);
    if (mistake) {
      state = _withLoop(
        state,
        state.repetition,
        state.loopAyah ?? state.range!.from,
        ayahRepetition: state.ayahRepetition,
      ).copyWith(loopReview: true);
      return;
    }
    _nextPass(judge);
    _resume();
  }

  void _resume() {
    final session = ref.read(recitationSessionControllerProvider);
    if (session.phase == RecitationPhase.paused) {
      ref.read(recitationSessionControllerProvider.notifier).resume();
    }
  }

  /// A strict loop in review: the pass once more (not counted).
  void loopTryAgain() {
    final judge = _judge;
    if (!state.loopReview || judge == null) return;
    _again(judge, judge.start, judge.end);
    state = _withLoop(
      state,
      state.repetition,
      state.loopAyah ?? state.range!.from,
      ayahRepetition: state.ayahRepetition,
    );
    _showWord(judge.corpus.words[judge.start].ref);
    _resume();
  }

  /// A strict loop in review: on, as if the pass had no mistakes.
  void loopSkip() {
    final judge = _judge;
    if (!state.loopReview || judge == null) return;
    state = state.copyWith(loopReview: false);
    _nextPass(judge);
    _resume();
  }

  /// The loop's next pass after [judge]'s: the same range or ayah again,
  /// the next ayah, or — a whole range recited ayah by ayah — the range
  /// from its start again. Nothing when the loop is done.
  void _nextPass(HifzJudge judge) {
    final loop = state.loop, range = state.range;
    final corpus = judge.corpus;
    if (loop == null || range == null) return;
    var repetition = state.repetition;
    var ayah = state.loopAyah ?? range.from;
    var ayahRepetition = state.ayahRepetition;
    final last = corpus.verseEndPosition(range.to);
    final afterAyah = corpus.verseEndPosition(ayah)! + 1;
    var restart = false;
    if (loop.mode == HifzLoopMode.range && loop.byAyah) {
      // A pass of the whole range, each ayah perAyah times.
      if (++ayahRepetition > loop.perAyah) {
        ayahRepetition = 1;
        if (last == null || afterAyah > last) {
          if (++repetition > loop.count) return; // the loop is done
          ayah = range.from;
          restart = true;
        } else {
          ayah = corpus.words[afterAyah].verse;
        }
      }
    } else if (++repetition > loop.count) {
      if (loop.mode == HifzLoopMode.range || last == null || afterAyah > last) {
        return; // the loop is done
      }
      ayah = corpus.words[afterAyah].verse;
      repetition = 1;
    }
    final start = loop.byAyah
        ? corpus.verseStartPosition(ayah)
        : corpus.verseStartPosition(range.from);
    final end = loop.byAyah
        ? corpus.verseEndPosition(ayah)
        : corpus.verseEndPosition(range.to);
    if (start == null || end == null) return;
    if (restart) {
      // The whole range again: every ayah hidden again.
      _loopDone.clear();
    } else if (loop.byAyah && ayah != state.loopAyah) {
      // On to the next ayah: the ones done stay shown.
      for (var p = judge.start; p <= judge.end; p++) {
        _loopDone.add(corpus.words[p].ref);
      }
    }
    _again(judge, start, end);
    state = _withLoop(state, repetition, ayah, ayahRepetition: ayahRepetition);
    // Going back to the start is this position's page turn.
    if (_showWord(corpus.words[start].ref)) _turnedFor = start;
  }

  /// Tests [start]..[end] afresh, the next pass: the reciter, who may
  /// already be a word or two into it, is followed from the end of the last
  /// pass's final word.
  void _again(HifzJudge finished, int start, int end) {
    _record(finished);
    final corpus = finished.corpus;
    _judge = HifzJudge(
      corpus,
      start: start,
      end: end,
      config: HifzConfig(strict: ref.read(hifzSettingsProvider).strict),
    );
    _setPass(_pass + 1);
    _heardAt.clear();
    _correctedAt.clear();
    _turnedFor = null;
    final matcher = _matcher;
    if (matcher is LocalQuranPositionTracker) {
      // Its placements past the finished pass's last word are the new
      // pass's words, placed as whatever follows the range: dropped, and
      // their frames followed again.
      final lastRef = corpus.words[finished.end].ref;
      final at = matcher.placements.lastIndexWhere((w) => w.ref == lastRef);
      final from = at < 0 ? null : matcher.placements[at].end + 1;
      if (at >= 0) {
        matcher.placements.removeRange(at + 1, matcher.placements.length);
      }
      matcher.start(anchor: start, trustAnchor: true, from: from);
    } else {
      matcher?.start(anchor: start, trustAnchor: true);
    }
    _publish(const [], running: true);
  }

  /// The test whose results were last recorded (each test once).
  HifzJudge? _recorded;

  /// Records a finished test for memorization: every ayah it covered whole,
  /// graded from its words (wrong, skipped or revealed by hand, corrected,
  /// and this pass's pronunciation mistakes).
  void _record(HifzJudge judge) {
    final sessionId = _sessionId;
    if (identical(_recorded, judge) || sessionId == null) return;
    _recorded = judge;
    final corpus = judge.corpus;
    final pass = _pass;
    final at = ref.read(recitationClockProvider)();
    final hidden = ref.read(mushafHideModeProvider).enabled;
    final recorder = ref.read(memorizationRecorderProvider);
    final settle = ref.read(memorizationRecordDelayProvider);
    // Activity: the words heard recited, and the ayahs recited whole.
    final recited = {
      for (final p in judge.revealed)
        if (!judge.given.contains(p)) p,
    };
    if (recited.isNotEmpty) {
      final byAyah = <int, int>{};
      for (final p in recited) {
        final a = corpus.words[p].ref.ayahId;
        byAyah[a] = (byAyah[a] ?? 0) + 1;
      }
      var whole = 0;
      for (final MapEntry(key: a, value: n) in byAyah.entries) {
        final verse = (chapterNo: a ~/ 1000, verseNo: a % 1000);
        final first = corpus.verseStartPosition(verse);
        final last = corpus.verseEndPosition(verse);
        if (first != null && last != null && n >= last - first + 1) whole++;
      }
      ref
          .read(activityStatsProvider.notifier)
          .add(recitedWords: recited.length, recitedAyahs: whole);
    }
    final outcomes = {
      for (final p in judge.revealed)
        if (p >= judge.start && p <= judge.end && !judge.given.contains(p))
          corpus.words[p].ref: switch (judge.marked[p]) {
            HifzVerdict.wrong => WordOutcome.wrong,
            HifzVerdict.skipped => WordOutcome.skipped,
            HifzVerdict.selfCorrected => WordOutcome.selfCorrected,
            _ => WordOutcome.correct,
          },
    };
    int ayahWords(int ayahId) {
      final verse = (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000);
      final first = corpus.verseStartPosition(verse);
      final last = corpus.verseEndPosition(verse);
      return first == null || last == null ? 0 : last - first + 1;
    }

    var acoustic = ref.read(acousticVerificationControllerProvider).words;
    unawaited(() async {
      // The last ayah's pronunciation check may still be running: graded
      // on confirmed verdicts once it is done (or a few seconds on).
      if (settle > Duration.zero) {
        await Future<void>.delayed(settle);
        for (var i = 0; i < 20 && ref.mounted; i++) {
          if (ref.read(acousticVerificationControllerProvider).pending == 0) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      if (ref.mounted) {
        acoustic = ref.read(acousticVerificationControllerProvider).words;
      }
      final attempts = gradeTest(
        [
          for (final MapEntry(key: w, value: o) in outcomes.entries)
            TestWord(
              w,
              o,
              pronunciationMistake: switch (acoustic[w]) {
                final a? => a.isMistake && !a.provisional && a.pass == pass,
                null => false,
              },
            ),
        ],
        ayahWords: ayahWords,
        sessionId: sessionId,
        at: at,
        hidden: hidden,
      );
      if (attempts.isNotEmpty) await recorder(attempts);
    }());
  }

  /// Shows the page holding [word] if it is not on screen (a loop going
  /// back to its start). Returns whether the page is to change.
  bool _showWord(WordRef word) {
    final pages = _visiblePages();
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (pages == null || location is! QuranLocationPage) return false;
    final ranges = ref.read(mushafPageWordRangesProvider);
    final first = ranges[pages.$1], last = ranges[pages.$2];
    if (first != null &&
        last != null &&
        compareWordRefs(word, first.first) >= 0 &&
        compareWordRefs(word, last.last) <= 0) {
      return false;
    }
    // The pages on screen are about to change by request, not by the
    // reciter's hand: the test stays where it is.
    _seenPages = null;
    unawaited(() async {
      final page = await ref
          .read(quranRepositoryProvider)
          .getPageForAyah(mushafId: location.mushafId, ayahId: word.ayahId);
      if (page == null || !ref.mounted) return;
      ref.read(mushafPageTurnRequestsProvider.notifier).toPage(page);
    }());
    return true;
  }

  /// Turns the page when the expected word has moved off what is shown —
  /// forward as recitation continues, back after hiding back.
  void _followPage() {
    // (Once the words recited are all shown.)
    if (_held.isNotEmpty) return;
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
