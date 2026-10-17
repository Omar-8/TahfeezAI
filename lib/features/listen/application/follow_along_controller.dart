import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/hifz/hifz_judge.dart' show HifzVerdict;
import '../../../quran/domain/models/quran_refs.dart';
import '../../recitation/application/acoustic_settle.dart';
import '../../recitation/application/hifz_controller.dart';
import '../../recitation/application/recitation_position.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/application/recitation_session_controller.dart';
import '../domain/quran_audio_sources.dart';
import 'listen_options.dart';
import 'quran_audio_player.dart';

/// What Follow along repeats: each ayah in turn, or the whole range.
enum FollowAlongUnit { eachAyah, range }

/// Follow along's settings (its menu): the unit, and how many times the
/// reciter recites it and the user then does. (The reciter and the speed
/// are those of all listening: [reciterProvider], [listenSpeedProvider].)
/// Saved: the menu opens as last used.
class FollowAlongOptions {
  const FollowAlongOptions({
    this.unit = FollowAlongUnit.eachAyah,
    this.reciterTimes = 1,
    this.userTimes = 1,
    this.rangeRounds = 1,
    this.strict = false,
  });

  final FollowAlongUnit unit;
  final int reciterTimes, userTimes;

  /// The whole range: how many times through it (the reciter's turn and
  /// the user's each time); [untilStopped] goes round until stopped.
  final int rangeRounds;
  static const untilStopped = 0;

  /// After the user's turn, a mistake in it (a word wrong or skipped, or a
  /// pronunciation mistake) means reciting it once more, until without.
  final bool strict;

  static const maxTimes = 10;

  FollowAlongOptions copyWith({
    FollowAlongUnit? unit,
    int? reciterTimes,
    int? userTimes,
    int? rangeRounds,
    bool? strict,
  }) => FollowAlongOptions(
    unit: unit ?? this.unit,
    reciterTimes: reciterTimes ?? this.reciterTimes,
    userTimes: userTimes ?? this.userTimes,
    rangeRounds: rangeRounds ?? this.rangeRounds,
    strict: strict ?? this.strict,
  );
}

class FollowAlongOptionsController
    extends SavedJsonController<FollowAlongOptions> {
  @override
  String get storageKey => 'follow.options';

  @override
  Object toJson(FollowAlongOptions value) => {
    'unit': value.unit.name,
    'reciterTimes': value.reciterTimes,
    'userTimes': value.userTimes,
    'rangeRounds': value.rangeRounds,
    'strict': value.strict,
  };

  @override
  FollowAlongOptions fromJson(Object? json) {
    if (json is! Map) return const FollowAlongOptions();
    int times(String key) => json[key] is int
        ? (json[key] as int).clamp(1, FollowAlongOptions.maxTimes)
        : 1;
    return FollowAlongOptions(
      unit:
          FollowAlongUnit.values.asNameMap()[json['unit']] ??
          FollowAlongUnit.eachAyah,
      reciterTimes: times('reciterTimes'),
      userTimes: times('userTimes'),
      rangeRounds: json['rangeRounds'] is int
          ? (json['rangeRounds'] as int).clamp(0, FollowAlongOptions.maxTimes)
          : 1,
      strict: json['strict'] == true,
    );
  }

  @override
  FollowAlongOptions build() {
    restore();
    return const FollowAlongOptions();
  }

  void set(FollowAlongOptions options) => save(options);
}

final followAlongOptionsProvider =
    NotifierProvider<FollowAlongOptionsController, FollowAlongOptions>(
      FollowAlongOptionsController.new,
    );

/// Whose turn it is — or, strict, a turn with mistakes to look over
/// before trying again or skipping on.
enum FollowAlongPhase { reciter, user, review }

/// A Follow along run: its parts (each a run of ayah ids), the part now
/// repeated, and whose turn it is.
class FollowAlongState {
  const FollowAlongState({
    required this.parts,
    required this.index,
    required this.phase,
    required this.options,
    this.round = 1,
    this.again = false,
  });

  final List<List<int>> parts;
  final int index;
  final FollowAlongPhase phase;
  final FollowAlongOptions options;

