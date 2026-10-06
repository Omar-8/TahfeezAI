// Evaluates the Dart acoustic verifier — the code the app runs — on
// exported model outputs (see export_eval in the README):
//
//   dart run tool/acoustic_verification/evaluate.dart <data.json> <data.f32>
//       [--error 2] [--letter 2] [--missing X] [--sukun X] [--shadda X] [--correct 1]
//       [--confirm] [--sweep] [--compare <ref.json> <ref.f32>] [--json]
//       [--early] [--chunk N] [--learner]
//
// Spliced real mistakes: is the right mistake found in the target word?
// Their unspliced controls and clean recitation (four reciters): how many
// correct words are flagged, or left uncertain? --confirm requires the
// main and the 20 ms-shifted views to agree before flagging a word.
// --compare scores agreement with a reference model's outputs on the same
// cases: frame top-1, per-phoneme verdicts, and per-word results.
// --early (with --compare): the app's quick per-word check (these outputs,
// at the given thresholds) against its ayah check (the reference's, at the
// calibrated thresholds): of the words marked early, how many the ayah
// check confirms, and how many it takes back.
// --chunk N: each case checked as the app checks a long ayah — pieces of N
// words cut from it with 1 s on each side (cut mid-recitation, so located and
// verified with open edges), each word judged by its own piece. Word
// boundaries come from a whole-case alignment, and the frames are the whole
// case's (approximating the model's view of the cut audio).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

const _expect = {
  'vowel_DAMMA_FATHA': RecitationErrorType.wrongVowel,
  'vowel_DAMMA_KASRA': RecitationErrorType.wrongVowel,
  'vowel_FATHA_KASRA': RecitationErrorType.wrongVowel,
  'consonant': RecitationErrorType.wrongLetter,
  'sukun': RecitationErrorType.sukunError,
  'missing_vowel': RecitationErrorType.missingVowel,
  'shadda_missing': RecitationErrorType.shaddaError,
  'shadda_extra': RecitationErrorType.shaddaError,
};

int _chunk = 0;

/// AcousticVerificationController.learnerSounds; --learner applies them
/// (with its uncertain margin and pause length) to the given thresholds.
const _learnerSounds = {
  SoundGroup.shadda: SoundMargins(uncertain: 2),
  SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
  SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
  SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
  SoundGroup.nasal: SoundMargins(uncertain: 2),
  SoundGroup.throat: SoundMargins(uncertain: 2),
};

void main(List<String> args) {
  final chi = args.indexOf('--chunk');
  if (chi >= 0) _chunk = int.parse(args[chi + 1]);
  final meta = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  final bytes = File(args[1]).readAsBytesSync();
  // --temperature T: the model's probabilities rescaled (softmax(logits / T)),
  // a post-training calibration; the verifier itself is unchanged.
  final ti = args.indexOf('--temperature');
  final all = _scaled(
    bytes.buffer.asFloat32List(0, bytes.length ~/ 4),
    ti < 0 ? 1.0 : double.parse(args[ti + 1]),
  );
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  double? opt(String name) {
    final i = args.indexOf('--$name');
    return i < 0 ? null : double.parse(args[i + 1]);
  }

  final confirm = args.contains('--confirm');
  final learner = args.contains('--learner');
  final base = AcousticThresholds(
    error: opt('error') ?? 2.0,
    letterError: opt('letter') ?? 2.0,
    missingVowelError: opt('missing'),
    sukunError: opt('sukun'),
    shaddaError: opt('shadda'),
    correct: opt('correct') ?? 1.0,
    pauseFrames: learner ? 4 : 6,
    sounds: learner ? _learnerSounds : const {},
  );
  // --screen: only the fixed screening subset.
  // --heldout: only the cases outside it (for checking thresholds tuned
  // on the screening subset).
  final screen = args.contains('--screen');
  final heldout = args.contains('--heldout');
  final cases = [
    for (final m in meta)
      if ((!screen || m['screen'] == true) && (!heldout || m['screen'] != true))
        _Case(m, all, reference),
  ];
  final json = args.contains('--json');
  final ci = args.indexOf('--compare');
  if (ci >= 0) {
    final refMeta = (jsonDecode(File(args[ci + 1]).readAsStringSync()) as List)
        .cast<Map<String, Object?>>();
    final refBytes = File(args[ci + 2]).readAsBytesSync();
    final refAll = refBytes.buffer.asFloat32List(0, refBytes.length ~/ 4);
    String key(Map<String, Object?> m) =>
        '${m['set']}|${m['category']}|${m['kind']}|${m['name']}';
    final refCases = {
      for (final m in refMeta) key(m): _Case(m, refAll, reference),
    };
    if (args.contains('--early')) {
      _early(cases, refCases, key, base);
      return;
    }
    _agreement(cases, refCases, key, base, json);
  }
  if (args.contains('--grid')) {
    // Calibration grid: global temperature x a few thresholds, loaded once.
    // One line per setting: clean flagged / uncertain, mistakes right type.
    final raw = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    stdout.writeln(
      'T\terror\tsukun+missing\tcorrect\tflagged\tuncertain\tright',
    );
    for (final t in [0.75, 1.0, 1.25, 1.5, 2.0]) {
      final scaled = _scaled(raw, t);
      final cs = [for (final m in meta) _Case(m, scaled, reference)];
      for (final e in [2.0, 3.0, 4.0, 5.0]) {
        for (final ms in [1.0, 2.0, 3.0]) {
          for (final c in [1.0, 0.5, 0.0]) {
            final s = _stats(
              cs,
              AcousticThresholds(
                error: e,
                letterError: e,
                missingVowelError: ms,
                sukunError: ms,
                correct: c,
              ),
            );
            stdout.writeln(
              '$t\t$e\t$ms\t$c\t${s.$1.toStringAsFixed(2)}\t'
              '${s.$2.toStringAsFixed(2)}\t${s.$3.toStringAsFixed(1)}',
            );
          }
        }
      }
    }
    return;
  }
  if (args.contains('--margins')) {
    _margins(cases, base);
    return;
  }
  if (args.contains('--sweep')) {
    for (final t in [1.0, 1.5, 2.0, 2.5, 3.0]) {
      stdout.writeln('--- all mistake thresholds $t');
      _report(cases, AcousticThresholds(error: t, letterError: t), confirm);
    }
    return;
  }
  _report(cases, base, confirm, json);
}

