import 'dart:math' as math;

import '../../quran/domain/models/quran_refs.dart';
import 'ctc.dart';
import 'quran_acoustic_model.dart';
import 'quran_phonetic_reference.dart';

/// What the acoustic evidence says about one expected sound.
enum RecitationErrorType {
  correct,
  wrongLetter,
  wrongVowel,
  missingVowel,
  sukunError,
  shaddaError,

  /// A qalqala letter (ق ط ب ج د with sukun or at a stop) said without its
  /// echo (tajweed).
  qalqalaMissing,

  /// A madd of four or six harakat held clearly shorter (tajweed).
  maddShort,

  /// Another word of the passage said in this word's place (a word
  /// swapped, out of order, or said instead): its sounds fit the audio
  /// clearly better ([QuranAcousticVerifier.wordSwaps]).
  wrongWord,

  /// The evidence is too weak either way.
  uncertain,

  /// A unit-final vowel dropped at a pause (waqf): not a mistake.
  pause,

  /// An optional tajweed marker not heard: not judged.
  skipped;

  bool get isError =>
      this == wrongLetter ||
      this == wrongVowel ||
      this == missingVowel ||
      this == sukunError ||
      this == shaddaError ||
      this == qalqalaMissing ||
      this == maddShort ||
      this == wrongWord;
}

/// Sounds whose evidence is naturally weak, or easily confused with a
/// neighbouring sound, in learners' correct recitation — each may have its
/// own extra margins ([AcousticThresholds.sounds]).
enum SoundGroup {
  /// A doubled letter heard single, or a single one doubled.
  shadda,

  /// A short vowel inside a sound unit heard as reduced to nothing.
  reducedVowel,

  /// A sound unit's last vowel heard as reduced to nothing (said lightly,
  /// or before a short stop).
  finalVowel,

  /// A heavy letter and its light counterpart (ط ت, ص س, ض د, ظ ذ, ق ك)
  /// or ض and ظ.
  heavyLight,

  /// A qalqala letter (ق ط ب ج د) with sukun or at a stop, heard as
  /// another letter: its echo blurs it.
  qalqala,

  /// ن and م heard as each other.
  nasal,

  /// A hidden nūn or mīm (ikhfāʾ, iqlāb: «ں», «۾») heard as a plain, clear
  /// «ن» / «م» — a nasalisation a streaming model judges with less context.
  hiddenNasal,

  /// The throat letters (ء ع ح ه خ غ) heard as each other.
  throat,

  /// A word's last vowel said as another short vowel, in flow: a case
  /// ending, said in a frame or two — its evidence is weaker than a vowel's
  /// inside a word.
  wordFinalVowel,

  /// A word's last vowel after a qalqala letter heard as a stop on the
  /// letter (its echo) though the next word follows at once.
  stopInFlow;

  /// Which group an alternative pronunciation of [ts]`[k]` belongs to, if
  /// any: [type] the mistake it would be, [heard] its token (a letter).
  static SoundGroup? of(
    List<PhoneticToken> ts,
    int k,
    RecitationErrorType type,
    int? heard,
  ) {
    final t = ts[k];
    switch (type) {
      case RecitationErrorType.shaddaError:
        return shadda;
      case RecitationErrorType.missingVowel
          when heard != null && heard == phoneticClassOf('ڇ'):
        return stopInFlow;
      case RecitationErrorType.missingVowel:
        return t.unitFinalVowel ? finalVowel : reducedVowel;
      case RecitationErrorType.wrongVowel:
        for (var j = k + 1; j < ts.length; j++) {
          if (ts[j].word != t.word) return wordFinalVowel;
          if (ts[j].kind != PhoneticTokenKind.marker) return null;
        }
        return wordFinalVowel;
      case RecitationErrorType.wrongLetter when heard != null:
        final a = t.symbol, b = quranPhoneticVocabulary[heard];
        if ('ں۾'.contains(a) && 'نم'.contains(b)) return hiddenNasal;
        if (_pairs.contains('$a$b') || _pairs.contains('$b$a')) {
          return heavyLight;
        }
        if ('نم'.contains(a) && 'نم'.contains(b)) return nasal;
        if (_throat.contains(a) && _throat.contains(b)) return throat;
        final next = k + 1 < ts.length ? ts[k + 1] : null;
        final sakin =
            next == null ||
            next.unit != t.unit ||
            next.kind == PhoneticTokenKind.consonant ||
            next.kind == PhoneticTokenKind.marker;
        if (sakin && !t.geminate && _qalqala.contains(a)) return qalqala;
        return null;
      default:
        return null;
    }
  }

  static const _pairs = {'طت', 'صس', 'ضد', 'ظذ', 'قك', 'ضظ'};
  static const _throat = 'ءعحهخغ';
  static const _qalqala = 'قطبجد';
}

/// Extra margins for a [SoundGroup], added to the type's own: a mistake
/// needs [error] more, an uncertain mark [uncertain] more.
class SoundMargins {
  const SoundMargins({this.error = 0, this.uncertain = 0});
  final double error, uncertain;
}

/// Configurable decision thresholds, in nats of log-likelihood.
class AcousticThresholds {
  const AcousticThresholds({
    this.error = 2.0,
    this.letterError = 2.5,
    this.missingVowelError = 1.0,
    this.sukunError = 1.0,
    this.shaddaError,
    this.correct = 1.0,
    this.pauseFrames = 6,
    this.context = 2,
    this.sounds = const {},
    this.tajweed = true,
    this.qalqalaError = 3,
    this.maddShare = QuranAcousticVerifier.maddShortShare,
  });

  /// With [tajweed]: a madd of 4 or 6 counts is short when held for less
  /// than this share of its length, in the reciter's beats. (A ghunnah's
  /// length cannot be read this way: the model does not hold the noon's
  /// probability through it - on QDAT nearly every ghunnah held looked short.)
  final double maddShare;

