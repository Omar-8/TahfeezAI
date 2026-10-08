// Al-Ikhlas learners (model_work/ikhlas_pack.py): per labelled-mistake word, what
// the app's ayah check said about it, against the same word in correct clips:
//   dart run tool/acoustic_verification/ikhlas_words.dart <tag>
// Counts, per word, the verdict types on its sounds (mistake clips vs correct).
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
  final meta = (jsonDecode(
    File('$_results/ikhlas_${args[0]}.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final bytes = File('$_results/ikhlas_${args[0]}.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  const verifier = QuranAcousticVerifier(
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
      },
    ),
  );
  // (ayah:word, mistake clip?) -> verdict type -> clips
  final counts = <String, Map<String, int>>{};
  final clips = <String, int>{};
  for (final m in meta) {
    final ayahId = m['ayahId']! as int;
    final expected = reference.words(ayahId, 0, m['lastWord']! as int);
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
      pauses: reference.pauseForms(ayahId),
    );
    final mistake = m['set'] == 'mistake';
    final targets = (m['targetWords']! as List).cast<int>();
    final words = mistake
        ? targets
        : <int>{
            for (final x in meta)
              if (x['set'] == 'mistake' && x['ayahId'] == ayahId)
                ...(x['targetWords']! as List).cast<int>(),
          }.toList();
    for (final w in words) {
      final key =
          '${ayahId % 1000}:${w + 1} ${mistake ? 'mistake' : 'correct'}';
      clips[key] = (clips[key] ?? 0) + 1;
      final kinds = {
        for (final v in vs)
          if (v.token.word.wordIndex == w &&
              (v.type.isError || v.type == RecitationErrorType.uncertain))
            '${v.type.name}${v.observed == null ? '' : ':${v.observed}'}',
      };
      final row = counts[key] ??= {};
      for (final k in kinds.isEmpty ? {'fine'} : kinds) {
        row[k] = (row[k] ?? 0) + 1;
      }
    }
  }
  for (final key in clips.keys.toList()..sort()) {
    final row = counts[key]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln(
      '$key (${clips[key]}): '
      '${row.take(6).map((e) => '${e.key} ${(100 * e.value / clips[key]!).round()}%').join(', ')}',
    );
  }
}