/// Early marks (quick check, [quick]) against the ayah check's verdicts
/// (the reference, at the app's calibrated thresholds).
void _early(
  List<_Case> cases,
  Map<String, _Case> refCases,
  String Function(Map<String, Object?>) key,
  AcousticThresholds quick,
) {
  // The app's ayah check (AcousticVerificationController.calibratedThresholds).
  const calibrated = AcousticThresholds(
    error: 4,
    letterError: 4,
    shaddaError: 4,
    sukunError: 3,
    missingVowelError: 3,
    correct: -1,
    pauseFrames: 4,
    sounds: _learnerSounds,
  );
  var early = 0, confirmed = 0, takenBack = 0, finals = 0, words = 0;
  var spliced = 0, splicedEarly = 0;
  for (final c in cases) {
    final r = refCases[key(c.m)];
    if (r == null) continue;
    final a = c.judged(quick, false), b = r.judged(calibrated, false);
    for (final w in {...a.keys, ...b.keys}) {
      words++;
      final e = a[w]?.any((t) => t.isError) ?? false;
      final f = b[w]?.any((t) => t.isError) ?? false;
      if (f) finals++;
      if (e) early++;
      if (e && f) confirmed++;
      if (e && !f) takenBack++;
    }
    if (c.m['kind'] == 'spliced') {
      spliced++;
      if (c.targets.any((w) => a[w]?.any((t) => t.isError) ?? false)) {
        splicedEarly++;
      }
    }
  }
  String pc(int a, int b) => b == 0 ? '-' : '${(a * 100 / b).round()}%';
  stdout.writeln(
    'words $words: marked early $early (${pc(early, words)}), '
    'confirmed $confirmed, taken back $takenBack (${pc(takenBack, early)} of '
    'early marks); ayah check marks $finals, of them early '
    '${pc(confirmed, finals)}; spliced mistakes marked early '
    '${pc(splicedEarly, spliced)}',
  );
}

/// (clean words flagged %, clean words uncertain %, mistakes right type %).
(double, double, double) _stats(List<_Case> cases, AcousticThresholds th) {
  var words = 0, flagged = 0, uncertain = 0, n = 0, right = 0;
  for (final c in cases) {
    final judged = c.judged(th, false);
    if (c.m['set'] == 'clean') {
      for (final k in judged.values) {
        words++;
        if (k.any((t) => t.isError)) flagged++;
        if (k.contains(RecitationErrorType.uncertain)) uncertain++;
      }
    } else if (c.m['kind'] == 'spliced') {
      n++;
      final kinds = {for (final w in c.targets) ...?judged[w]};
      if (kinds.contains(_expect[c.m['category']])) right++;
    }
  }
  return (flagged * 100 / words, uncertain * 100 / words, right * 100 / n);
}