  /// The whole range: which time through it this is (from 1).
  final int round;

  /// Strict: the user's turn again, after a mistake.
  final bool again;

  List<int> get part => parts[index];

  FollowAlongState copyWith({
    int? index,
    FollowAlongPhase? phase,
    int? round,
    bool again = false,
  }) => FollowAlongState(
    parts: parts,
    index: index ?? this.index,
    phase: phase ?? this.phase,
    options: options,
    round: round ?? this.round,
    again: again,
  );
}

/// Follow along: the reciter recites a part (an ayah, or the whole range)
/// the chosen number of times, then the user recites it — a loop test
/// ([HifzController.setLoop]) of the same part, as many times — then on to
/// the next part. Stopping either turn (the bar's stop), leaving the
/// Mushaf or the audio failing ends the run.
class FollowAlongController extends Notifier<FollowAlongState?> {
  StreamSubscription<NowPlaying>? _finished;

  /// This controller is the one stopping a session (the user's turn
  /// done), so its end goes on rather than ending the run.
  var _advancing = false;

  @override
  FollowAlongState? build() {
    final player = ref.read(quranAudioPlayerProvider.notifier);
    _finished?.cancel();
    _finished = player.finished.listen(_onReciterDone);
    ref.onDispose(() => _finished?.cancel());
    // The reciter stopped from the bar (or the audio failing).
    ref.listen(quranAudioPlayerProvider, (previous, next) {
      final s = state;
      if (s != null && s.phase == FollowAlongPhase.reciter && next == null) {
        _end();
      }
    });
    ref.listen(recitationSessionControllerProvider, (previous, next) {
      final s = state;
      if (s == null || s.phase == FollowAlongPhase.reciter || _advancing) {
        return;
      }
      // The user stopped their turn, or the microphone was refused.
      if ((previous?.isActive ?? false) && !next.isActive) _end();
      if (next.phase == RecitationPhase.permissionDenied ||
          next.phase == RecitationPhase.error) {
        _end();
      }
    });
    // The user's turn recited, every repetition. (A loop's earlier
    // passes complete too, for a moment, before the next begins.)
    ref.listen(
      hifzControllerProvider.select(
        (h) => h.completed && (h.loop == null || h.repetition >= h.loop!.count),
      ),
      (_, done) {
        final s = state;
        if (done && s != null && s.phase == FollowAlongPhase.user) {
          // The test's verdicts now, before the session ends clears them.
          final counts = ref.read(hifzControllerProvider).counts;
          final wordMistakes =
              (counts[HifzVerdict.wrong] ?? 0) +
              (counts[HifzVerdict.skipped] ?? 0);
          unawaited(_onUserDone(s, wordMistakes: wordMistakes));
        }
      },
    );
    ref.listen(mushafRecitationTargetProvider, (previous, next) {
      if (next == null) _end();
    });
    return null;
  }

  /// Starts over [from]..[to] with [options]. `false` when the audio
  /// couldn't be reached (offline).
  Future<bool> start(
    VerseRef from,
    VerseRef to,
    FollowAlongOptions options,
  ) async {
    ref.read(followAlongOptionsProvider.notifier).set(options);
    final ayahs = ayahRange(
      from.chapterNo * 1000 + from.verseNo,
      to.chapterNo * 1000 + to.verseNo,
    );
    state = FollowAlongState(
      parts: options.unit == FollowAlongUnit.range
          ? [ayahs]
          : [
              for (final a in ayahs) [a],
            ],
      index: 0,
      phase: FollowAlongPhase.reciter,
      options: options,
    );
    return _reciterTurn();
  }

  Future<bool> _reciterTurn() async {
    final s = state;
    if (s == null) return false;
    final played = await ref.read(quranAudioPlayerProvider.notifier).playAyahs([
      for (var r = 0; r < s.options.reciterTimes; r++) ...s.part,
    ], options: const ListenOptions());
    if (!played) _end();
    return played;
  }