  /// With [tajweed]: a qalqala letter's echo missing needs "said without
  /// it" to beat "said with it" by this much. (On QDAT's expert labels for
  /// the stop on «ٱلْغُيُوبِ», the margin was above 2 for 95% of readers who
  /// left the echo out and 5% of those who did it.)
  final double qalqalaError;

  /// Judge tajweed: a merged or hidden nūn / mīm (idghām, ikhfāʾ, iqlāb)
  /// said plainly is a mistake. Off: only the letters and vowels count.
  final bool tajweed;

  /// Per [SoundGroup], its extra margins.
  final Map<SoundGroup, SoundMargins> sounds;

  /// An alternative pronunciation must beat the expected one by this much
  /// to report a mistake — a wrong vowel, and any type without its own.
  final double error;

  /// …a wrong letter.
  final double letterError;

  /// …a missing vowel, a vowel on a sakin letter, a shadda mistake (the
  /// evidence for each is naturally weaker or stronger; `null` = [error]).
  ///
  /// Defaults tuned on real audio (tool/acoustic_verification/evaluate.dart):
  /// a vowel added or dropped leaves weaker evidence than a swapped one,
  /// so their thresholds are lower — detection of those doubled or tripled
  /// with no extra false alarms on correct recitation — and a wrong letter's
  /// slightly higher.
  final double? missingVowelError, sukunError, shaddaError;

  double errorFor(RecitationErrorType type) => switch (type) {
    RecitationErrorType.wrongLetter => letterError,
    RecitationErrorType.missingVowel => missingVowelError ?? error,
    RecitationErrorType.sukunError => sukunError ?? error,
    RecitationErrorType.shaddaError => shaddaError ?? error,
    _ => error,
  };

  AcousticThresholds copyWith({
    double? error,
    double? letterError,
    double? missingVowelError,
    double? sukunError,
    double? shaddaError,
    double? correct,
    int? pauseFrames,
    Map<SoundGroup, SoundMargins>? sounds,
    bool? tajweed,
    double? qalqalaError,
    double? maddShare,
  }) => AcousticThresholds(
    error: error ?? this.error,
    letterError: letterError ?? this.letterError,
    missingVowelError: missingVowelError ?? this.missingVowelError,
    sukunError: sukunError ?? this.sukunError,
    shaddaError: shaddaError ?? this.shaddaError,
    correct: correct ?? this.correct,
    pauseFrames: pauseFrames ?? this.pauseFrames,
    context: context,
    sounds: sounds ?? this.sounds,
    tajweed: tajweed ?? this.tajweed,
    qalqalaError: qalqalaError ?? this.qalqalaError,
    maddShare: maddShare ?? this.maddShare,
  );

  /// The expected pronunciation must beat every alternative by this much
  /// to count as correct; anything in between is uncertain.
  final double correct;

  /// Blank frames after a sound unit that make a pause (6 × 40 ms).
  final int pauseFrames;

  /// Neighbouring aligned tokens either side in the local rescoring.
  final int context;
}

/// The verdict on one expected token.
class PhonemeVerdict {
  const PhonemeVerdict({
    required this.token,
    required this.type,
    this.span,
    this.confidence = 0,
    this.competitor,
    this.likelihoodRatio = 0,
    this.observed,
  });

  final PhoneticToken token;
  final RecitationErrorType type;
  final FrameSpan? span;

  /// Mean posterior of the expected token over its frames.
  final double confidence;

  /// The most probable other token over those frames.
  final String? competitor;

  /// Best alternative minus expected (log-likelihood); > 0 favours a
  /// mistake.
  final double likelihoodRatio;

  /// What was heard instead: a vowel name, `SUKUN`, a letter,
  /// `NO_SHADDA` / `EXTRA_SHADDA`.
  final String? observed;
}

/// A mistake (or uncertainty) located in the Quran text.
class RecitationError {
  const RecitationError({
    required this.word,
    required this.letter,
    required this.type,
    required this.expected,
    this.observed,
    required this.likelihoodRatio,
    this.start,
    this.end,
  });

  final WordRef word;

  /// Base-letter index within the word.
  final int letter;
  final RecitationErrorType type;

  /// The expected phonetic symbol and its Uthmani source character.
  final String expected;
  final String? observed;
  final double likelihoodRatio;

  /// Where in the audio.
  final Duration? start, end;

  @override
  String toString() =>
      '${type.name} ${word.ayahId ~/ 1000}:${word.ayahId % 1000}:'
      '${word.wordIndex + 1} letter ${letter + 1} expected $expected'
      '${observed == null ? '' : ' heard $observed'}'
      ' (llr ${likelihoodRatio.toStringAsFixed(2)})';
}

/// Verifies recitation audio against the expected Quran pronunciation.
///
/// 1. Forced alignment: the acoustic frames are aligned to the *expected*
///    token sequence ([ctcForcedAlign]); unit-final vowels may be dropped
///    only where a pause follows (waqf), tajweed markers are optional.
/// 2. Rescoring: for each expected sound, the frames around it are scored
///    (full CTC probability) with the expected tokens and with each
///    alternative — the other short vowels, no vowel, another letter, a
///    vowel after a sakin letter, a missing or extra shadda. The margin of
///    the best alternative over the expected pronunciation decides:
///    mistake, correct, or — in between — uncertain.
///
/// Confidence comes only from the model's probabilities; weak evidence is
/// never reported as a mistake.
class QuranAcousticVerifier {
  const QuranAcousticVerifier({this.thresholds = const AcousticThresholds()});

  final AcousticThresholds thresholds;