/// Log-probabilities at temperature [t]: log softmax(logp / t), per frame.
Float32List _scaled(Float32List lp, double t) {
  if (t == 1.0) return lp;
  final out = Float32List(lp.length);
  for (var f = 0; f + 43 <= lp.length; f += 43) {
    var mx = double.negativeInfinity;
    for (var c = 0; c < 43; c++) {
      final v = lp[f + c] / t;
      out[f + c] = v;
      if (v > mx) mx = v;
    }
    var sum = 0.0;
    for (var c = 0; c < 43; c++) {
      sum += math.exp(out[f + c] - mx);
    }
    final z = mx + math.log(sum);
    for (var c = 0; c < 43; c++) {
      out[f + c] -= z;
    }
  }
  return out;
}

/// The mistake family a verdict's best alternative belongs to.
String _family(PhonemeVerdict v) {
  const vowels = ['DAMMA', 'FATHA', 'KASRA'];
  final o = v.observed;
  if (o == null) return 'none';
  if (v.token.kind == PhoneticTokenKind.vowel) {
    if (o == 'SUKUN') return 'missing_vowel';
    final e = ShortVowel.ofToken(v.token.token)?.name.toUpperCase();
    if (e == null || !vowels.contains(o)) return 'other';
    final p = [e, o]..sort((a, b) => vowels.indexOf(a) - vowels.indexOf(b));
    return 'vowel_${p[0]}_${p[1]}';
  }
  if (o == 'NO_SHADDA') return 'shadda_missing';
  if (o == 'EXTRA_SHADDA') return 'shadda_extra';
  if (vowels.contains(o)) return 'sukun';
  return 'consonant';
}

/// Distributions of the verifier's margin (best alternative minus expected,
/// log-likelihood) per mistake family: on correct recitation (every scored
/// sound of clean ayahs and controls) and on real mistakes (the highest
/// margin in each spliced target word, by the case's category).
void _margins(List<_Case> cases, AcousticThresholds th) {
  final correct = <String, List<double>>{}, mistake = <String, List<double>>{};
  for (final c in cases) {
    final vs = QuranAcousticVerifier(thresholds: th).verify(
      c.main,
      c.expected,
      pauses: c.pauses,
      openStart: c.m['openStart']! as bool,
      openEnd: c.m['openEnd']! as bool,
    );
    if (c.m['kind'] == 'spliced') {
      PhonemeVerdict? top;
      for (final v in vs) {
        if (!c.targets.contains(v.token.word) || v.span == null) continue;
        if (top == null || v.likelihoodRatio > top.likelihoodRatio) top = v;
      }
      if (top != null) {
        (mistake[c.m['category']! as String] ??= []).add(top.likelihoodRatio);
      }
      continue;
    }
    for (final v in vs) {
      if (v.span == null || v.observed == null) continue;
      (correct[_family(v)] ??= []).add(v.likelihoodRatio);
    }
  }
  String q(List<double> x) {
    x.sort();
    double p(double f) => x[((x.length - 1) * f).round()];
    String n(double v) => v.toStringAsFixed(1).padLeft(6);
    return 'n ${x.length.toString().padLeft(5)} | p5 ${n(p(.05))} p25 ${n(p(.25))} '
        'p50 ${n(p(.5))} p75 ${n(p(.75))} p95 ${n(p(.95))} p99 ${n(p(.99))}';
  }

  String share(List<double> x, double lo, double hi) =>
      '${(x.where((v) => v > lo && v < hi).length * 100 / x.length).toStringAsFixed(1)}%';
  stdout.writeln(
    'margin = best alternative - expected (log-likelihood); > 0 favours a mistake',
  );
  for (final f in correct.keys.toList()..sort()) {
    final x = correct[f]!;
    final err = th.errorFor(switch (f) {
      'consonant' => RecitationErrorType.wrongLetter,
      'sukun' => RecitationErrorType.sukunError,
      'missing_vowel' => RecitationErrorType.missingVowel,
      'shadda_missing' || 'shadda_extra' => RecitationErrorType.shaddaError,
      _ => RecitationErrorType.wrongVowel,
    });
    stdout.writeln(
      '  CORRECT ${f.padRight(18)} ${q(x)} | uncertain ${share(x, -th.correct, err)} '
      'flagged ${share(x, err - 1e-9, double.infinity)}',
    );
  }
  for (final f in mistake.keys.toList()..sort()) {
    stdout.writeln('  MISTAKE ${f.padRight(18)} ${q(mistake[f]!)}');
  }
}

