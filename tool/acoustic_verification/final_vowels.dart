// Short vowels said as another short vowel: how often the app's ayah check
// catches them, word-final against inside a word, and how often a correct
// one would be flagged, by threshold:
//   dart run tool/acoustic_verification/final_vowels.dart <tag> [sessions]
// Mistakes: QuranMB.v2's annotated swaps (results/quranmb_<tag>); correct
// vowels: the user's phone sessions (results/sessions_<tag>, or the pack
// given), all words taken as said correctly.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _art = 'tool/acoustic_verification/model_work/artifacts';

// The app's (AcousticVerificationController.calibratedThresholds).
QuranAcousticVerifier _verifierWith(double margin, [double stop = 0]) =>
    QuranAcousticVerifier(
      thresholds: AcousticThresholds(
        error: 4,
        letterError: 4,
        shaddaError: 4,
        sukunError: 3,
        missingVowelError: 3,
        correct: -1,
        pauseFrames: 4,
        sounds: {
          SoundGroup.shadda: SoundMargins(uncertain: 2),
          SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
          SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
          SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
          SoundGroup.nasal: SoundMargins(uncertain: 2),
          SoundGroup.throat: SoundMargins(uncertain: 2),
          SoundGroup.wordFinalVowel: SoundMargins(error: margin),
          SoundGroup.stopInFlow: SoundMargins(error: stop),
        },
      ),
    );
final _verifier = _verifierWith(0);

const _vowels = {'َ': 'a', 'ُ': 'u', 'ِ': 'i'};
const _names = {'FATHA': 'a', 'DAMMA': 'u', 'KASRA': 'i'};

// IqraEval phonemes -> the coarse alphabet both sides are aligned in.
const _ph = {
  'b': 'ب',
  't': 'ت',
  '^': 'ث',
  'j': 'ج',
  'H': 'ح',
  'x': 'خ',
  'd': 'د',
  '*': 'ذ',
  'r': 'ر',
  'z': 'ز',
  's': 'س',
  r'$': 'ش',
  'S': 'ص',
  'D': 'ض',
  'T': 'ط',
  'Z': 'ظ',
  'E': 'ع',
  'g': 'غ',
  'f': 'ف',
  'q': 'ق',
  'k': 'ك',
  'm': 'م',
  'n': 'ن',
  'h': 'ه',
  '<': 'ء',
  'l': 'ل',
  'w': 'و',
  'y': 'ي',
};
String _coarseIqra(String p) {
  if (p == 'a' || p == 'A') return 'a';
  if (p == 'u' || p == 'U') return 'u';
  if (p == 'i' || p == 'I') return 'i';
  if (p == 'aa' || p == 'AA') return 'A';
  if (p == 'uu' || p == 'UU') return 'U';
  if (p == 'ii' || p == 'II') return 'I';
  return _ph[p[0]] ?? '?';
}

String? _coarseToken(PhoneticToken t) => switch (t.kind) {
  PhoneticTokenKind.vowel => _vowels[t.symbol],
  PhoneticTokenKind.long => switch (t.symbol) {
    'ا' => 'A',
    'ۥ' => 'U',
    'ۦ' => 'I',
    _ => null,
  },
  PhoneticTokenKind.consonant => t.symbol,
  PhoneticTokenKind.marker => null,
};

/// Levenshtein alignment: for each of [a], its index in [b] (null: none).
List<int?> _align(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final d = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      d[i][j] = [
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      ].reduce(math.min);
    }
  }
  final out = List<int?>.filled(n, null);
  var i = n, j = m;
  while (i > 0 && j > 0) {
    if (d[i][j] == d[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) {
      out[i - 1] = j - 1;
      i--;
      j--;
    } else if (d[i][j] == d[i - 1][j] + 1) {
      i--;
    } else {
      j--;
    }
  }
  return out;
}

class _Pack {
  _Pack(String name)
    : cases = (jsonDecode(
        File('$_art/results/$name.json').readAsStringSync(),
      ) as List).cast<Map<String, Object?>>(),
      all = _floats('$_art/results/$name.f32');

  static Float32List _floats(String path) {
    final b = File(path).readAsBytesSync();
    return b.buffer.asFloat32List(0, b.length ~/ 4);
  }

  final List<Map<String, Object?>> cases;
  final Float32List all;