  /// Verifies [expected] (whole sound units) against [frames]. With the
  /// units' [pauses] forms, it first finds where the reciter paused and,
  /// where the audio supports it better, expects the unit as said at that
  /// pause (waqf after, ibtida before). [openStart] / [openEnd]: the audio
  /// was cut mid-recitation on that side, so no pause is assumed there.
  List<PhonemeVerdict> verify(
    AcousticFrames frames,
    List<PhoneticToken> expected, {
    Map<int, PauseForms> pauses = const {},
    bool openStart = false,
    bool openEnd = false,
    BeatMeter? beat,
  }) {
    if (expected.isEmpty) return const [];
    final t = frames.frames;
    var spans = _alignWithWaqf(frames, expected);
    final first = <int, int>{}, last = <int, int>{};
    final byUnit = <int, List<PhoneticToken>>{};
    for (var k = 0; k < expected.length; k++) {
      final tok = expected[k];
      (byUnit[tok.unit] ??= []).add(tok);
      final span = spans[k];
      if (span == null) continue;
      first.putIfAbsent(tok.unit, () => span.start);
      last[tok.unit] = span.end;
    }
    final aligned = first.keys.toList()..sort();
    final pauseAfter = <int>{};
    // …and the units followed by a real stop (a waqf, not a breath), or
    // ending the recitation: a separated madd there needs no length.
    final stopAfter = <int>{};
    for (var i = 0; i + 1 < aligned.length; i++) {
      final a = aligned[i], b = aligned[i + 1];
      final gap = first[b]! - last[a]! - 1;
      if (gap >= thresholds.pauseFrames) pauseAfter.add(a);
      if (gap >= stopFrames) stopAfter.add(a);
    }
    if (aligned.isNotEmpty && !openEnd) {
      pauseAfter.add(aligned.last);
      stopAfter.add(aligned.last);
    }
    final starts = <int>{
      for (var i = 0; i + 1 < aligned.length; i++)
        if (pauseAfter.contains(aligned[i])) aligned[i + 1],
      if (aligned.isNotEmpty && !openStart) aligned.first,
    };
    final order = byUnit.keys.toList()..sort();
    final chosen = <PhoneticToken>[];
    // Per unit, a vowel dropped at a stop and the last word said before it
    // (null: the unit's end) — checked below for a different vowel said.
    final finalVowel = <int, (PhoneticToken, int?)>{};
    for (var n = 0; n < order.length; n++) {
      final u = order[n];
      final unit = byUnit[u]!;
      final forms = pauses[u];
      final stop = pauseAfter.contains(u), start = starts.contains(u);
      // The unit as said here: at a pause (waqf / ibtida) or, at an ayah
      // boundary without one, joined to the next / previous ayah.
      // Its ends may each be said at a pause or in flow: every combination
      // of the two edits is a candidate, and the audio decides.
      // The stop/restart forms only where a pause was heard; the joined
      // forms of an ayah's ends are said in flow, pause or not.
      final ends = [(stop, true), if (stop) (false, true), (false, false)];
      final begins = [(start, true), if (start) (false, true), (false, false)];
      final options = <List<PhoneticToken>>[
        if (forms != null)
          for (final (s, e) in ends)
            for (final (st, b) in begins)
              if (e || b)
                forms.apply(unit, stop: s, start: st, end: e, begin: b),
      ].where((o) => !_sameTokens(o, unit)).toList();
      // The ayah's end said on into the next ayah (wasl): judged with the
      // next ayah's start joined to it too (no hamzat al-wasl) — a join is
      // a pair, «ٱلْبَيْتِ ٱلَّذِىٓ» said «-bayti-lladhī».
      final joinedEnds = <List<PhoneticToken>>{
        if (forms?.wasl != null)
          for (final (st, b) in begins)
            forms!.apply(unit, stop: false, start: st, end: true, begin: b),
      };
      // Stopping inside a unit of several words (after a word whose
      // ending joins the next in flow): only where a pause was heard
      // inside it, so in flow the joined form is the one judged.
      if (forms != null &&
          forms.splits.isNotEmpty &&
          first.containsKey(u) &&
          _pauseWithin(frames, first[u]!, last[u]!)) {
        options.addAll(forms.splits.values);
      }
      List<PhoneticToken>? candidate;
      if (options.isNotEmpty && !first.containsKey(u)) {
        candidate = options.first;
      } else if (options.isNotEmpty) {
        final prev = n > 0 ? order[n - 1] : null;
        final next = n + 1 < order.length ? order[n + 1] : null;
        final f0 = math.max(0, (first[prev] ?? first[u]!) - 2);
        final f1 = math.min(t - 1, (last[next] ?? last[u]!) + 2);
        // The previous unit as already chosen (its form may have changed).
        final before = [
          for (final x in chosen)
            if (x.unit == prev) x.token,
        ];
        final after = [
          for (final x in byUnit[next] ?? const <PhoneticToken>[]) x.token,
        ];
        final nextForms = next == null ? null : pauses[next];
        final afterJoined = nextForms?.joined == null
            ? after
            : [
                for (final x in nextForms!.apply(
                  byUnit[next]!,
                  stop: false,
                  start: false,
                  end: false,
                ))
                  x.token,
              ];
        final local = frames.slice(f0, f1);
        double score(List<PhoneticToken> tokens) => ctcLogProbability(local, [
          ...before,
          for (final x in tokens) x.token,
          ...(joinedEnds.any((j) => _sameTokens(j, tokens))
              ? afterJoined
              : after),
        ]);
        var best = score(unit);
        for (final o in options) {
          final s = score(o);
          if (s > best) {
            best = s;
            candidate = o;
          }
        }
      }
      if (candidate == null) {
        chosen.addAll(unit);
        continue;
      }
      // Stopped inside the unit, after word k: that word's last vowel (in
      // flow) was dropped at the stop.
      final splitAfter = forms?.splits.entries
          .where((e) => identical(e.value, candidate))
          .firstOrNull
          ?.key;
      if (splitAfter != null) {
        final ofWord = [
          for (final x in unit)
            if (x.word.wordIndex == splitAfter) x,
        ];
        if (ofWord.isNotEmpty &&
            ofWord.last.kind == PhoneticTokenKind.vowel &&
            ShortVowel.ofToken(ofWord.last.token) != null) {
          finalVowel[u] = (ofWord.last, splitAfter);
        }
      } else if (stop) {
        for (final x in unit) {
          if (x.unitFinalVowel) finalVowel[u] = (x, null);
        }
      }
      chosen.addAll(candidate);
    }
    spans = _alignWithWaqf(frames, chosen);
    final out = _verifyAligned(
      frames,
      chosen,
      spans,
      beat,
      stoppedUnits: stopAfter,
    );
    // A different vowel said just before a pause is still a mistake.
    for (final MapEntry(key: u, value: (vowel, lastWord))
        in finalVowel.entries) {
      final ks = [
        for (var k = 0; k < chosen.length; k++)
          if (chosen[k].unit == u &&
              spans[k] != null &&
              (lastWord == null || chosen[k].word.wordIndex <= lastWord))
            k,
      ];
      if (ks.isEmpty) continue;
      final k = ks.last;
      final lo = math.max(0, k - thresholds.context);
      final f0 = (spans[lo] ?? spans[k])!.start;
      var nextStart = t;
      for (var i = k + 1; i < chosen.length; i++) {
        if (spans[i] != null) {
          nextStart = spans[i]!.start;
          break;
        }
      }
      final f1 = math.min(t - 1, math.min(nextStart - 1, spans[k]!.end + 12));
      final before = [
        for (var i = lo; i <= k; i++)
          if (spans[i] != null) chosen[i].token,
      ];
      final local = frames.slice(f0, f1);
      // The vowel kept on the flow form's ending too: «ٱلْقَارِعَةَ» said
      // with its ت (not the stop's ه) and a fatha.
      final stem = [
        for (final x in byUnit[u]!.takeWhile((x) => !identical(x, vowel)))
          x.token,
      ];
      final inUnit = [
        for (var i = lo; i <= k; i++)
          if (spans[i] != null && chosen[i].unit == u) i,
      ].length;
      final flow = [
        for (var i = lo; i <= k; i++)
          if (spans[i] != null && chosen[i].unit != u) chosen[i].token,
        ...stem.sublist(math.max(0, stem.length - inUnit)),
      ];
      double said(int v) => math.max(
        ctcLogProbability(local, [...before, v]),
        ctcLogProbability(local, [...flow, v]),
      );
      final ok = math.max(ctcLogProbability(local, before), said(vowel.token));
      var best = double.negativeInfinity;
      String? observed;
      for (final v in ShortVowel.values) {
        if (v.token == vowel.token) continue;
        final score = said(v.token);
        if (score > best) {
          best = score;
          observed = v.name.toUpperCase();
        }
      }
      final llr = best - ok;
      if (llr > -thresholds.correct) {
        out.add(
          PhonemeVerdict(
            token: vowel,
            type: llr >= thresholds.error
                ? RecitationErrorType.wrongVowel
                : RecitationErrorType.uncertain,
            likelihoodRatio: llr,
            observed: observed,
          ),
        );
      }
    }
    return out;
  }