void _agreement(
  List<_Case> cases,
  Map<String, _Case> refs,
  String Function(Map<String, Object?>) key,
  AcousticThresholds th,
  bool json,
) {
  var frames = 0, sameFrames = 0, tokens = 0, sameTokens = 0;
  var words = 0, sameWords = 0, refErr = 0, candErr = 0, bothErr = 0;
  for (final c in cases) {
    final r = refs[key(c.m)];
    if (r == null) continue;
    final n = c.main.frames < r.main.frames ? c.main.frames : r.main.frames;
    for (var f = 0; f < n; f++) {
      var a = 0, b = 0;
      for (var k = 1; k < 43; k++) {
        if (c.main.at(f, k) > c.main.at(f, a)) a = k;
        if (r.main.at(f, k) > r.main.at(f, b)) b = k;
      }
      frames++;
      if (a == b) sameFrames++;
    }
    final verifier = QuranAcousticVerifier(thresholds: th);
    List<PhonemeVerdict> run(_Case x) => verifier.verify(
      x.main,
      x.expected,
      pauses: x.pauses,
      openStart: x.m['openStart']! as bool,
      openEnd: x.m['openEnd']! as bool,
    );
    final vc = run(c), vr = run(r);
    if (vc.length == vr.length) {
      for (var i = 0; i < vc.length; i++) {
        tokens++;
        if (vc[i].type == vr[i].type) sameTokens++;
      }
    }
    final wc = c.judged(th, false), wr = r.judged(th, false);
    for (final w in wr.keys) {
      words++;
      final a = wc[w] ?? const {}, b = wr[w]!;
      if (a.length == b.length && a.containsAll(b)) sameWords++;
      final ea = a.any((t) => t.isError), eb = b.any((t) => t.isError);
      if (ea) candErr++;
      if (eb) refErr++;
      if (ea && eb) bothErr++;
    }
  }
  String p(int a, int b) => b == 0 ? '–' : (a * 100 / b).toStringAsFixed(1);
  if (json) {
    stdout.writeln(
      jsonEncode({
        'frameAgreement': p(sameFrames, frames),
        'verdictAgreement': p(sameTokens, tokens),
        'wordAgreement': p(sameWords, words),
        'errorWordsKept': p(bothErr, refErr),
        'errorWordsNew': candErr - bothErr,
      }),
    );
    return;
  }
  stdout.writeln(
    'agreement with reference: frames ${p(sameFrames, frames)}%  '
    'phoneme verdicts ${p(sameTokens, tokens)}%  word results ${p(sameWords, words)}%  '
    '| reference mistake-words kept ${p(bothErr, refErr)}% ($bothErr/$refErr), '
    'new mistake-words ${candErr - bothErr}',
  );
}

class _Case {
  _Case(this.m, Float32List all, QuranPhoneticReference reference)
    : main = _frames(m['main']! as Map, all),
      shifted = m['shifted'] == null
          ? null
          : _frames(m['shifted']! as Map, all) {
    final ayahId = m['ayahId']! as int;
    expected = reference.words(
      ayahId,
      m['firstWord']! as int,
      m['lastWord']! as int,
    );
    final units = {for (final t in expected) t.unit};
    pauses = {
      for (final MapEntry(:key, :value) in reference.pauseForms(ayahId).entries)
        if (units.contains(key)) key: value,
    };
    targets = {
      for (final w in (m['targetWords']! as List).cast<int>())
        (ayahId: ayahId, wordIndex: w),
    };
  }

  final Map<String, Object?> m;
  final AcousticFrames main;
  final AcousticFrames? shifted;
  late final List<PhoneticToken> expected;
  late final Map<int, PauseForms> pauses;
  late final Set<WordRef> targets;

