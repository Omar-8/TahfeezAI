import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/acoustic/local_quran_acoustic_model.dart';
import '../../../ai/acoustic/pcm_ring.dart';
import '../../../ai/acoustic/quran_acoustic_model.dart';
import '../../../ai/acoustic/quran_acoustic_verifier.dart';
import '../../../ai/acoustic/quran_phonetic_reference.dart';
import '../../../ai/acoustic/remote_acoustic_model.dart';
import '../../../ai/matching/local_quran_position_tracker.dart'
    show WordPlacement;
import '../../../core/core_providers.dart';
import '../../../quran/domain/models/quran_refs.dart';
import 'local_acoustic_inference_controller.dart';
import 'hifz_controller.dart' show hifzSettingsProvider;
import 'recitation_ai_config.dart';
import 'recitation_position.dart';
import 'quran_match_controller.dart' show quranWordCorpusProvider;
import 'recitation_session_controller.dart';

/// Where the development server runs the acoustic model
/// (`tool/acoustic_verification/server.py`), for
/// [QuranAcousticBackend.remoteDevelopment].
final acousticServerUrlProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'TAHFEEZ_ACOUSTIC_URL',
    defaultValue: 'http://127.0.0.1:8790',
  ),
);

/// The acoustic model the verifier listens with, per
/// [recitationAiConfigProvider]: on the device, the development server, or
/// none.
final quranAcousticModelProvider = Provider<QuranAcousticModel?>((ref) {
  switch (ref.watch(recitationAiConfigProvider).acoustic) {
    case QuranAcousticBackend.local:
      return ref.watch(localQuranAcousticModelProvider);
    case QuranAcousticBackend.remoteDevelopment:
      final url = ref.watch(acousticServerUrlProvider);
      if (url.isEmpty) return null;
      return RemoteAcousticModel(
        network: ref.watch(networkClientProvider),
        baseUrl: url,
      );
    case QuranAcousticBackend.disabled:
      return null;
  }
});

/// The expected pronunciation of every ayah.
final quranPhoneticReferenceProvider = FutureProvider<QuranPhoneticReference>((
  ref,
) async {
  final raw = await rootBundle.loadString(
    'assets/quran/recitation/phonetic_reference_hafs.json',
  );
  return compute(
    (String raw) => QuranPhoneticReference.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    ),
    raw,
  );
});

/// Confirm mistakes with a second view of the audio (shifted 20 ms): a
/// word is marked wrong only if both find the mistake. Doubles the model
/// work per piece. Off until measured on the benchmark.
final acousticConfirmProvider = Provider<bool>((ref) => false);

/// How one recited word sounded.
class AcousticWordResult {
  const AcousticWordResult(
    this.type,
    this.errors, {
    this.provisional = false,
    this.pass = 0,
  });

  /// [RecitationErrorType.correct], [RecitationErrorType.uncertain], or the
  /// most serious mistake heard in the word.
  final RecitationErrorType type;

  /// The mistakes (and uncertain sounds) in the word.
  final List<RecitationError> errors;

  /// An early verdict from the word's quick check, until its ayah's check
  /// confirms or replaces it.
  final bool provisional;

  /// The Hifz test's pass the word was recited in (a loop recites the same
  /// words again; see `recitationPassProvider`).
  final int pass;

  bool get isMistake => type.isError;

  /// A mistake shown and alerted at once, though only [provisional]: the
  /// kinds a quick check is rarely wrong about. Replaying 30 phone
  /// sessions (model v3.5s, 2026-10-10), quick verdicts of a wrong vowel
  /// heard with llr ≥ [sureVowelLlr], or a wrong letter with llr ≥
  /// [sureLetterLlr], were confirmed by their ayah's check 24 times in 28;
  /// sukun verdicts only 10 in 34. Every other quick verdict waits for the
  /// ayah's check.
  bool get isSure =>
      isMistake &&
      (!provisional ||
          errors.any(
            (e) =>
                (e.type == RecitationErrorType.wrongVowel &&
                    e.likelihoodRatio >= sureVowelLlr) ||
                (e.type == RecitationErrorType.wrongLetter &&
                    e.likelihoodRatio >= sureLetterLlr),
          ));

  static const sureVowelLlr = 6.0, sureLetterLlr = 8.0;
}

class AcousticVerificationState {
  const AcousticVerificationState({
    this.active = false,
    this.words = const {},
    this.utterances = 0,
    this.pending = 0,
    this.lastLatency,
    this.lastModelTime,
    this.lastMistake,
    this.lastQuality,
    this.error,
  });

  /// Listening to a session.
  final bool active;
  final Map<WordRef, AcousticWordResult> words;

  /// Utterances verified, and waiting.
  final int utterances, pending;

  /// From the end of an utterance to its verdicts; of that, the model.
  final Duration? lastLatency, lastModelTime;
  final RecitationError? lastMistake;

  /// The audio quality of the last piece checked.
  final AudioQuality? lastQuality;
  final String? error;

  AcousticVerificationState copyWith({
    bool? active,
    Map<WordRef, AcousticWordResult>? words,
    int? utterances,
    int? pending,
    Duration? lastLatency,
    Duration? lastModelTime,
    RecitationError? lastMistake,
    AudioQuality? lastQuality,
    String? Function()? error,
  }) => AcousticVerificationState(
    active: active ?? this.active,
    words: words ?? this.words,
    utterances: utterances ?? this.utterances,
    pending: pending ?? this.pending,
    lastLatency: lastLatency ?? this.lastLatency,
    lastModelTime: lastModelTime ?? this.lastModelTime,
    lastMistake: lastMistake ?? this.lastMistake,
    lastQuality: lastQuality ?? this.lastQuality,
    error: error == null ? this.error : error(),
  );
}

/// How usable a piece of audio is for judging pronunciation.
///
/// Only checks that proved reliable on clean recitation are used: too
/// quiet, or clipped. (A noise estimate from loudness percentiles was
/// tried and dropped — continuous, reverberant recitation reads as "noisy"
/// by that measure, so it would have distrusted good audio.)
class AudioQuality {
  const AudioQuality({required this.speechLevel, required this.clipped});