  /// Which sound units of [candidates] the frames hold — the utterance
  /// aligned with a free start and end at unit boundaries. `null` when it
  /// matches none of them well: the best path through the expected tokens
  /// may cost at most [maxCostPerFrame] (nats per frame) more than the
  /// best unconstrained path. [openStart] / [openEnd]: the audio was cut
  /// mid-recitation on that side, so it may begin / end inside a unit (a
  /// neighbouring word cut in two).
  (int, int)? locate(
    AcousticFrames frames,
    List<PhoneticToken> candidates, {
    double maxCostPerFrame = 0.6,
    bool openStart = false,
    bool openEnd = false,
  }) {
    if (candidates.isEmpty || frames.frames == 0) return null;
    final startAt = <int>{}, endAt = <int>{};
    for (var k = 0; k < candidates.length; k++) {
      if (openStart || k == 0 || candidates[k - 1].unit != candidates[k].unit) {
        startAt.add(k);
      }
      if (openEnd ||
          k + 1 == candidates.length ||
          candidates[k + 1].unit != candidates[k].unit) {
        endAt.add(k);
      }
    }
    final a = ctcForcedAlign(
      frames,
      [for (final t in candidates) t.token],
      optional: [for (final t in candidates) t.optional || t.unitFinalVowel],
      startAt: startAt,
      endAt: endAt,
    );
    var free = 0.0;
    for (var f = 0; f < frames.frames; f++) {
      var best = double.negativeInfinity;
      for (var c = 0; c < frames.classes; c++) {
        best = math.max(best, frames.at(f, c));
      }
      free += best;
    }
    if ((free - a.score) / frames.frames > maxCostPerFrame) return null;
    int? lo, hi;
    for (var k = 0; k < candidates.length; k++) {
      if (a.spans[k] == null) continue;
      lo ??= candidates[k].unit;
      hi = candidates[k].unit;
    }
    return lo == null ? null : (lo, hi!);
  }

  /// A stop inside a sound unit: at least this many silent frames (320 ms;
  /// a reciter's stop is longer than the 160 ms that separates units, and
  /// shorter gaps inside a joined unit are too often just the audio).
  static const stopInsideFrames = 8;

  /// Whether frames [from]..[to] hold a stop: a run of at least
  /// [stopInsideFrames] (and [AcousticThresholds.pauseFrames]) frames where
  /// nothing but the blank is likely.
  bool _pauseWithin(AcousticFrames frames, int from, int to) =>
      pauseBetween(frames, from, to);

  /// Whether the reciter stopped between frames [from] and [to] (as
  /// [_pauseWithin]): e.g. between two ayahs, said joined or not.
  bool pauseBetween(AcousticFrames frames, int from, int to) {
    var run = 0;
    for (var f = from + 1; f < to; f++) {
      var blank = true;
      for (var c = 1; c < frames.classes && blank; c++) {
        if (frames.at(f, c) > frames.at(f, ctcBlank)) blank = false;
      }
      run = blank ? run + 1 : 0;
      if (run >= math.max(thresholds.pauseFrames, stopInsideFrames)) {
        return true;
      }
    }
    return false;
  }

