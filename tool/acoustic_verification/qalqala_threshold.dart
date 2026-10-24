// The qalqala check's margin ("said without the echo" over "with it") on
// labelled sets, to choose its threshold for a model:
//   dart run tool/acoustic_verification/qalqala_threshold.dart <model tag> \
//     <pack> ...
// Packs: results/<pack>_<tag>.{json,f32}. A mistake case's target words with
// a qalqala letter are its "missing echo" examples (Surah Al-Ikhlas learners:
// category ikhlas_qalqala); every qalqala letter of a clean case is a
// correct example. Prints, per threshold, the share of each flagged.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

void main(List<String> args) {
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  // The app's thresholds (the streaming model's), the echo always reported.
  const verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: 4,
      letterError: 4,
      shaddaError: 4,
      sukunError: 2,
      missingVowelError: 2,
      correct: -1,
      pauseFrames: 4,
      qalqalaError: 99,
      sounds: {
        SoundGroup.shadda: SoundMargins(uncertain: 2),
        SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
        SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
        SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
        SoundGroup.nasal: SoundMargins(uncertain: 2),
        SoundGroup.throat: SoundMargins(uncertain: 2),
      },
    ),
  );
  final tag = args[0];
  final missing = <String, List<double>>{}, kept = <String, List<double>>{};
  // --by-letter: the correct qalqalas' scores per letter too.
  final byLetter = args.contains('--by-letter');
  final letters = <String, Map<String, List<double>>>{};
  for (final pack in args.skip(1).where((a) => !a.startsWith('--'))) {
    final meta = (jsonDecode(
      File('$_results/${pack}_$tag.json').readAsStringSync(),
    ) as List).cast<Map<String, Object?>>();
    final bytes = File('$_results/${pack}_$tag.f32').readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    for (final m in meta) {
      final mistake = m['set'] == 'mistake';
      if (mistake && m['category'] != 'ikhlas_qalqala') continue;
      final ayahId = m['ayahId']! as int;
      final at = m['main']! as Map;
      final n = at['frames'] as int, off = at['offset'] as int;
      final vs = verifier.verify(
        AcousticFrames(
          frames: n,
          classes: 43,
          logProbs: Float32List.sublistView(all, off, off + n * 43),
          frameDuration: const Duration(milliseconds: 40),
        ),
        reference.words(ayahId, m['firstWord']! as int, m['lastWord']! as int),
        pauses: reference.pauseForms(ayahId),
        openStart: m['openStart'] == true,
        openEnd: m['openEnd'] == true,
      );
      final targets = (m['targetWords']! as List).cast<int>();
      String? letter;
      for (final v in vs) {
        if (v.token.symbol != 'ڇ') {
          letter = v.token.symbol;
          continue;
        }
        if (byLetter && !mistake) {
          (letters[letter ?? '?'] ??= {})
              .putIfAbsent(pack, () => [])
              .add(v.likelihoodRatio);
        }
        if (mistake && !targets.contains(v.token.word.wordIndex)) continue;
        (mistake ? missing : kept)
            .putIfAbsent(pack, () => [])
            .add(v.likelihoodRatio);
      }
    }
  }
  if (byLetter) {
    // Correct qalqalas' scores by letter (deciles; lower: the echo surer).
    for (final MapEntry(key: l, value: packs) in letters.entries) {
      final xs = [for (final v in packs.values) ...v]..sort();
      String at(double q) =>
          xs[(q * (xs.length - 1)).round()].toStringAsFixed(1);
      stdout.writeln(
        '$l: ${xs.length} correct — 5% ${at(.05)} | 10% ${at(.1)} | 25% '
        '${at(.25)} | median ${at(.5)} | 75% ${at(.75)} | 90% ${at(.9)}',
      );
    }
  }
  String share(List<double> xs, double t) =>
      '${(100 * xs.where((x) => x >= t).length / xs.length).toStringAsFixed(1)}%';
  stdout.writeln(
    'threshold  ${[for (final p in missing.keys) 'caught $p (${missing[p]!.length})', for (final p in kept.keys) 'flagged $p (${kept[p]!.length})'].join('  ')}',
  );
  for (final t in [
    -3.0,
    -2.0,
    -1.5,
    -1.25,
    -1.0,
    -0.5,
    0.0,
    0.5,
    1.0,
    1.5,
    2.0,
    2.5,
    3.0,
    4.0,
  ]) {
    stdout.writeln(
      '${t.toStringAsFixed(1).padLeft(9)}  ${[for (final xs in missing.values) share(xs, t).padLeft(8), for (final xs in kept.values) share(xs, t).padLeft(8)].join('  ')}',
    );
  }
}
