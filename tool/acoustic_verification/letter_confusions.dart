// Which letters the verifier hears as which: every wrong-letter mistake on a
// word not marked as a real mistake (correct recitation), as expected →
// heard, with its count and how often that letter is flagged; and on the
// words that are (a real mistake) the same, as caught.
//
//   dart run tool/acoustic_verification/letter_confusions.dart <tag> <v35|v36|v36+s2> <pack>...
//   (e.g. r6g2e8 v36 phone phone2 ... — results/<pack>_<tag>.json/.f32)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

const _margins = {
  SoundGroup.shadda: SoundMargins(uncertain: 2),
  SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
  SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
  SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
  SoundGroup.nasal: SoundMargins(uncertain: 2),
  SoundGroup.throat: SoundMargins(uncertain: 2),
  SoundGroup.wordFinalVowel: SoundMargins(error: -1),
  SoundGroup.stopInFlow: SoundMargins(error: 1),
};

/// v35, v36, or v36+sN (N more for [SoundGroup.similarLetter]); +eX: v36's margins at X
/// instead of 3 (a model's own threshold); +wN: [SoundGroup.phoneWeak] at N more.
AcousticThresholds _settings(String preset) {
  final v36 = preset.startsWith('v36');
  final similar = RegExp(r'\+s([\d.]+)').firstMatch(preset);
  final e = double.parse(RegExp(r'\+e([\d.]+)').firstMatch(preset)?[1] ?? '3');
  // +wN: [SoundGroup.phoneWeak] at N more.
  final weak = RegExp(r'\+w([\d.]+)').firstMatch(preset);
  return AcousticThresholds(
    error: v36 ? e : 4,
    letterError: v36 ? e : 4,
    shaddaError: v36 ? e : 4,
    sukunError: v36 ? e : 2,
    missingVowelError: v36 ? e : 2,
    correct: -1,
    pauseFrames: 4,
    sounds: {
      ..._margins,
      if (v36) SoundGroup.hiddenNasal: const SoundMargins(error: -1),
      if (similar != null)
        SoundGroup.similarLetter: SoundMargins(
          error: double.parse(similar[1]!),
        ),
      if (weak != null)
        SoundGroup.phoneWeak: SoundMargins(
          error: double.parse(weak[1]!),
          uncertain: 2,
        ),
    },
  );
}

Future<void> main(List<String> arguments) async {
  final args = [...arguments];
  // --all: every confusion, not the 25 commonest.
  final all = args.remove('--all');
  // --dump FILE: every letter flag as a JSON line (pack, a real mistake's word or
  // not, expected, heard, likelihood ratio) — margins per pair worked out after.
  final dumpAt = args.indexOf('--dump');
  IOSink? dump;
  if (dumpAt >= 0) {
    dump = File(args[dumpAt + 1]).openWrite();
    args.removeRange(dumpAt, dumpAt + 2);
  }
  final tag = args[0], packs = args.sublist(2);
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final th = _settings(args[1]);
  final pairs = <String, List<double>>{}, seen = <String, int>{};
  final caught = <String, int>{};
  var letters = 0, flagged = 0, words = 0;
  for (final pack in packs) {
    final file = File('$_results/${pack}_$tag.json');
    if (!file.existsSync()) {
      stderr.writeln('missing ${pack}_$tag');
      continue;
    }
    final raw = jsonDecode(file.readAsStringSync());
    final meta = (raw is List ? raw : (raw as Map)['cases'] as List)
        .cast<Map<String, Object?>>();
    final bytes = File('$_results/${pack}_$tag.f32').readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    for (final m in meta) {
      final ayahId = m['ayahId']! as int;
      final expected = reference.words(
        ayahId,
        m['firstWord']! as int,
        m['lastWord']! as int,
      );
      final units = {for (final t in expected) t.unit};
      final targets = {
        for (final w in (m['targetWords']! as List).cast<int>())
          (ayahId: ayahId, wordIndex: w),
      };
      final at = m['main']! as Map;
      final n = at['frames'] as int, off = at['offset'] as int;
      final verdicts = QuranAcousticVerifier(thresholds: th).verify(
        AcousticFrames(
          frames: n,
          classes: 43,
          logProbs: Float32List.sublistView(all, off, off + n * 43),
          frameDuration: const Duration(milliseconds: 40),
        ),
        expected,
        pauses: {
          for (final e in reference.pauseForms(ayahId).entries)
            if (units.contains(e.key)) e.key: e.value,
        },
        openStart: m['openStart']! as bool,
        openEnd: m['openEnd']! as bool,
      );
      words += {for (final t in expected) t.word}.difference(targets).length;
      for (final v in verdicts) {
        if (v.type == RecitationErrorType.wrongLetter) {
          // The token's place (the verdict's may be a waqf form's copy: then
          // judged alone, as its group but a sākin qalqala's).
          final k = expected.indexWhere(
            (t) => t.unit == v.token.unit && t.symbol == v.token.symbol,
          );
          dump?.writeln(
            jsonEncode({
              'pack': pack,
              'mistake': targets.contains(v.token.word),
              'exp': v.token.symbol,
              'heard': v.observed,
              'llr': v.likelihoodRatio,
              // The threshold it passed: the letter's and its sound group's.
              'at':
                  th.letterError +
                  (th
                          .sounds[SoundGroup.of(
                            k < 0 ? [v.token] : expected,
                            k < 0 ? 0 : k,
                            RecitationErrorType.wrongLetter,
                            phoneticClassOf(v.observed!),
                          )]
                          ?.error ??
                      0),
            }),
          );
        }
        if (targets.contains(v.token.word)) {
          if (v.type == RecitationErrorType.wrongLetter) {
            caught['${v.token.symbol} → ${v.observed}'] =
                (caught['${v.token.symbol} → ${v.observed}'] ?? 0) + 1;
          }
          continue;
        }
        if (v.type == RecitationErrorType.correct ||
            v.type == RecitationErrorType.wrongLetter ||
            v.type == RecitationErrorType.uncertain) {
          if (quranPhoneticVocabulary.indexOf(v.token.symbol) > 0 &&
              !'َُِْ'.contains(v.token.symbol)) {
            letters++;
            seen[v.token.symbol] = (seen[v.token.symbol] ?? 0) + 1;
          }
        }
        if (v.type != RecitationErrorType.wrongLetter) continue;
        flagged++;
        (pairs['${v.token.symbol} → ${v.observed}'] ??= []).add(
          v.likelihoodRatio,
        );
      }
    }
  }
  await dump?.close();
  print(
    '$words correct words, $letters letters judged, '
    '$flagged heard as another letter',
  );
  final sorted = pairs.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  if (caught.isNotEmpty) {
    final c = caught.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    print(
      'on real mistakes, ${c.fold(0, (a, e) => a + e.value)} caught as '
      'another letter: ${c.take(15).map((e) => '${e.key} ${e.value}x').join(', ')}',
    );
  }
  for (final e in sorted.take(all ? sorted.length : 25)) {
    final llr = e.value..sort();
    final of = seen[e.key.split(' ').first] ?? 0;
    print(
      '${e.key}  ${e.value.length}x  '
      '(${(100 * e.value.length / (of == 0 ? 1 : of)).toStringAsFixed(1)}% '
      'of that letter; llr median ${llr[llr.length ~/ 2].toStringAsFixed(1)})',
    );
  }
}