  factory AudioQuality.of(Float32List x) {
    const frame = 320;
    final levels = <double>[];
    var clipped = 0;
    for (var i = 0; i + frame <= x.length; i += frame) {
      var sum = 0.0;
      for (var k = i; k < i + frame; k++) {
        sum += x[k] * x[k];
        if (x[k].abs() >= 0.99) clipped++;
      }
      levels.add(math.sqrt(sum / frame));
    }
    if (levels.length < 5) {
      return const AudioQuality(speechLevel: 0, clipped: 0);
    }
    levels.sort();
    return AudioQuality(
      speechLevel: levels[levels.length * 9 ~/ 10],
      clipped: x.isEmpty ? 0 : clipped / x.length,
    );
  }

  /// Loudness of the speech: the 90th percentile of 20 ms RMS levels.
  final double speechLevel;

  /// Share of samples at full scale.
  final double clipped;

  /// Why mistakes heard in this audio can't be trusted, or `null`.
  String? get problem {
    if (speechLevel < 0.005) return 'too quiet';
    if (clipped > 0.005) return 'distorted (too loud)';
    return null;
  }

  @override
  String toString() {
    final db = 20 * math.log(math.max(speechLevel, 1e-6)) / math.ln10;
    return 'level ${db.round()} dBFS${problem == null ? '' : ' ($problem)'}';
  }
}

/// A piece of recitation to verify.
class _Job {
  _Job({
    required this.samples,
    required this.start,
    required this.end,
    required this.targets,
    required this.from,
    required this.to,
    required this.openStart,
    required this.openEnd,
    required this.pass,
    this.frames,
    this.wordEnd,
  }) : quality = AudioQuality.of(samples);

  final Float32List samples;

  /// Where [samples] are in the session's audio (stream positions).
  final int start, end;
  final AudioQuality quality;

  /// The words whose results this piece decides.
  final Set<WordRef> targets;

  /// Corpus positions of the candidate words the piece is located among.
  final int from, to;

  /// The audio was cut mid-recitation on that side.
  final bool openStart, openEnd;

  /// The Hifz test's pass the audio was recited in.
  final int pass;

  /// A quick check's: frames already computed (the tracker's), so no
  /// model run, and only strong mistakes reported.
  final AcousticFrames? frames;
  bool get quick => frames != null;

  /// A quick check's: its word's last frame, where the tracker placed it
  /// (in [frames]).
  final int? wordEnd;
  final queued = DateTime.now();
}