  void _onReciterDone(NowPlaying done) {
    final s = state;
    if (s == null || s.phase != FollowAlongPhase.reciter) return;
    // Before the player clears: its end is not a stop.
    state = s.copyWith(phase: FollowAlongPhase.user);
    unawaited(_userTurn());
  }

  Future<void> _userTurn({int? times}) async {
    final s = state;
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (s == null || location == null) {
      _end();
      return;
    }
    // Felt as well as seen: the user's turn.
    ref.read(hifzHapticsProvider)();
    VerseRef verse(int id) => (chapterNo: id ~/ 1000, verseNo: id % 1000);
    ref
        .read(hifzControllerProvider.notifier)
        .setLoop(
          (from: verse(s.part.first), to: verse(s.part.last)),
          HifzLoop(
            mode: HifzLoopMode.range,
            count: times ?? s.options.userTimes,
          ),
          // The ayahs before the one recited stay readable.
          showBefore: true,
        );
    await ref
        .read(recitationSessionControllerProvider.notifier)
        .start(startLocation: location);
  }

  Future<void> _onUserDone(
    FollowAlongState done, {
    required int wordMistakes,
  }) async {
    // The pronunciation check of the last words: the microphone paused at
    // once, so the audio heard is checked now (no waiting to hear the
    // reciter stop), then on as soon as the last ayah's check is in.
    final pass = ref.read(recitationPassProvider);
    final pronunciation = await settleAcousticCheck(
      ref,
      lastAyah: done.part.last,
      pass: pass,
    );
    if (!identical(state, done)) return;
    final mistake =
        wordMistakes > 0 ||
        hasPronunciationMistake(
          pronunciation,
          ayahIds: done.part.toSet(),
          pass: pass,
        );
    if (done.options.strict && mistake) {
      // The session kept (paused), its marks in view: the user looks them
      // over, then tries again or skips on.
      state = done.copyWith(phase: FollowAlongPhase.review);
      return;
    }
    await _stopTurn();
    final s = state;
    if (s != null) await _nextPart(s);
  }

  /// Strict, after a turn with mistakes: once more.
  Future<void> tryAgain() async {
    final s = state;
    if (s == null || s.phase != FollowAlongPhase.review) return;
    state = s.copyWith(phase: FollowAlongPhase.user, again: true);
    await _stopTurn();
    if (state != null) await _userTurn(times: 1);
  }

  /// Strict, after a turn with mistakes: on to the next part anyway.
  Future<void> skip() async {
    final s = state;
    if (s == null || s.phase != FollowAlongPhase.review) return;
    await _stopTurn();
    if (identical(state, s)) await _nextPart(s);
  }

  /// Ends the user's turn's session without ending the run.
  Future<void> _stopTurn() async {
    _advancing = true;
    try {
      await ref.read(recitationSessionControllerProvider.notifier).stop();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _nextPart(FollowAlongState s) async {
    if (s.index + 1 >= s.parts.length) {
      // The whole range: round again, from its reciter's turn.
      final rounds = s.options.rangeRounds;
      if (s.options.unit == FollowAlongUnit.range &&
          (rounds == FollowAlongOptions.untilStopped || s.round < rounds)) {
        state = s.copyWith(
          index: 0,
          phase: FollowAlongPhase.reciter,
          round: s.round + 1,
        );
        await _reciterTurn();
      } else {
        _end();
      }
      return;
    }
    state = s.copyWith(index: s.index + 1, phase: FollowAlongPhase.reciter);
    await _reciterTurn();
  }

  void _end() => state = null;

  /// Ends the run, stopping whichever turn is on.
  Future<void> stop() async {
    final s = state;
    _end();
    if (s?.phase == FollowAlongPhase.reciter) {
      await ref.read(quranAudioPlayerProvider.notifier).stop();
    } else if (s != null) {
      await ref.read(recitationSessionControllerProvider.notifier).stop();
    }
  }
}

/// Lives with the Mushaf's bar (which shows its banner), like the Hifz
/// controller it drives.
final followAlongControllerProvider =
    NotifierProvider.autoDispose<FollowAlongController, FollowAlongState?>(
      FollowAlongController.new,
    );