  AcousticFrames frames(int i) {
    final at = cases[i]['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    return AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: Float32List.sublistView(all, off, off + n * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
  }
}

List<PhonemeVerdict> _verify(
  QuranPhoneticReference reference,
  Map<String, Object?> c,
  AcousticFrames frames,
  List<PhoneticToken> expected, [
  QuranAcousticVerifier? verifier,
]) {
  final ayahId = c['ayahId']! as int;
  final units = {for (final t in expected) t.unit};
  return (verifier ?? _verifier).verify(
    frames,
    expected,
    pauses: {
      for (final e in reference.pauseForms(ayahId).entries)
        if (units.contains(e.key)) e.key: e.value,
    },
    openStart: c['openStart'] == true,
    openEnd: c['openEnd'] == true,
  );
}

/// Whether [t] is its word's last sound (markers aside).
bool _wordFinal(List<PhoneticToken> ts, int k) {
  for (var j = k + 1; j < ts.length; j++) {
    if (ts[j].word != ts[k].word) return true;
    if (ts[j].kind != PhoneticTokenKind.marker) return false;
  }
  return true;
}

/// The vowel's verdict: its likelihood ratio for [said] (the vowel said
/// instead; null: the strongest other), and the verdict type.
(double, String)? _score(List<PhonemeVerdict> vs, PhoneticToken t) {
  for (final v in vs) {
    if (v.token.word == t.word &&
        v.token.letter == t.letter &&
        v.token.kind == PhoneticTokenKind.vowel) {
      return (v.likelihoodRatio, v.type.name);
    }
  }
  return null;
}

void main(List<String> args) {
  final tag = args[0];
  final sessions = args.length > 1 ? args[1] : 'sessions';
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final gt = <String, (List<String>, List<String>)>{};
  final lines = File('$_art/external/IqraEval_Test_GT__labels_test.csv')
      .readAsLinesSync();
  for (final l in lines.skip(1)) {
    final p = l.split(',');
    gt['quranmb_${p[0]}'] = (
      p[1].trim().split(' ').where((s) => s.isNotEmpty).toList(),
      p[2].trim().split(' ').where((s) => s.isNotEmpty).toList(),
    );
  }

  // Mistakes: (word-final?, from -> to, llr, verdict).
  final found = <(bool, String, double, String)>[];
  // FV_PACK=quranmbh: QuranMB's held-out speakers only (learner_data.py).
  final mb = _Pack('${Platform.environment['FV_PACK'] ?? 'quranmb'}_$tag');
  for (var i = 0; i < mb.cases.length; i++) {
    final c = mb.cases[i];
    if (c['kind'] != 'mistake') continue;
    final g = gt[c['name']];
    if (g == null) continue;
    final ref = g.$1.map(_coarseIqra).toList();
    final ann = g.$2.map(_coarseIqra).toList();
    final expected = reference.words(
      c['ayahId']! as int,
      c['firstWord']! as int,
      c['lastWord']! as int,
    );
    final coarse = <String>[], owner = <int>[];
    for (var k = 0; k < expected.length; k++) {
      final s = _coarseToken(expected[k]);
      if (s == null) continue;
      coarse.add(s);
      owner.add(k);
    }
    final toAnn = _align(ref, ann), toTok = _align(ref, coarse);
    List<PhonemeVerdict>? vs;
    for (var p = 0; p < ref.length; p++) {
      final q = toAnn[p], k = toTok[p];
      if (q == null || k == null) continue;
      final from = ref[p], to = ann[q];
      if (!'aui'.contains(from) || !'aui'.contains(to) || from == to) continue;
      if (coarse[k] != from) continue;
      // A clean swap: the neighbours said as written.
      var clean = true;
      for (final d in [-2, -1, 1, 2]) {
        final pp = p + d;
        if (pp < 0 || pp >= ref.length) continue;
        final qq = toAnn[pp];
        if (qq == null || ann[qq] != ref[pp]) clean = false;
      }
      if (!clean) continue;
      final t = expected[owner[k]];
      // The phrase's very last vowel: dropped at its stop, not judged.
      if (p >= ref.length - 2) continue;
      vs ??= _verify(reference, c, mb.frames(i), expected);
      final s = _score(vs, t);
      if (s == null) continue;
      found.add((_wordFinal(expected, owner[k]), '$from→$to', s.$1, s.$2));
    }
  }

  // Correct vowels in the user's sessions: (word-final?, llr).
  final correct = <(bool, double)>[];
  final sp = _Pack('${sessions}_$tag');
  for (var i = 0; i < sp.cases.length; i++) {
    final c = sp.cases[i];
    final expected = reference.words(
      c['ayahId']! as int,
      c['firstWord']! as int,
      c['lastWord']! as int,
    );
    final vs = _verify(reference, c, sp.frames(i), expected);
    for (var k = 0; k < expected.length; k++) {
      final t = expected[k];
      if (t.kind != PhoneticTokenKind.vowel) continue;
      for (final v in vs) {
        if (v.token.word == t.word &&
            v.token.letter == t.letter &&
            v.token.kind == PhoneticTokenKind.vowel) {
          // Flagged only as a swap for another short vowel.
          correct.add((
            _wordFinal(expected, k),
            _names.containsKey(v.observed) ? v.likelihoodRatio : -99,
          ));
          break;
        }
      }
    }
  }

  String pct(int a, int b) =>
      b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}% ($a/$b)';
  for (final fin in [true, false]) {
    final ms = found.where((f) => f.$1 == fin).toList();
    final cs = correct.where((c) => c.$1 == fin).toList();
    final cAll = sp.cases.isEmpty
        ? 0
        : correct.length; // vowels with a vowel competitor
    stdout.writeln(
      '${fin ? 'WORD-FINAL' : 'INSIDE A WORD'}: ${ms.length} swaps, '
      'as judged now: ${{for (final m in ms) m.$4: ms.where((x) => x.$4 == m.$4).length}}',
    );
    for (final th in [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]) {
      stdout.writeln(
        '  at $th: caught ${pct(ms.where((m) => m.$3 >= th).length, ms.length)}'
        ', your correct ones flagged '
        '${pct(cs.where((c) => c.$2 >= th).length, cs.length)}'
        '${cAll == 0 ? '' : ''}',
      );
    }
    final pairs = {for (final m in ms) m.$2}.toList()..sort();
    for (final pair in pairs) {
      final x = ms.where((m) => m.$2 == pair).toList();
      stdout.writeln(
        '    $pair: caught at 4 ${pct(x.where((m) => m.$3 >= 4).length, x.length)}'
        ', at 3 ${pct(x.where((m) => m.$3 >= 3).length, x.length)}'
        ', at 2 ${pct(x.where((m) => m.$3 >= 2).length, x.length)}'
        ', at 1 ${pct(x.where((m) => m.$3 >= 1).length, x.length)}',
      );
    }
  }