  static bool _sameTokens(List<PhoneticToken> a, List<PhoneticToken> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].token != b[i].token || a[i].geminate != b[i].geminate) {
        return false;
      }
    }
    return true;
  }

  /// [stoppedUnits]: the sound units a pause was heard after.
  List<PhonemeVerdict> _verifyAligned(
    AcousticFrames frames,
    List<PhoneticToken> expected,
    List<FrameSpan?> spans,
    BeatMeter? meter, {
    Set<int> stoppedUnits = const {},
  }) {
    final labels = [for (final t in expected) t.token];
    final out = <PhonemeVerdict>[];
    // The reciter's beat: this audio's own, else the session's so far (a
    // word's own check rarely holds the two madds a beat needs).
    final own = thresholds.tajweed ? _beat(frames, expected, spans) : null;
    if (own != null) meter?.add(own);
    final beat = thresholds.tajweed ? own ?? meter?.value : null;
    for (var k = 0; k < expected.length; k++) {
      final t = expected[k];
      final span = spans[k];
      // A long madd held clearly short, against the reciter's own beat —
      // not one ending a unit the reciter stopped after: a separated madd
      // (munfaṣil, or a ṣila before a hamza: «فِيهَآ ۚ أُو۟لَـٰٓئِكَ»,
      // «بِهِۦٓ أَحَدًا») is long only joined to the next word; at a stop
      // it is a natural madd of two.
      if (beat != null &&
          span != null &&
          t.kind == PhoneticTokenKind.long &&
          t.count >= 4 &&
          _plainOfHidden(t) == null &&
          !(stoppedUnits.contains(t.unit) && _unitFinal(expected, k))) {
        final beats = _held(frames, expected, spans, k) / beat;
        if (beats < thresholds.maddShare * t.count) {
          out.add(
            PhonemeVerdict(
              token: t,
              type: RecitationErrorType.maddShort,
              span: span,
              likelihoodRatio: beats,
              observed: '${beats.round()}',
            ),
          );
          continue;
        }
      }
      if (thresholds.tajweed && t.optional && t.token == _qalqalaEcho) {
        out.add(_qalqala(frames, expected, spans, labels, k));
        continue;
      }
      if (span == null) {
        out.add(
          t.unitFinalVowel
              ? _atPause(frames, expected, spans, labels, k)
              : PhonemeVerdict(token: t, type: RecitationErrorType.skipped),
        );
        continue;
      }
      var confidence = 0.0;
      final rival = List<double>.filled(frames.classes, 0);
      for (var f = span.start; f <= span.end; f++) {
        confidence += math.exp(frames.at(f, t.token));
        for (var c = 1; c < frames.classes; c++) {
          if (c != t.token) rival[c] += math.exp(frames.at(f, c));
        }
      }
      confidence /= span.end - span.start + 1;
      var best = 1;
      for (var c = 2; c < frames.classes; c++) {
        if (rival[c] > rival[best]) best = c;
      }
      final competitor = quranPhoneticVocabulary[best];
      final alternatives = [
        for (final a in _alternatives(expected, k))
          if (thresholds.tajweed || !a.tajweed) a,
      ];
      if (alternatives.isEmpty) {
        out.add(
          PhonemeVerdict(
            token: t,
            type: RecitationErrorType.correct,
            span: span,
            confidence: confidence,
            competitor: competitor,
          ),
        );
        continue;
      }
      final (lo, hi, f0, f1) = _window(spans, k, frames.frames);
      final window = [
        for (var i = lo; i <= hi; i++)
          if (spans[i] != null) labels[i],
      ];
      var at = 0;
      for (var i = lo; i < k; i++) {
        if (spans[i] != null) at++;
      }
      final local = frames.slice(f0, f1);
      final base = ctcLogProbability(local, window);
      // Each alternative against its own margins (its type's, plus its
      // sound group's): a mistake if any clears its error margin, else
      // uncertain if any clears its uncertain one. Reported: the one that
      // decided, or the likeliest.
      var bestLlr = double.negativeInfinity;
      late _Alternative bestAlt;
      _Alternative? mistake, doubt;
      var mistakeLlr = 0.0, doubtLlr = 0.0;
      for (final alt in alternatives) {
        final seq = [
          ...window.sublist(0, at),
          ...alt.tokens,
          ...window.sublist(at + 1),
        ];
        final llr = ctcLogProbability(local, seq) - base;
        if (llr > bestLlr) {
          bestLlr = llr;
          bestAlt = alt;
        }
        final group = thresholds.sounds.isEmpty
            ? null
            : SoundGroup.of(
                expected,
                k,
                alt.type,
                alt.tokens.length == 1 ? alt.tokens.single : null,
              );
        final extra = thresholds.sounds[group] ?? const SoundMargins();
        if (llr >= thresholds.errorFor(alt.type) + extra.error &&
            (mistake == null || llr > mistakeLlr)) {
          mistake = alt;
          mistakeLlr = llr;
        }
        if (llr > -thresholds.correct + extra.uncertain &&
            (doubt == null || llr > doubtLlr)) {
          doubt = alt;
          doubtLlr = llr;
        }
      }
      final decided = mistake ?? doubt ?? bestAlt;
      final llr = mistake != null
          ? mistakeLlr
          : doubt != null
          ? doubtLlr
          : bestLlr;
      final type = mistake != null
          ? mistake.type
          : doubt != null
          ? RecitationErrorType.uncertain
          : RecitationErrorType.correct;
      out.add(
        PhonemeVerdict(
          token: t,
          type: type,
          span: span,
          confidence: confidence,
          competitor: competitor,
          likelihoodRatio: llr,
          observed: decided.observed,
        ),
      );
    }
    return out;
  }

  static final _qalqalaEcho = phoneticClassOf('ڇ');

  /// A madd of 4 or 6 harakat is short when held for less than this share
  /// of its length, in the reciter's own beats (measured while its sound
  /// keeps returning, [_held]). Rechecked on the streaming v3.5
  /// (2026-10-16): on QDAT's held-out learners («لَنَآ إِنَّكَ», 5:109) the
  /// madd held right flagged 0.8% at 0.6–0.7 (1.0% at 0.75), cut short
  /// caught 30.9 / 35.1 / 35.9%; but 0.7 flagged a correct «وَمَآ» (2:4,
  /// 2.67 beats) in the user's own replayed sessions, so 0.65 stays.
  static const maddShortShare = 0.65;

  /// A gap (frames of 40 ms) long enough to be a stop (waqf) rather than a
  /// breath, for a separated madd's length: 720 ms. On QDAT's held-out
  /// learners («لَنَآ ۖ إِنَّكَ», 5:109) the separate madd done right and still
  /// flagged 2.6 -> 0.8%, missed and flagged 39.0 -> 35.1% (160 ms: 25.1%).
  static const stopFrames = 18;

  /// A long sound still heard: its probability at least this, …
  static const heldFloor = 0.15;

  /// … dropping below it for at most this many frames before it returns.
  static const heldGap = 3;

  /// A long sound's length in frames: its aligned span, extended while the
  /// sound keeps coming back ([heldFloor], gaps up to [heldGap]) up to the
  /// next sound's span. A streaming model fires fewer CTC spikes in a long
  /// madd than a whole-clip model does, but still hears it (QDAT's
  /// separate madd, held by the reciter: flagged 2.9% by span, 0.8% so;
  /// the whole-clip model unchanged at 0.5%).
  static int _held(
    AcousticFrames frames,
    List<PhoneticToken> expected,
    List<FrameSpan?> spans,
    int k,
  ) {
    final span = spans[k]!;
    var next = frames.frames;
    for (var i = k + 1; i < expected.length; i++) {
      if (spans[i] case final s?) {
        next = s.start;
        break;
      }
    }
    final floor = math.log(heldFloor);
    var last = span.end, gap = 0;
    for (var f = span.end + 1; f < next; f++) {
      if (frames.at(f, expected[k].token) >= floor) {
        last = f;
        gap = 0;
      } else if (++gap > heldGap) {
        break;
      }
    }
    return last - span.start + 1;
  }

  /// The reciter's beat (one haraka, in frames): half the median length of
  /// the two-count madds aligned here that a short vowel follows in their
  /// unit (one before a stop is often held longer); `null` with fewer than
  /// two of them.
  static double? _beat(
    AcousticFrames frames,
    List<PhoneticToken> expected,
    List<FrameSpan?> spans,
  ) {
    bool beforeVowel(int k) => expected
        .skip(k + 1)
        .takeWhile((u) => u.unit == expected[k].unit)
        .any((u) => u.kind == PhoneticTokenKind.vowel);
    final halves = <double>[
      for (var k = 0; k < expected.length; k++)
        if (expected[k].kind == PhoneticTokenKind.long &&
            expected[k].count == 2 &&
            _plainOfHidden(expected[k]) == null &&
            spans[k] != null &&
            beforeVowel(k))
          _held(frames, expected, spans, k) / 2,
    ]..sort();
    if (halves.length < 2) return null;
    final mid = halves.length ~/ 2;
    return halves.length.isOdd
        ? halves[mid]
        : (halves[mid - 1] + halves[mid]) / 2;
  }

  /// A qalqala letter's echo: the frames around it said with the echo or
  /// without — a mistake if clearly without.
  PhonemeVerdict _qalqala(
    AcousticFrames frames,
    List<PhoneticToken> expected,
    List<FrameSpan?> spans,
    List<int> labels,
    int k,
  ) {
    final t = expected[k];
    final (lo, hi, f0, f1) = _window(spans, k, frames.frames);
    final before = [
      for (var i = lo; i < k; i++)
        if (spans[i] != null) labels[i],
    ];
    final after = [
      for (var i = k + 1; i <= hi; i++)
        if (spans[i] != null) labels[i],
    ];
    final local = frames.slice(f0, f1);
    final llr =
        ctcLogProbability(local, [...before, ...after]) -
        ctcLogProbability(local, [...before, t.token, ...after]);
    return PhonemeVerdict(
      token: t,
      type: llr >= thresholds.qalqalaError
          ? RecitationErrorType.qalqalaMissing
          : RecitationErrorType.correct,
      span: spans[k],
      likelihoodRatio: llr,
      observed: llr >= thresholds.qalqalaError ? 'NO_QALQALA' : null,
    );
  }

  /// A unit-final vowel not heard before a pause is fine (waqf) — unless a
  /// different short vowel was said there.
  PhonemeVerdict _atPause(
    AcousticFrames frames,
    List<PhoneticToken> expected,
    List<FrameSpan?> spans,
    List<int> labels,
    int k,
  ) {
    final t = expected[k];
    final (lo, hi, f0, f1) = _window(spans, k, frames.frames);
    final before = [
      for (var i = lo; i < k; i++)
        if (spans[i] != null) labels[i],
    ];
    final after = [
      for (var i = k + 1; i <= hi; i++)
        if (spans[i] != null) labels[i],
    ];
    final local = frames.slice(f0, f1);
    final ok = math.max(
      ctcLogProbability(local, [...before, ...after]),
      ctcLogProbability(local, [...before, t.token, ...after]),
    );
    var best = double.negativeInfinity;
    String? observed;
    for (final v in ShortVowel.values) {
      if (v.token == t.token) continue;
      final score = ctcLogProbability(local, [...before, v.token, ...after]);
      if (score > best) {
        best = score;
        observed = v.name.toUpperCase();
      }
    }
    final llr = best - ok;
    return PhonemeVerdict(
      token: t,
      type: llr >= thresholds.error
          ? RecitationErrorType.wrongVowel
          : llr <= -thresholds.correct
          ? RecitationErrorType.pause
          : RecitationErrorType.uncertain,
      likelihoodRatio: llr,
      observed: observed,
    );
  }

  /// The mistakes and uncertain sounds, located in the text.
  /// A word must beat the expected one by this (log-likelihood) to be
  /// heard in its place.
  static const swapMargin = 4.0;

  /// Words said as another word of the passage: for each word already
  /// failing on several sounds (two letters, or three mistakes), the whole
  /// passage ([verdicts]' sounds, in order) is scored with that word's
  /// sounds replaced by each other word's in [candidates]; one fitting the
  /// audio better by [swapMargin] was said instead — reported as one word,
  /// not as a run of unlikely letter swaps. Scored over the whole passage,
  /// not the word's own frames: a word whose alignment slipped onto its
  /// neighbour is not "said as the neighbour", since that neighbour's
  /// sounds are already heard where it is.
  List<WordSwap> wordSwaps(
    AcousticFrames frames,
    List<PhonemeVerdict> verdicts,
    Map<WordRef, List<PhoneticToken>> candidates,
  ) {
    final byWord = <WordRef, List<PhonemeVerdict>>{};
    for (final v in verdicts) {
      (byWord[v.token.word] ??= []).add(v);
    }
    List<int> sounds(Iterable<PhoneticToken> ts) => [
      for (final t in ts)
        if (!t.optional) t.token,
    ];
    bool same(List<int> a, List<int> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    final order = [for (final v in verdicts) v.token];
    double? base;
    final out = <WordSwap>[];
    for (final MapEntry(key: word, value: vs) in byWord.entries) {
      final letters = vs
          .where((v) => v.type == RecitationErrorType.wrongLetter)
          .length;
      final mistakes = vs.where((v) => v.type.isError).length;
      if (letters < 2 && mistakes < 3) continue;
      int? lo, hi;
      for (final v in vs) {
        final span = v.span;
        if (span == null) continue;
        lo = lo == null ? span.start : math.min(lo, span.start);
        hi = hi == null ? span.end : math.max(hi, span.end);
      }
      if (lo == null || hi == null) continue;
      // A word cut by the audio's edge is partly missing, not said as
      // another (the app drops such words: cut within 0.3 s).
      if (lo < 8 || hi >= frames.frames - 8) continue;
      final first = order.indexWhere((t) => t.word == word);
      final last = order.lastIndexWhere((t) => t.word == word);
      final before = sounds(order.sublist(0, first));
      final after = sounds(order.sublist(last + 1));
      final own = sounds(order.sublist(first, last + 1));
      base ??= ctcLogProbability(frames, [...before, ...own, ...after]);
      WordRef? best;
      var bestLlr = double.negativeInfinity;
      for (final MapEntry(key: other, value: ts) in candidates.entries) {
        if (other == word) continue;
        final seq = sounds(ts);
        if (seq.isEmpty || same(seq, own)) continue;
        final llr =
            ctcLogProbability(frames, [...before, ...seq, ...after]) - base;
        if (llr > bestLlr) {
          bestLlr = llr;
          best = other;
        }
      }
      if (best != null && bestLlr >= swapMargin) {
        out.add(
          WordSwap(
            word: word,
            said: best,
            likelihoodRatio: bestLlr,
            span: (start: lo, end: hi),
          ),
        );
      }
    }
    return out;
  }

  List<RecitationError> errors(
    List<PhonemeVerdict> verdicts,
    Duration frameDuration,
  ) => [
    for (final v in verdicts)
      if (v.type.isError || v.type == RecitationErrorType.uncertain)
        RecitationError(
          word: v.token.word,
          letter: v.token.letter,
          type: v.type,
          expected: '${v.token.symbol} (${v.token.sourceChar})',
          observed: v.type.isError ? v.observed : null,
          likelihoodRatio: v.likelihoodRatio,
          start: v.span == null ? null : frameDuration * v.span!.start,
          end: v.span == null ? null : frameDuration * (v.span!.end + 1),
        ),
  ];

  /// Unit-final vowels may be dropped only at a pause: aligned first as
  /// optional; one dropped with no pause after it is aligned again as
  /// required, so it is verified.
  List<FrameSpan?> _alignWithWaqf(
    AcousticFrames frames,
    List<PhoneticToken> expected,
  ) {
    final labels = [for (final t in expected) t.token];
    final optional = [for (final t in expected) t.optional || t.unitFinalVowel];
    var spans = ctcForcedAlign(frames, labels, optional: optional).spans;
    var redo = false;
    for (var k = 0; k + 1 < expected.length; k++) {
      if (!expected[k].unitFinalVowel || spans[k] != null) continue;
      var prevEnd = 0;
      for (var i = k - 1; i >= 0; i--) {
        if (spans[i] != null) {
          prevEnd = spans[i]!.end;
          break;
        }
      }
      var nextStart = frames.frames;
      for (var i = k + 1; i < expected.length; i++) {
        if (spans[i] != null) {
          nextStart = spans[i]!.start;
          break;
        }
      }
      if (nextStart - prevEnd - 1 < thresholds.pauseFrames) {
        optional[k] = false;
        redo = true;
      }
    }
    if (redo) {
      spans = ctcForcedAlign(frames, labels, optional: optional).spans;
    }
    return spans;
  }

  (int, int, int, int) _window(List<FrameSpan?> spans, int k, int frames) {
    final ctx = thresholds.context;
    var lo = k, hi = k, got = 0;
    while (lo > 0 && got < ctx) {
      lo--;
      if (spans[lo] != null) got++;
    }
    got = 0;
    while (hi < spans.length - 1 && got < ctx) {
      hi++;
      if (spans[hi] != null) got++;
    }
    int? first, last, prevEnd, nextStart;
    for (var i = lo; i <= hi; i++) {
      if (spans[i] != null) {
        first ??= spans[i]!.start;
        last = spans[i]!.end;
      }
    }
    for (var i = lo - 1; i >= 0 && prevEnd == null; i--) {
      prevEnd = spans[i]?.end;
    }
    for (var i = hi + 1; i < spans.length && nextStart == null; i++) {
      nextStart = spans[i]?.start;
    }
    final f0 = math.max((prevEnd ?? -1) + 1, (first ?? 0) - 3);
    final f1 = math.min((nextStart ?? frames) - 1, (last ?? frames - 1) + 3);
    return (lo, hi, f0, f1);
  }

  static const _qalqalaLetters = 'قطبجد';

  /// Whether [ts]`[k]` is its sound unit's last sound (markers aside).
  static bool _unitFinal(List<PhoneticToken> ts, int k) {
    for (var j = k + 1; j < ts.length; j++) {
      if (ts[j].unit != ts[k].unit) return true;
      if (ts[j].kind != PhoneticTokenKind.marker) return false;
    }
    return true;
  }

  /// Whether [ts]`[k]` is its word's last sound (markers aside).
  static bool _wordFinal(List<PhoneticToken> ts, int k) {
    for (var j = k + 1; j < ts.length; j++) {
      if (ts[j].word != ts[k].word) return true;
      if (ts[j].kind != PhoneticTokenKind.marker) return false;
    }
    return true;
  }

  static List<_Alternative> _alternatives(List<PhoneticToken> ts, int k) {
    final t = ts[k];
    final vowel = ShortVowel.ofToken(t.token);
    if (t.kind == PhoneticTokenKind.vowel && vowel != null) {
      return [
        for (final v in ShortVowel.values)
          if (v != vowel)
            _Alternative(RecitationErrorType.wrongVowel, v.name.toUpperCase(), [
              v.token,
            ]),
        const _Alternative(RecitationErrorType.missingVowel, 'SUKUN', []),
        // A word's last vowel after a qalqala letter, in flow, said as a
        // stop on it (its echo, no vowel) and on into the next word.
        if (k > 0 &&
            _qalqalaLetters.contains(ts[k - 1].symbol) &&
            _wordFinal(ts, k))
          _Alternative(RecitationErrorType.missingVowel, 'STOP', [
            phoneticClassOf('ڇ'),
          ]),
      ];
    }
    // A hidden nūn or mīm (ghunnah): ikhfāʾ «ں», iqlāb or ikhfāʾ shafawī
    // «۾» — said as a plain, clear «ن» / «م» instead.
    if (t.kind == PhoneticTokenKind.long) {
      final plain = _plainOfHidden(t);
      return plain == null
          ? const []
          : [
              _Alternative(
                RecitationErrorType.wrongLetter,
                quranPhoneticVocabulary[plain],
                [plain],
                tajweed: true,
              ),
            ];
    }
    if (t.kind != PhoneticTokenKind.consonant) return const [];
    // A letter another merged into (idghām: «مَن يَقُولُ» as «مَيَّقُولُ»):
    // said as that letter, or single, is a tajweed mistake.
    final merged = _mergedFrom(t);
    if (t.geminate) {
      return [
        _Alternative(
          RecitationErrorType.shaddaError,
          'NO_SHADDA',
          const [],
          tajweed: merged != null,
        ),
      ];
    }
    final next = k + 1 < ts.length ? ts[k + 1] : null;
    final followsVowel =
        next != null &&
        next.unit == t.unit &&
        (next.kind == PhoneticTokenKind.vowel ||
            next.kind == PhoneticTokenKind.long);
    final doubled = next != null && next.geminate;
    // Qalqala (ق ط ب ج د with sukun or at a stop, marked by its optional
    // marker): the echo after the letter is correct tajweed and sounds like
    // a short vowel, so "a vowel after this sakin letter" is not asked.
    final qalqala =
        next != null && next.optional && next.token == phoneticClassOf('ڇ');
    return [
      for (final c in consonantTokens)
        if (c != t.token)
          _Alternative(
            RecitationErrorType.wrongLetter,
            quranPhoneticVocabulary[c],
            [c],
            tajweed: c == merged,
          ),
      if (!followsVowel && !doubled && !qalqala)
        for (final v in ShortVowel.values)
          _Alternative(RecitationErrorType.sukunError, v.name.toUpperCase(), [
            t.token,
            v.token,
          ]),
      if (!doubled && followsVowel)
        _Alternative(RecitationErrorType.shaddaError, 'EXTRA_SHADDA', [
          t.token,
          t.token,
        ]),
    ];
  }
}

