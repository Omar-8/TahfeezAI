// QDAT's tajweed labels against the app's verdicts on the words they are
// about (5:109): ikhfāʾ in «أَنتَ» (word 13), the shaddah's ghunnah in «إِنَّكَ»
// (word 12), the separate madd in «لَنَآ» (word 11):
//   dart run tool/acoustic_verification/qdat_rules.dart <tag> [--nasal E/U] [--hidden E/U]
//       [--pack qdath] (the held-out speakers: real_mistakes_data.py)
// For each rule: of the clips where the experts heard it applied / missed,
// how many have that word flagged (M) or uncertain (?).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _art = 'tool/acoustic_verification/model_work/artifacts';

void main(List<String> args) {
  final pi = args.indexOf('--pack');
  final pack = pi < 0 ? 'qdat' : args[pi + 1];
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final labels = (jsonDecode(
    File('$_art/qdat_labels.json').readAsStringSync(),
  ) as Map).cast<String, Object?>();
  final meta = (jsonDecode(
    File('$_art/results/${pack}_${args[0]}.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final bytes = File('$_art/results/${pack}_${args[0]}.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  // --nasal E/U: the nasal sounds' margins (error / uncertain) to try.
  final nasalArg = args.contains('--nasal')
      ? args[args.indexOf('--nasal') + 1].split('/').map(double.parse).toList()
      : <double>[0, 2];
  // --hidden E/U: the hidden nūn / mīm's (ikhfāʾ, iqlāb) margins to try.
  final hiddenArg = args.contains('--hidden')
      ? args[args.indexOf('--hidden') + 1].split('/').map(double.parse).toList()
      : <double>[0, 0];
  // --error E (vowel / letter / shadda) and --minor M (sukun / missing vowel).
  double opt(String name, double fallback) => args.contains('--$name')
      ? double.parse(args[args.indexOf('--$name') + 1])
      : fallback;
  final verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: opt('error', 4),
      letterError: opt('error', 4),
      shaddaError: opt('error', 4),
      sukunError: opt('minor', 3),
      missingVowelError: opt('minor', 3),
      correct: -1,
      pauseFrames: 4,
      sounds: {
        SoundGroup.shadda: SoundMargins(uncertain: 2),
        SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
        SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
        SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
        SoundGroup.nasal: SoundMargins(
          error: nasalArg[0],
          uncertain: nasalArg[1],
        ),
        SoundGroup.throat: SoundMargins(uncertain: 2),
        SoundGroup.hiddenNasal: SoundMargins(
          error: hiddenArg[0],
          uncertain: hiddenArg[1],
        ),
      },
    ),
  );
  const rules = {
    'concealment': (12, 'ikhfa in «أَنتَ»'),
    'the_tight_noon': (11, 'ghunnah of «إِنَّكَ»'),
    'separate_tide': (10, 'separate madd «لَنَآ»'),
  };
  // rule -> applied? -> [clips, flagged, uncertain]
  final counts = <String, Map<bool, List<int>>>{};
  for (final m in meta) {
    final l = labels[m['name']] as Map?;
    if (l == null) continue;
    final expected = reference.words(5109, 7, 14);
    final units = {for (final t in expected) t.unit};
    final at = m['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    final vs = verifier.verify(
      AcousticFrames(
        frames: n,
        classes: 43,
        logProbs: Float32List.sublistView(all, off, off + n * 43),
        frameDuration: const Duration(milliseconds: 40),
      ),
      expected,
      pauses: {
        for (final e in reference.pauseForms(5109).entries)
          if (units.contains(e.key)) e.key: e.value,
      },
    );
    for (final MapEntry(key: rule, value: (word, _)) in rules.entries) {
      final v = l[rule];
      if (v == null) continue;
      final applied = (v as num) >= 1;
      final kinds = {
        for (final x in vs)
          if (x.token.word.wordIndex == word) x.type,
      };
      final c = (counts[rule] ??= {})[applied] ??= [0, 0, 0];
      c[0]++;
      if (kinds.any((k) => k.isError)) {
        c[1]++;
      } else if (kinds.contains(RecitationErrorType.uncertain)) {
        c[2]++;
      }
    }
  }
  for (final MapEntry(key: rule, value: (_, name)) in rules.entries) {
    for (final applied in [true, false]) {
      final c = counts[rule]?[applied];
      if (c == null) continue;
      String p(int x) => '${(100 * x / c[0]).toStringAsFixed(1)}%';
      stdout.writeln(
        '$name, ${applied ? 'applied' : 'missed '} (${c[0]} clips): '
        'flagged ${p(c[1])}, uncertain ${p(c[2])}',
      );
    }
  }
}