  // Learners' clips, judged whole as the app would at each margin: words
  // flagged in clips said correctly, target words flagged in vowel
  // mistakes.
  for (final name in ['quranmb', 'ikhlash', 'qdath']) {
    final pack = _Pack('${name}_$tag');
    for (final (margin, stop) in [
      (0.0, 9.0),
      (-1.0, 9.0),
      (-1.0, 0.0),
      (-1.0, 1.0),
      (-1.0, 2.0),
    ]) {
      final v = _verifierWith(margin, stop);
      var cleanWords = 0, cleanFlagged = 0, targets = 0, caught = 0;
      for (var i = 0; i < pack.cases.length; i++) {
        final c = pack.cases[i];
        final cat = c['category'] as String;
        final clean = c['kind'] == 'clean' && cat != 'qdat_unlabelled';
        final vowel = cat == 'ikhlas_vowel' || cat == 'quranmb_mistake';
        if (!clean && !vowel) continue;
        final expected = reference.words(
          c['ayahId']! as int,
          c['firstWord']! as int,
          c['lastWord']! as int,
        );
        final vs = _verify(reference, c, pack.frames(i), expected, v);
        final flagged = {
          for (final x in vs)
            if (x.type.isError) x.token.word.wordIndex,
        };
        if (clean) {
          cleanWords += {for (final t in expected) t.word}.length;
          cleanFlagged += flagged.length;
        } else {
          final ts = (c['targetWords']! as List).cast<int>();
          targets += ts.length;
          caught += ts.where(flagged.contains).length;
        }
      }
      stdout.writeln(
        '$name margin $margin stop $stop: correct words flagged '
        '${pct(cleanFlagged, cleanWords)}, mistaken words caught '
        '${pct(caught, targets)}',
      );
    }
  }
}