/// The plain letter a hidden nasal would be said as without its rule: the
/// ikhfāʾ nasal «ں» as «ن»; «۾» as «م» where it hides a mīm (ikhfāʾ
/// shafawī), else as «ن» (iqlāb of a nūn or tanween). `null` for other
/// tokens.
int? _plainOfHidden(PhoneticToken t) {
  if (t.symbol == 'ں') return phoneticClassOf('ن');
  if (t.symbol == '۾') {
    return phoneticClassOf(t.sourceChar == 'م' ? 'م' : 'ن');
  }
  return null;
}

/// For a letter that another merged into (idghām), the letter merged — a
/// nūn for a tanween; `null` for any other token.
int? _mergedFrom(PhoneticToken t) {
  final s = t.sourceChar;
  if ('ًٌٍ'.contains(s)) return phoneticClassOf('ن');
  if (s != t.symbol && consonantTokens.contains(phoneticClassOrNull(s))) {
    return phoneticClassOrNull(s);
  }
  return null;
}

class _Alternative {
  const _Alternative(
    this.type,
    this.observed,
    this.tokens, {
    this.tajweed = false,
  });
  final RecitationErrorType type;
  final String observed;
  final List<int> tokens;

  /// A tajweed mistake (not judged with tajweed off).
  final bool tajweed;
}

/// The reciter's beat (one haraka, in frames) across a session: each check
/// whose audio holds enough two-count madds adds its own; a check with too
/// few of them — a single word's — judges madds against the recent median.
class BeatMeter {
  final _recent = <double>[];

  /// The median of the recent beats, or `null` before any.
  double? get value {
    if (_recent.isEmpty) return null;
    final sorted = [..._recent]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  void add(double beat) {
    _recent.add(beat);
    if (_recent.length > 9) _recent.removeAt(0);
  }

  void reset() => _recent.clear();
}

/// A word heard said as another word of the passage
/// ([QuranAcousticVerifier.wordSwaps]).
class WordSwap {
  const WordSwap({
    required this.word,
    required this.said,
    required this.likelihoodRatio,
    required this.span,
  });

  /// The expected word, and the word heard in its place.
  final WordRef word, said;

  /// How much better [said] fits (log-likelihood).
  final double likelihoodRatio;
  final FrameSpan span;
}