  static AcousticFrames _frames(Map at, Float32List all) {
    final frames = at['frames'] as int;
    final offset = at['offset'] as int;
    return AcousticFrames(
      frames: frames,
      classes: 43,
      logProbs: Float32List.sublistView(all, offset, offset + frames * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
  }

  Map<WordRef, Set<RecitationErrorType>> words(
    AcousticThresholds th,
    AcousticFrames frames,
  ) {
    if (_chunk > 0) {
      final chunked = _chunked(th, frames);
      if (chunked != null) return chunked;
    }
    final vs = QuranAcousticVerifier(thresholds: th).verify(
      frames,
      expected,
      pauses: pauses,
      openStart: m['openStart']! as bool,
      openEnd: m['openEnd']! as bool,
    );
    final out = <WordRef, Set<RecitationErrorType>>{};
    for (final v in vs) {
      (out[v.token.word] ??= {}).add(v.type);
    }
    return out;
  }

  /// [words], checked in pieces of [_chunk] words as the app checks a long
  /// ayah; `null` if the case is too short or its words can't be timed.
  Map<WordRef, Set<RecitationErrorType>>? _chunked(
    AcousticThresholds th,
    AcousticFrames frames,
  ) {
    final verifier = QuranAcousticVerifier(thresholds: th);
    final order = <WordRef>[];
    for (final t in expected) {
      if (order.isEmpty || order.last != t.word) order.add(t.word);
    }
    if (order.length <= _chunk) return null;
    final openAll = m['openStart']! as bool, openEndAll = m['openEnd']! as bool;
    // Word boundaries: a whole-case alignment.
    final span = <WordRef, (int, int)>{};
    for (final v in verifier.verify(
      frames,
      expected,
      pauses: pauses,
      openStart: openAll,
      openEnd: openEndAll,
    )) {
      final s = v.span;
      if (s == null) continue;
      final at = span[v.token.word];
      span[v.token.word] = at == null
          ? (s.start, s.end)
          : (math.min(at.$1, s.start), math.max(at.$2, s.end));
    }
    if (order.any((w) => !span.containsKey(w))) return null;
    final index = {for (final (i, w) in order.indexed) w: i};
    final out = <WordRef, Set<RecitationErrorType>>{};
    for (var i = 0; i < order.length; i += _chunk) {
      final j = math.min(order.length, i + _chunk) - 1;
      final lo = math.max(0, span[order[i]]!.$1 - 25);
      final hi = math.min(frames.frames - 1, span[order[j]]!.$2 + 25);
      final piece = frames.slice(lo, hi);
      final openStart = i > 0 || openAll;
      final openEnd = j < order.length - 1 || openEndAll;
      final cand = [
        for (final t in expected)
          if (index[t.word]! >= i - 3 && index[t.word]! <= j + 6) t,
      ];
      final located = verifier.locate(
        piece,
        cand,
        openStart: openStart,
        openEnd: openEnd,
      );
      if (located == null) continue;
      final (ulo, uhi) = located;
      final vs = verifier.verify(
        piece,
        [
          for (final t in cand)
            if (t.unit >= ulo && t.unit <= uhi) t,
        ],
        pauses: {
          for (final MapEntry(:key, :value) in pauses.entries)
            if (key >= ulo && key <= uhi) key: value,
        },
        openStart: openStart,
        openEnd: openEnd,
      );
      // As the app: no word cut off where the audio was cut.
      final reach = <WordRef, (int, int)>{};
      for (final v in vs) {
        final s = v.span;
        if (s == null) continue;
        final at = reach[v.token.word];
        reach[v.token.word] = at == null
            ? (s.start, s.end)
            : (math.min(at.$1, s.start), math.max(at.$2, s.end));
      }
      for (final v in vs) {
        final k = index[v.token.word];
        if (k == null || k < i || k > j) continue;
        final r = reach[v.token.word];
        if (r != null &&
            ((openStart && r.$1 < 8) ||
                (openEnd && r.$2 >= piece.frames - 8))) {
          continue;
        }
        (out[v.token.word] ??= {}).add(v.type);
      }
    }
    return out;
  }

  /// Per word: its mistake types, `{uncertain}` or `{}` (correct). With
  /// [confirm], a mistake stands only if both views find one.
  Map<WordRef, Set<RecitationErrorType>> judged(
    AcousticThresholds th,
    bool confirm,
  ) {
    Set<RecitationErrorType> summary(Set<RecitationErrorType> kinds) {
      final errors = kinds.where((k) => k.isError).toSet();
      if (errors.isNotEmpty) return errors;
      return kinds.contains(RecitationErrorType.uncertain)
          ? {RecitationErrorType.uncertain}
          : {};
    }

    final a = {
      for (final e in words(th, main).entries) e.key: summary(e.value),
    };
    if (!confirm || shifted == null) return a;
    final b = {
      for (final e in words(th, shifted!).entries) e.key: summary(e.value),
    };
    return {
      for (final MapEntry(key: w, value: ka) in a.entries)
        w: () {
          final kb = b[w] ?? const <RecitationErrorType>{};
          final ea = ka.any((k) => k.isError), eb = kb.any((k) => k.isError);
          if (ea && eb) return ka;
          if (ea || eb) return {RecitationErrorType.uncertain};
          if (ka.isNotEmpty && kb.isNotEmpty) return ka;
          return <RecitationErrorType>{};
        }(),
    };
  }
}

void _report(
  List<_Case> cases,
  AcousticThresholds th,
  bool confirm, [
  bool json = false,
]) {
  final rows =
      <String, List<int>>{}; // n, right, anyError, uncertain, control flagged
  final clean = <String, List<int>>{}; // words, flagged, uncertain
  var withShift = 0;
  for (final c in cases) {
    if (confirm && c.shifted == null) continue;
    if (c.shifted != null) withShift++;
    final judged = c.judged(th, confirm);
    final set = c.m['set'];
    final cat = c.m['category']! as String;
    if (set == 'clean') {
      final r = clean[cat] ??= [0, 0, 0];
      for (final k in judged.values) {
        r[0]++;
        if (k.any((t) => t.isError)) r[1]++;
        if (k.contains(RecitationErrorType.uncertain)) r[2]++;
      }
      continue;
    }
    final kinds = {for (final w in c.targets) ...?judged[w]};
    final r = rows[cat] ??= [0, 0, 0, 0, 0, 0];
    if (c.m['kind'] == 'spliced') {
      r[0]++;
      if (kinds.contains(_expect[cat])) r[1]++;
      if (kinds.any((k) => k.isError)) r[2]++;
      if (!kinds.any((k) => k.isError) &&
          kinds.contains(RecitationErrorType.uncertain)) {
        r[3]++;
      }
    } else {
      r[5]++;
      if (kinds.any((k) => k.isError)) r[4]++;
    }
  }
  String pct(int a, int b) =>
      b == 0 ? '  –' : '${(a * 100 / b).round()}%'.padLeft(4);
  stdout.writeln(
    'thresholds: error ${th.error} letter ${th.letterError} '
    'missing ${th.missingVowelError ?? th.error} sukun ${th.sukunError ?? th.error} '
    'shadda ${th.shaddaError ?? th.error}${confirm ? ' · confirmed by 2 views ($withShift cases)' : ''}',
  );
  var n = 0, right = 0;
  for (final MapEntry(key: cat, value: r) in rows.entries) {
    n += r[0];
    right += r[1];
    stdout.writeln(
      '  ${cat.padRight(18)} n=${r[0].toString().padLeft(2)} right type ${pct(r[1], r[0])}'
      '  any error ${pct(r[2], r[0])}  uncertain ${pct(r[3], r[0])}'
      '  | control flagged ${pct(r[4], r[5])}',
    );
  }
  if (n > 0) stdout.writeln('  all mistakes: right type ${pct(right, n)}');
  var w = 0, f = 0, u = 0;
  for (final MapEntry(key: cat, value: r) in clean.entries) {
    w += r[0];
    f += r[1];
    u += r[2];
    stdout.writeln(
      '  clean ${cat.padRight(22)} words ${r[0]}  flagged ${pct(r[1], r[0])}'
      '  uncertain ${pct(r[2], r[0])}',
    );
  }
  if (w > 0) {
    stdout.writeln(
      '  clean all: flagged ${(f * 100 / w).toStringAsFixed(1)}%'
      '  uncertain ${(u * 100 / w).toStringAsFixed(1)}%',
    );
  }
  if (json) {
    stdout.writeln(
      'JSON ${jsonEncode({
        for (final MapEntry(key: cat, value: r) in rows.entries) cat: {'n': r[0], 'right': pct(r[1], r[0]).trim(), 'any': pct(r[2], r[0]).trim(), 'uncertain': pct(r[3], r[0]).trim(), 'controlFlagged': pct(r[4], r[5]).trim()},
        for (final MapEntry(key: cat, value: r) in clean.entries) 'clean_$cat': {'words': r[0], 'flagged': pct(r[1], r[0]).trim(), 'uncertain': pct(r[2], r[0]).trim()},
        'clean_all': {'flagged': w == 0 ? null : (f * 100 / w).toStringAsFixed(1), 'uncertain': w == 0 ? null : (u * 100 / w).toStringAsFixed(1)},
      })}',
    );
  }
}