/// Quran Acoustic Verification, live.
///
/// Runs beside the coarse recognizer: that one answers "where are we?"
/// (the Hifz test's next expected word), this one "was it pronounced
/// correctly?". Audio is sent **per ayah**: when the recognizer moves on
/// to the next ayah, the finished ayah's audio (from the session's own
/// PCM) goes to the acoustic model, is located among the words around it
/// and verified sound by sound against the expected Hafs pronunciation.
/// Nothing is sent for audio the recognizer found no Quran words in. A long
/// ayah is also sent in pieces every [_longPiece] while Quran words keep
/// being recognized; pausing or stopping sends the part said so far.
/// Results are per word ([WordRef]); a later check replaces an earlier one.
///
/// With the on-device model ([QuranAcousticBackend.local]) nothing is run
/// twice: the audio is [LocalAcousticInferenceController]'s, and each
/// piece is checked on the frames that pipeline already computed (and the
/// position tracker followed).
class AcousticVerificationController
    extends Notifier<AcousticVerificationState> {
  static const _rate = 16000;

  /// Audio kept before an ayah's first recognized word (the recognizer
  /// lags the voice), and after its last (the word's tail).
  static const _lead = 3 * _rate;
  static const _tail = Duration(seconds: 1);
  static const _firstLead = 8 * _rate;

  /// A long ayah is sent in pieces this long, while Quran words are being
  /// recognized (within [_recent]).
  static const _longPiece = 20 * _rate;
  static const _recent = 4 * _rate;

  /// The longest piece sent at once.
  static const _maxPiece = 45 * _rate;

  /// Candidate words around a piece's own.
  static const _lookBack = 3;

  /// The second view's offset when confirming (20 ms).
  static const _shift = 320;
  static const _lookAhead = 6;

  /// The most recent audio (90 s), indexed by stream position — the
  /// inference pipeline's own with the local model.
  PcmRing _pcm = PcmRing();
  int get _written => _pcm.written;
  LocalAcousticInferenceController? _inference;

  /// Where the current ayah's audio starts, and its first word.
  int _ayahStart = 0;
  int? _ayahFirstWord;

  /// When the recognizer last placed a Quran word; when audio was last sent.
  int _lastProgress = -1 << 40;
  int _lastSent = 0;

  QuranAcousticModel? _model;
  StreamSubscription<Object?>? _audio;
  final _queue = <_Job>[];
  bool _busy = false;
  String? _sessionId;
  int _generation = 0;

  /// The Hifz test's pass being recited: on the device, as the placements
  /// say (they arrive after the test has moved on); otherwise as published.
  int _pass = 0;

  /// The reciter's beat this session (for madds a word's own check judges).
  final _beat = BeatMeter();
  final _verifier = const QuranAcousticVerifier(
    thresholds: calibratedThresholds,
  );

  /// The on-device model's calibration (`tool/acoustic_verification/model_work`):
  /// a mistake needs a margin of 4 (vowels, letters, shadda) or 3 (sukun,
  /// missing vowel). Shadda / sukun / missing vowel were 2 / 1 / 1 (v2.2, chosen
  /// on professional reciters); on amateurs' recitation those fired on correct
  /// words. Measured with v2.4 at 4 / 3 / 3: test mistakes caught about the
  /// same (shadda 93-94%, sukun 69%, missing vowel 93 -> 89%), false flags down.
  ///
  /// A sound is uncertain only when an alternative is at least 1 more likely
  /// (2 more for [learnerSounds]), and a stop of 160 ms counts as a pause.
  /// Measured with v2.5 (`tune_sound_margins.dart`): correct words left
  /// uncertain in a reciter's phone sessions 12.6 -> 4.8%, in amateurs'
  /// correct clips 36.7 -> 10.1%; flagged 3.7 -> 3.5% and 5.5 -> 4.6%; test
  /// mistakes found unchanged (91.1%, phone-like audio 90.7%). The price:
  /// in amateurs' clips judged incorrect, words marked at all 47 -> 35%.
  static const calibratedThresholds = AcousticThresholds(
    error: 4,
    letterError: 4,
    shaddaError: 4,
    sukunError: 3,
    missingVowelError: 3,
    correct: -1,
    pauseFrames: 4,
    sounds: learnerSounds,
  );

  /// Sounds whose evidence is naturally weak in learners' correct
  /// recitation: their extra margins. A vowel reduced to almost nothing is
  /// a mistake only with clearer evidence (+1, a unit's last vowel +2). A
  /// qalqala letter with sukun or at a stop (its echo blurs it): +2 / +4 —
  /// on QDAT's amateur recitations judged good, its false mistakes 1.4 ->
  /// 0.8%, uncertain 6.3 -> 4.9%, with test mistakes found unchanged.
  ///
  /// A word's last vowel said as another (a case ending, a frame or two
  /// long) needs 1 less; said as a stop on its qalqala letter, though the
  /// next word follows at once, it is a missing vowel at 1 more. Measured
  /// with v3.5 (`final_vowels.dart`, the session replay): QuranMB's
  /// word-final swaps caught 54.9 -> 64.6%, correct words flagged in the
  /// user's sessions 110 -> 111 of 1705, in QuranMB's / Al-Ikhlas's / QDAT's
  /// correct clips 161 -> 162 / unchanged / 880 -> 881.
  ///
  /// A hidden nūn or mīm (ikhfāʾ, iqlāb) heard as a clear one needs 1 less:
  /// v3.6 is less sure of it than v3.5 (the owner's plain nūn in
  /// «ٱلْإِنسَـٰنَ», 103:2: 3.1 vs 5.1), reported as noon and meem rarely
  /// marked (2026-10-18). On QDAT's held-out learners missed ikhfāʾ caught
  /// 63.5 -> 66.9%, correct flagged 10.8 -> 11.8%; the user's and amateurs'
  /// correct words flagged unchanged. (+2 / +4 had cost 63.5 -> 55.1%.)
  ///
  /// Letters that sound alike (ك ء, ف ت, ذ د, ل ن …: [SoundGroup.similarLetter])
  /// need 2 more: reported as letters heard wrongly while said right
  /// (2026-10-19). With v3.6 (`bootstrap.dart`, speaker-resampled), correct
  /// words flagged: the user's 5.5 -> 5.2%, amateurs' 4.6 -> 4.2%, held-out
  /// Juz 30 reciters' 35.4 -> 33.6%, Tarteel users' 16.1 -> 15.6%; QuranMB's
  /// real mistakes caught 68.2 -> 68.1%, Al-Ikhlas's unchanged. (+3: the
  /// user's 5.1%, QuranMB 67.7%.)
  ///
  /// v3.7 (2026-10-21; fine-tuned on real phone recordings) hears vowels a
  /// little more leniently than v3.6, so its vowel margins are 1 lower: a
  /// reduced vowel at +0 (was +1), a unit's last vowel at +1 (was +2), a
  /// word's last vowel (a case ending) at -2 (was -1). Letters unchanged.
  /// Measured with v3.7 against v3.6 at its own margins (`tune_sound_margins`,
  /// `real_mistakes`, `final_vowels`): QuranMB's real mistakes caught 66.2 ->
  /// 66.7% (v3.6 68.1%), Al-Ikhlas's 12.4 -> 12.7% (v3.6 12.7%), case endings
  /// said -u as -a caught 14/21 -> 17/21 (v3.6 13/21); correct words flagged
  /// unchanged (the user's 4.6%, amateurs' 4.2%, professionals' 1.8%; v3.6
  /// 5.2 / 4.2 / 2.0%). Stronger (-0.5 / +0.5 / -2.5) caught QuranMB 67.2%
  /// but flagged amateurs 5.1%.
  static const learnerSounds = {
    SoundGroup.shadda: SoundMargins(uncertain: 2),
    SoundGroup.reducedVowel: SoundMargins(error: 0, uncertain: 2),
    SoundGroup.finalVowel: SoundMargins(error: 1, uncertain: 2),
    SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
    SoundGroup.nasal: SoundMargins(uncertain: 2),
    SoundGroup.hiddenNasal: SoundMargins(error: -1),
    SoundGroup.throat: SoundMargins(uncertain: 2),
    SoundGroup.similarLetter: SoundMargins(error: 2),
    SoundGroup.wordFinalVowel: SoundMargins(error: -2),
    SoundGroup.stopInFlow: SoundMargins(error: 1),
  };

  /// The quick check's: no lower margin for a case ending, a stop in flow
  /// at 2 more (an early mark only for a clear mistake).
  static const _quickSounds = {
    SoundGroup.shadda: SoundMargins(uncertain: 2),
    SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
    SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
    SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
    SoundGroup.nasal: SoundMargins(uncertain: 2),
    SoundGroup.throat: SoundMargins(uncertain: 2),
    SoundGroup.similarLetter: SoundMargins(error: 2),
    SoundGroup.stopInFlow: SoundMargins(error: 2),
  };

  /// The quick per-word check's: stricter, as its frames (the tracker's
  /// short streaming windows) have less context around each word than the
  /// ayah's own run — an early mark is shown only for a clear mistake.
  /// Measured against the ayah check on the calibration set (v2.5, 1 s / 0.5 s
  /// windows; `evaluate.dart --early`): 82% of the mistakes are marked early,
  /// 3% of early marks taken back. Looser (6 / 6 / 4 / 4 / 4, 88% and 4% in
  /// that test) took back every early mark of a phone session at the app's
  /// 0.5 s / 0.3 s windows, so not used.
  static const quickThresholds = AcousticThresholds(
    error: 8,
    letterError: 8,
    shaddaError: 4,
    sukunError: 4,
    missingVowelError: 4,
    correct: 0,
    pauseFrames: 4,
    sounds: _quickSounds,
  );
  final _quickVerifier = const QuranAcousticVerifier(
    thresholds: quickThresholds,
  );

  /// [verifier] judging tajweed or not, as the Hifz settings say.
  QuranAcousticVerifier _withTajweed(QuranAcousticVerifier verifier) {
    final settings = ref.read(hifzSettingsProvider);
    final tajweed = settings.tajweed;
    // The streaming model (v3.4): a missing vowel or sukun at 2, not 3.
    // Learners' «كُفُوًا» said «كُفْوًا» (Surah Al-Ikhlas set): marked 24% -> 34%;
    // the user's correct words flagged 6.1% -> 6.3%, amateurs' correct clips
    // 8.7% -> 10.1%, calibration unchanged.
    return QuranAcousticVerifier(
      thresholds: verifier.thresholds.copyWith(
        tajweed: tajweed,
        tajweedRules: settings.tajweedRules,
        error: _streaming ? streamingError : null,
        letterError: _streaming ? streamingError : null,
        shaddaError: _streaming ? streamingError : null,
        sukunError: _streaming ? streamingMinorError : null,
        missingVowelError: _streaming ? streamingMinorError : null,
        qalqalaError: _streaming ? streamingQalqalaError : null,
      ),
    );
  }

  /// A missing vowel or sukun, at 3 (v3.5: 2): v3.6 at 2 flagged more of the
  /// user's correct words (5.9 vs 5.5%) for the same mistakes found.
  static const streamingMinorError = 3.0;

  /// The streaming model v3.6 (`model_work`, round 6, G2e): a slimmer student
  /// (feed-forwards 2048, pruned by activity; 8-bit, the rest 4-bit) distilled
  /// further on learners' real mistakes, with v3.5 a second teacher on
  /// amateurs' clips (the teachers flag 9-13% of their correct words). Chosen
  /// strict (owner, 2026-10-18): at 3, against v3.5 at 4 (both with these
  /// margins; `real_mistakes.dart --margins`), real mistakes found nearly as
  /// many — QuranMB's held-out speakers 67.9 vs 68.7% (their correct words
  /// flagged 29.6 vs 32.7%), Al-Ikhlas learners 12.7 vs 13.8% (2.4 vs 2.8%) —
  /// spliced mistakes 88.7 vs 85.1%, case endings u -> a 10 vs 2 of 21; the
  /// price: correct words flagged, the user's 5.5 vs 5.1%, amateurs' 4.6 vs
  /// 3.4%. (At 2.5: QuranMB 70.1%, Al-Ikhlas 13.6%, more flagged.)
  static const streamingError = 3.0;

  /// A missing qalqala echo, at 2: v3.5s on the held-out Surah Al-Ikhlas
  /// learners catches 19.2% of labelled misses, flags 2.5% of correct ones; the
  /// user's phone sessions and professional recitation no more than at 3.
  static const streamingQalqalaError = 2.0;

  @override
  AcousticVerificationState build() {
    _model = ref.watch(quranAcousticModelProvider);
    final local =
        ref.watch(recitationAiConfigProvider).acoustic ==
        QuranAcousticBackend.local;
    _inference = local
        ? ref.watch(localAcousticInferenceControllerProvider.notifier)
        : null;
    _pcm = _inference?.pcm ?? PcmRing();
    ref.onDispose(_stop);
    ref.listen(
      recitationSessionControllerProvider,
      (_, next) => _onSession(next),
      fireImmediately: true,
    );
    if (_inference case final inference?) {
      // On the device: each ayah on the frames its words were placed in.
      final sub = inference.placements.listen(_onPlacements);
      ref.onDispose(sub.cancel);
    } else {
      ref.listen<WordRef?>(
        recitationPositionProvider,
        (previous, next) => _onPosition(previous, next),
      );
      ref.listen<int>(recitationPassProvider, (_, next) => _pass = next);
    }
    return const AcousticVerificationState();
  }

  void _onSession(RecitationSessionState session) {
    final listening = session.phase == RecitationPhase.listening;
    final id = session.session?.id;
    if (listening && _audio == null && _model != null) {
      if (id != _sessionId) {
        _sessionId = id;
        _generation++; // a new session: drop the old one's audio
        _beat.reset();
        _queue.clear();
        _waitingQuick.clear();
        if (_inference == null) _pcm.reset();
        _ayahStart = 0;
        _ayahFirstWord = null;
        _lastSent = 0;
        _piece = [];
        _pass = _inference == null ? ref.read(recitationPassProvider) : 0;
        _lastEnd = null;
        _pieceFloor = null;
        state = const AcousticVerificationState(active: true);
      }
      _start();
    } else if (!listening && _audio != null) {
      // Paused or stopped: the part of the ayah said so far (on the
      // device, once the tracker has placed it — see [_onPlacements]).
      if (_inference == null) _sendCurrent(openEnd: false);
      _stop();
      if (!session.isActive) state = state.copyWith(active: false);
    }
  }

  void _start() {
    final session = ref.read(recitationSessionControllerProvider.notifier);
    final format = session.liveFormat;
    if (format == null || format.sampleRate != 16000 || format.channels != 1) {
      state = state.copyWith(error: () => 'Needs 16 kHz mono audio');
      return;
    }
    void onAudio() {
      _retryQuick();
      // A long ayah: send what has been recited of it so far.
      if (_inference == null &&
          _written - _ayahStart >= _longPiece &&
          _written - _lastSent >= _longPiece &&
          _written - _lastProgress <= _recent) {
        _sendCurrent(openEnd: true);
      }
    }

    final inference = _inference;
    _audio = inference != null
        // One microphone, one pipeline: its audio, as it arrives.
        ? inference.progress.listen((_) => onAudio())
        : session.liveAudio.listen((chunk) {
            _pcm.addPcm16(chunk);
            onAudio();
          });
    state = state.copyWith(active: true);
  }

  void _stop() {
    unawaited(_audio?.cancel());
    _audio = null;
  }

  /// The recognizer moved: a finished ayah is sent once its last word's
  /// tail has been heard.
  void _onPosition(WordRef? previous, WordRef? next) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    if (corpus == null || next == null || _audio == null) return;
    _lastProgress = _written;
    final to = corpus.positionOf(next);
    final from = previous == null ? null : corpus.positionOf(previous);
    if (to == null) return;
    _ayahFirstWord ??= corpus.verseStartPosition(corpus.words[to].verse);
    if (from == null || to < from || to - from > 40) {
      // The reciter just found, or a jump (going back, a new page): start
      // over from here — with more lead-in the first time, as the
      // recognizer needed a few words to find them.
      _ayahStart = (_written - (from == null ? _firstLead : _lead)).clamp(
        0,
        _written,
      );
      _ayahFirstWord = corpus.verseStartPosition(corpus.words[to].verse);
      return;
    }
    if (corpus.words[to].verse == corpus.words[from].verse) return;
    // Into a new ayah: the ones before it are done.
    final first = _ayahFirstWord ?? from;
    final start = _ayahStart;
    final generation = _generation;
    _ayahStart = (_written - _lead).clamp(0, _written);
    _ayahFirstWord = corpus.verseStartPosition(corpus.words[to].verse);
    Timer(_tail, () {
      if (!ref.mounted || generation != _generation) return;
      _send(start, _written, first, to - 1, openStart: true, openEnd: true);
    });
  }

  /// The words of the ayah being placed (on the device).
  var _piece = <WordPlacement>[];

  /// The longest piece sent at once on the device (30 s of frames).
  static const _maxPieceFrames = 750;

  /// Audio kept around a placed piece (1 s each side): the tracker's word
  /// boundaries come from short streaming windows and can clip a word's first
  /// or last sounds, which the verifier then reports as missing. With a
  /// generous margin it finds the words itself ([QuranAcousticVerifier.locate]).
  /// (Measured on phone recordings: the tight 0.32 s cut roughly doubled the
  /// words wrongly flagged.)
  static const _pieceMargin = 25;

  /// The tracker placed words: an ayah is checked once the next one starts
  /// (or the reciter goes back, or pauses), on exactly the frames its
  /// words were heard in — not on the last seconds of audio, which the
  /// tracker's lag would make the wrong seconds.
  void _onPlacements(WordPlacements event) {
    if (_audio == null && !event.paused) return;
    _retryQuick();
    if (event.pass != _pass) {
      // A loop started again: the words of the last pass are checked as
      // recited in it.
      if (_piece.isNotEmpty) _sendPlaced(_piece, paused: false);
      _piece = [];
      _pass = event.pass;
    }
    for (final w in event.words) {
      final piece = _piece;
      // Placed: the tracker has heard past its end. A quick check on the
      // frames already computed, for an early mistake mark (at a pause the
      // ayah's own check follows at once).
      // After a stop, a word's audio starts inside the stop: the margin
      // before it would hold the last ayah's end (ٱلرَّحِيمِ's م heard as
      // the first of مَالِكِ's, an extra shadda).
      final floor = _afterStop(w);
      if (!event.paused) _quick(w, floor: floor);
      if (piece.isNotEmpty &&
          (w.ref.ayahId != piece.last.ref.ayahId ||
              !_after(w.ref, piece.last.ref) ||
              w.end - piece.first.start > _maxPieceFrames)) {
        // On into the next ayah without stopping: the ayah's end is said
        // in flow (لِّلْمُصَلِّينَ ٱلَّذِينَ: its ن with fatha, the hamza
        // after it not said) — not judged as a stop and a fresh start.
        final joined = _joined(piece.last, w);
        _sendPlaced(piece, paused: false, joinedEnd: joined);
        _piece = [];
        _pieceJoinedStart = joined;
      }
      if (_piece.isEmpty && piece.isEmpty) _pieceJoinedStart = false;
      if (_piece.isEmpty) _pieceFloor = floor;
      _piece.add(w);
      _lastEnd = w.end;
    }
    if (event.paused && _piece.isNotEmpty) {
      _sendPlaced(_piece, paused: true);
      _piece = [];
    }
    if (event.paused) _pieceJoinedStart = false;
  }

  /// The piece being placed began joined to the ayah before it.
  bool _pieceJoinedStart = false;

  /// The end frame of the last word placed, and the first frame the piece
  /// being placed may start at (inside a stop before it; `null`: no stop).
  int? _lastEnd, _pieceFloor;

  /// A stop before [w] (at least [QuranAcousticVerifier.stopInsideFrames]
  /// between the last word placed and it): the frame halfway through it.
  int? _afterStop(WordPlacement w) {
    final last = _lastEnd;
    if (last == null ||
        w.start - last - 1 < QuranAcousticVerifier.stopInsideFrames) {
      return null;
    }
    return (last + w.start) ~/ 2;
  }

  /// Whether [next] (in the next ayah) was said straight after [last], with
  /// no stop between them — read from the frames around the gap.
  bool _joined(WordPlacement last, WordPlacement next) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    final store = _inference?.store;
    if (corpus == null || store == null) return false;
    final a = corpus.positionOf(last.ref), b = corpus.positionOf(next.ref);
    if (a == null || b != a + 1) return false;
    final frames = store.slice(
      math.max(store.start, last.end - 2),
      math.min(store.end, next.start + 3),
    );
    if (frames == null) return false;
    return !_verifier.pauseBetween(frames.frames, -1, frames.frames.frames);
  }

  /// [a] comes after [b] in the Quran.
  static bool _after(WordRef a, WordRef b) =>
      a.ayahId > b.ayahId ||
      (a.ayahId == b.ayahId && a.wordIndex > b.wordIndex);

  void _sendPlaced(
    List<WordPlacement> words, {
    required bool paused,
    bool joinedEnd = false,
  }) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    if (corpus == null) return;
    final first = corpus.positionOf(words.first.ref);
    final last = corpus.positionOf(words.last.ref);
    if (first == null || last == null) return;
    const spf = 640;
    final start =
        (math.max(words.first.start - _pieceMargin, _pieceFloor ?? 0) * spf)
            .clamp(_pcm.oldest, _written);
    final end = ((words.last.end + 1 + _pieceMargin) * spf).clamp(
      start,
      _written,
    );
    if (end - start < _rate ~/ 4) return;
    final ayahEnd = corpus.verseEndPosition(corpus.words[last].verse);
    _queue.add(
      _Job(
        samples: _pcm.samples(start, end),
        start: start,
        end: end,
        targets: {for (final w in words) w.ref},
        from: (first - _lookBack).clamp(0, corpus.length - 1),
        to: (last + _lookAhead).clamp(0, corpus.length - 1),
        // Cut mid-ayah only where the piece starts or ends inside one.
        // (After a stop the reciter starts afresh, mid-ayah or not.)
        openStart:
            _pieceFloor == null &&
            (words.first.ref.wordIndex != 0 || _pieceJoinedStart),
        openEnd: (!paused && last != ayahEnd) || joinedEnd,
        pass: _pass,
      ),
    );
    if (_queue.length > 4) _queue.removeAt(0);
    state = state.copyWith(pending: _queue.length);
    unawaited(_pump());
  }

  /// Checks [word] at once on the tracker's frames, from a second before it
  /// through what has been heard after it (the next word's start decides
  /// how [word] ends: joined or not).
  void _quick(WordPlacement word, {int? floor}) {
    final inference = _inference;
    final corpus = ref.read(quranWordCorpusProvider).value;
    if (inference == null || corpus == null) return;
    final at = corpus.positionOf(word.ref);
    if (at == null) return;
    final store = inference.store;
    final first = math.max(
      store.start,
      math.max(word.start - _pieceMargin, floor ?? 0),
    );
    final last = math.min(store.end, word.end + 1 + _pieceMargin);
    // Too little heard after it to judge its end yet — a word that close
    // to the audio's end is taken as cut off ([_verify]'s `dropLast`): it
    // is checked as soon as the next frames arrive ([_retryQuick]), not
    // left for its ayah's check, seconds later (a word ending near a
    // streaming chunk's end).
    if (last - word.end < _quickTail) {
      _waitingQuick.add((word: word, floor: floor, pass: _pass));
      return;
    }
    final frames = store.slice(first, last);
    if (frames == null || frames.frames.frames < 10) return;
    const spf = 640;
    final start = math.max(first * spf, _pcm.oldest);
    final end = math.max(start, math.min(frames.end * spf, _written));
    final job = _Job(
      samples: _pcm.samples(start, end),
      start: start,
      end: end,
      targets: {word.ref},
      from: (at - _lookBack).clamp(0, corpus.length - 1),
      to: (at + 2).clamp(0, corpus.length - 1),
      openStart: floor == null,
      openEnd: true,
      pass: _pass,
      frames: frames.frames,
      wordEnd: word.end - frames.start,
    );
    final generation = _generation;
    unawaited(() async {
      try {
        if (generation == _generation) await _verify(job);
      } catch (e) {
        if (!kReleaseMode) debugPrint('Acoustic quick check: $e');
      }
    }());
  }

  /// Frames a quick check needs after its word: more than [_verify]'s
  /// edge margin (8), which drops a word that close to the audio's end.
  static const _quickTail = 9;

  /// Placed words whose quick check waits for a little more audio after
  /// them ([_quick]).
  final _waitingQuick = <({WordPlacement word, int? floor, int pass})>[];

  /// Runs the waiting quick checks that now have the frames they need (the
  /// same check, once enough has been heard after the word). Replaying 30
  /// phone sessions (v3.5, 2026-10-16): 90% of words judged within 1.6 s
  /// of their end instead of 2.8 s; final verdicts unchanged.
  void _retryQuick() {
    final store = _inference?.store;
    if (store == null || _waitingQuick.isEmpty) return;
    final ready = [
      for (final w in _waitingQuick)
        if (store.end - w.word.end >= _quickTail) w,
    ];
    if (ready.isEmpty) return;
    _waitingQuick.removeWhere(ready.contains);
    for (final w in ready) {
      // (A loop started again meanwhile: that pass's own checks decide.)
      if (w.pass == _pass) _quick(w.word, floor: w.floor);
    }
  }

  /// The current ayah, as recited so far.
  void _sendCurrent({required bool openEnd}) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    final at = ref.read(recitationPositionProvider);
    final to = at == null ? null : corpus?.positionOf(at);
    final first = _ayahFirstWord;
    if (to == null || first == null || to <= first) return;
    _send(
      _ayahStart,
      _written,
      first,
      to - 1,
      openStart: true,
      openEnd: openEnd,
    );
  }

  void _send(
    int start,
    int end,
    int firstWord,
    int lastWord, {
    required bool openStart,
    required bool openEnd,
  }) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    if (corpus == null || end - start < _rate ~/ 2) return;
    final from = [
      start,
      end - _maxPiece,
      _pcm.oldest,
      0,
    ].reduce((a, b) => a > b ? a : b);
    final samples = _pcm.samples(from, end);
    _lastSent = end;
    _queue.add(
      _Job(
        samples: samples,
        start: from,
        end: end,
        targets: {
          for (var p = firstWord; p <= lastWord; p++) corpus.words[p].ref,
        },
        from: (firstWord - _lookBack).clamp(0, corpus.length - 1),
        to: (lastWord + _lookAhead).clamp(0, corpus.length - 1),
        openStart: openStart || from > start,
        openEnd: openEnd,
        pass: _pass,
      ),
    );
    if (_queue.length > 4) _queue.removeAt(0); // falling behind: drop oldest
    state = state.copyWith(pending: _queue.length);
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    final generation = _generation;
    try {
      while (_queue.isNotEmpty && ref.mounted && generation == _generation) {
        final job = _queue.removeAt(0);
        try {
          await _verify(job);
          if (ref.mounted) state = state.copyWith(error: () => null);
        } catch (e) {
          if (!kReleaseMode) debugPrint('Acoustic verification: $e');
          if (ref.mounted) state = state.copyWith(error: () => '$e');
        }
      }
    } finally {
      _busy = false;
      if (ref.mounted) state = state.copyWith(pending: _queue.length);
    }
  }

  Future<void> _verify(_Job job) async {
    final model = _model;
    final corpus = ref.read(quranWordCorpusProvider).value;
    final reference = await ref.read(quranPhoneticReferenceProvider.future);
    if (model == null || corpus == null || !ref.mounted) return;
    final span = reference.span([
      for (var p = job.from; p <= job.to; p++) corpus.words[p].ref,
    ]);
    // Two views of the audio when confirming: as recorded, and 20 ms later.
    final confirm = ref.read(acousticConfirmProvider);
    final runs = await Future.wait([
      _framesOf(model, job),
      if (confirm && _inference == null && job.samples.length > _shift * 10)
        model
            .run(Float32List.sublistView(job.samples, _shift))
            .then<AcousticFrames?>((f) => f),
    ]);
    var frames = runs.first;
    if (!ref.mounted) return;
    if (frames == null) {
      _log('piece no longer held: not checked');
      return;
    }
    // A quick check not located in its window (the word and what was heard
    // after it): its word alone, to just past where the tracker placed it
    // — whole, the next words' sounds stretch it to the window's end,
    // where it is dropped as cut off.
    final found = _verifier.locate(frames, span.tokens);
    final wordEnd = job.wordEnd;
    if (found == null &&
        job.quick &&
        wordEnd != null &&
        wordEnd + _quickTail < frames.frames) {
      frames = frames.slice(0, wordEnd + _quickTail);
    }
    // Located among the candidate words; failing that (a piece recited with
    // mistakes may fit them too poorly to be found), the words the tracker
    // placed it as — judged, not skipped: the worse a short ayah was said,
    // the likelier it was to go unchecked.
    final located = found ?? _placedUnits(span, job);
    if (located == null) {
      if (job.quick) return;
      _log('piece not found among ${span.tokens.length} tokens');
      state = state.copyWith(utterances: state.utterances + 1);
      return;
    }
    final (lo, hi) = located;
    final expected = [
      for (final t in span.tokens)
        if (t.unit >= lo && t.unit <= hi) t,
    ];
    final leadJudged = expected.any(
      (t) => t.unit == lo && job.targets.contains(t.word),
    );
    // A streaming model's frames are as good for one word as for its ayah:
    // its quick check is judged as fully.
    final verifier = _withTajweed(
      job.quick && !_streaming ? _quickVerifier : _verifier,
    );
    final verdicts = verifier.verify(
      frames,
      expected,
      pauses: {
        for (final MapEntry(:key, :value) in span.pauses.entries)
          if (key >= lo && key <= hi) key: value,
      },
      openStart: job.openStart,
      openEnd: job.openEnd,
      // Cut before its words: a first unit holding none of them is only
      // lead-in, whose start the cut may have taken.
      startInside: job.openStart && !leadJudged,
      beat: _beat,
    );
    // Only this piece's own words, and none cut off where the audio was
    // cut: the first / last unit is dropped only if it reaches within
    // 0.3 s of that edge.
    const margin = 8; // frames
    var firstStart = frames.frames, lastEnd = -1;
    for (final v in verdicts) {
      final span = v.span;
      if (span == null) continue;
      if (v.token.unit == lo && span.start < firstStart) {
        firstStart = span.start;
      }
      if (v.token.unit == hi && span.end > lastEnd) lastEnd = span.end;
    }
    final dropFirst = job.openStart && firstStart < margin;
    final dropLast = job.openEnd && lastEnd >= frames.frames - margin;
    // A word failing on several sounds may be another word of the passage
    // said in its place: one mistake naming it, not a run of letter swaps.
    final passage = <WordRef, List<PhoneticToken>>{};
    for (final t in span.tokens) {
      (passage[t.word] ??= []).add(t);
    }
    // Another word said in a word's place needs the passage around it: judged
    // in the ayah's check, not a word's quick one (whose short audio took
    // «هَٰذَا» for «ٱلْبَيْتِ» in a clean recitation).
    final swaps = {
      if (!job.quick)
        for (final s in verifier.wordSwaps(frames, verdicts, passage))
          s.word: s,
    };
    final byWord = <WordRef, List<PhonemeVerdict>>{};
    for (final v in verdicts) {
      if (!job.targets.contains(v.token.word)) continue;
      if (dropFirst && v.token.unit == lo) continue;
      if (dropLast && v.token.unit == hi) continue;
      (byWord[v.token.word] ??= []).add(v);
    }
    // On the device the frames are the tracker's (4–8 s windows), which
    // alone flag more correct words than a run over the whole piece
    // (benchmark: 4.4% against 2.9%). So a piece with a mistake is run
    // again on its own audio, and a mistake stands only if both hear it
    // (then 2.1%, with the same mistakes found) — a second run only for
    // the pieces that need one.
    final confirmFrames = runs.length > 1 ? runs[1] : null;
    // The second view, verified the same way: per word, its worst verdict.
    final second = <WordRef, RecitationErrorType>{};
    if (confirmFrames != null) {
      final vs2 = _verifier.verify(
        confirmFrames,
        expected,
        pauses: {
          for (final MapEntry(:key, :value) in span.pauses.entries)
            if (key >= lo && key <= hi) key: value,
        },
        openStart: job.openStart,
        openEnd: job.openEnd,
      );
      final byWord2 = <WordRef, List<PhonemeVerdict>>{};
      for (final v in vs2) {
        (byWord2[v.token.word] ??= []).add(v);
      }
      for (final MapEntry(key: w, value: vs) in byWord2.entries) {
        second[w] = _worst(vs);
      }
    }
    final words = Map.of(state.words);
    RecitationError? mistake;
    // Poor audio: nothing heard in it is held against the reciter.
    final trusted = job.quality.problem == null;
    if (job.quick && _streaming) {
      // Streaming: every word's verdict is shown as soon as it is heard
      // (correct, uncertain or a mistake), until its ayah's check confirms
      // or replaces it — never over that check's own verdict.
      if (!trusted) return;
      for (final MapEntry(key: word, value: vs) in byWord.entries) {
        if (!_mayReplace(state.words[word], job.pass, provisional: true)) {
          continue;
        }
        final swap = _swapError(swaps[word], frames.frameDuration);
        final worst = swap?.type ?? _worst(vs);
        final errors = swap != null
            ? [swap]
            : verifier.errors(vs, frames.frameDuration);
        words[word] = AcousticWordResult(
          worst,
          errors,
          provisional: true,
          pass: job.pass,
        );
        if (worst.isError) {
          mistake = errors.firstWhere((e) => e.type.isError);
        }
      }
      if (byWord.isNotEmpty) {
        _log('word ${byWord.keys.map(_ref).join(' ')}: ${mistake ?? 'fine'}');
      }
      state = state.copyWith(
        words: words,
        lastMistake: mistake ?? state.lastMistake,
      );
      return;
    }
    if (job.quick) {
      // Only a clear mistake is shown early, and never over the ayah's
      // own verdict.
      if (!trusted) return;
      for (final MapEntry(key: word, value: vs) in byWord.entries) {
        final worst = _worst(vs);
        if (!worst.isError ||
            !_mayReplace(state.words[word], job.pass, provisional: true)) {
          continue;
        }
        final errors = verifier.errors(vs, frames.frameDuration);
        words[word] = AcousticWordResult(
          worst,
          errors,
          provisional: true,
          pass: job.pass,
        );
        mistake = errors.firstWhere((e) => e.type.isError);
      }
      _log(
        'quick ${byWord.keys.map(_ref).join(' ')}: '
        '${mistake ?? 'no clear mistake'}',
      );
      if (mistake != null) {
        state = state.copyWith(words: words, lastMistake: mistake);
      }
      return;
    }
    // The ayah's check decides: an early mark on a word it has no verdict
    // for (cut at the piece's edge) is withdrawn.
    for (final word in job.targets) {
      if (!byWord.containsKey(word) &&
          words[word]?.provisional == true &&
          words[word]?.pass == job.pass) {
        words.remove(word);
      }
    }
    for (final MapEntry(key: word, value: vs) in byWord.entries) {
      // Recited again since (a loop): that repetition's verdict stands.
      if (!_mayReplace(words[word], job.pass)) continue;
      final swap = _swapError(swaps[word], frames.frameDuration);
      final errors = swap != null
          ? [swap]
          : _verifier.errors(vs, frames.frameDuration);
      var worst = swap?.type ?? _worst(vs);
      if (worst.isError && !trusted) worst = RecitationErrorType.uncertain;
      // Confirming: a mistake stands only if the second view hears one too.
      final other = second[word];
      if (confirmFrames != null &&
          worst.isError &&
          !(other?.isError ?? false)) {
        worst = RecitationErrorType.uncertain;
      }
      words[word] = AcousticWordResult(worst, errors, pass: job.pass);
      if (worst.isError) {
        mistake = errors.firstWhere((e) => e.type.isError);
      }
    }
    final remote = switch (model) {
      RemoteAcousticModel() => model.lastModelTime,
      LocalQuranAcousticModel() when confirmFrames != null => model.lastRunTime,
      _ => null,
    };
    _log(
      'piece ${(job.samples.length / 16000).toStringAsFixed(1)} s, '
      '${job.quality}: '
      'words ${byWord.keys.map(_ref).join(' ')}; '
      '${[for (final e in byWord.values.expand(_verifier.errorsOf)) e].join('; ')}',
    );
    state = state.copyWith(
      words: words,
      utterances: state.utterances + 1,
      pending: _queue.length,
      lastLatency: DateTime.now().difference(job.queued),
      lastModelTime: remote,
      lastMistake: mistake,
      lastQuality: job.quality,
    );
  }

  /// The piece's frames: one model run over the whole piece — the condition
  /// the verifier's thresholds were calibrated in. (Reusing the streaming
  /// windows' frames saved that run but judged words on frames computed with
  /// little context, which made many more words uncertain.)
  ///
  /// A streaming model's frames are already final where the tracker heard
  /// them: the piece is read from them, with no run of its own (`null` if
  /// the store no longer holds it). A quick check's frames are given.
  Future<AcousticFrames?> _framesOf(QuranAcousticModel model, _Job job) {
    if (job.frames != null) return Future.value(job.frames);
    if (_streaming) {
      // Up to what has been computed: the piece's margin after its last
      // word may still be in the chunk being heard.
      const spf = 640;
      final store = _inference!.store;
      return Future.value(
        store
            .slice(
              math.max(job.start ~/ spf, store.start),
              math.min(job.end ~/ spf, store.end),
            )
            ?.frames,
      );
    }
    return runInPieces(model, job.samples);
  }

  /// The on-device model streams (v3): its frames are final as they come,
  /// so a word's own check is its full check.
  bool get _streaming =>
      _inference != null &&
      switch (_model) {
        LocalQuranAcousticModel(:final stream) => stream != null,
        _ => false,
      };

  /// Whether a verdict from [pass] may replace [existing]: never one from a
  /// later pass (the word recited again), and a [provisional] one never
  /// the same pass's ayah check.
  static bool _mayReplace(
    AcousticWordResult? existing,
    int pass, {
    bool provisional = false,
  }) {
    if (existing == null || existing.pass < pass) return true;
    if (existing.pass > pass) return false;
    return !provisional || existing.provisional;
  }

  /// The sound units of the words the tracker placed [job] as, or `null`
  /// when it has none among [span] (a piece sent without placements).
  (int, int)? _placedUnits(PhoneticSpan span, _Job job) {
    int? lo, hi;
    for (final t in span.tokens) {
      if (!job.targets.contains(t.word)) continue;
      lo = lo == null ? t.unit : math.min(lo, t.unit);
      hi = hi == null ? t.unit : math.max(hi, t.unit);
    }
    if (lo == null || hi == null) return null;
    // Said on from the word before (no stop): it is expected too, so a join
    // is judged as one (an ayah's first word joined: no hamzat al-wasl).
    if (job.openStart) {
      final before = [
        for (final t in span.tokens)
          if (t.unit < lo) t.unit,
      ];
      if (before.isNotEmpty) lo = before.reduce(math.max);
    }
    _log('piece placed as ${job.targets.map(_ref).join(' ')} (not located)');
    return (lo, hi);
  }

  /// A word heard said as another: one mistake naming both (their
  /// Uthmani text), in place of its sounds' own verdicts.
  RecitationError? _swapError(WordSwap? swap, Duration frameDuration) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    if (swap == null || corpus == null) return null;
    String text(WordRef r) => switch (corpus.positionOf(r)) {
      final int p => corpus.words[p].text,
      null => _ref(r),
    };
    return RecitationError(
      word: swap.word,
      letter: 0,
      type: RecitationErrorType.wrongWord,
      expected: text(swap.word),
      observed: text(swap.said),
      likelihoodRatio: swap.likelihoodRatio,
      start: frameDuration * swap.span.start,
      end: frameDuration * (swap.span.end + 1),
    );
  }

  static RecitationErrorType _worst(List<PhonemeVerdict> vs) {
    const order = [
      RecitationErrorType.wrongWord,
      RecitationErrorType.wrongLetter,
      RecitationErrorType.shaddaError,
      RecitationErrorType.qalqalaMissing,
      RecitationErrorType.ghunnahMissing,
      RecitationErrorType.maddShort,
      RecitationErrorType.wrongVowel,
      RecitationErrorType.sukunError,
      RecitationErrorType.missingVowel,
      RecitationErrorType.uncertain,
    ];
    for (final type in order) {
      if (vs.any((v) => v.type == type)) return type;
    }
    return RecitationErrorType.correct;
  }

  static String _ref(WordRef r) =>
      '${r.ayahId ~/ 1000}:${r.ayahId % 1000}:${r.wordIndex + 1}';

  void _log(String line) {
    if (!kReleaseMode) debugPrint('Acoustic: $line');
  }
}

extension on QuranAcousticVerifier {
  List<RecitationError> errorsOf(List<PhonemeVerdict> vs) =>
      errors(vs, const Duration(milliseconds: 40));
}

final acousticVerificationControllerProvider =
    NotifierProvider.autoDispose<
      AcousticVerificationController,
      AcousticVerificationState
    >(AcousticVerificationController.new);
