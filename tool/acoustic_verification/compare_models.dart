// The app's verdicts per word for several models on the same clips:
//   dart run tool/acoustic_verification/compare_models.dart <pack> <tag>...
// (results/<pack>_<tag>.json/.f32). Lists, per clip, each word any model
// flags (M = mistake, ? = uncertain, . = fine), and how often the models
// agree.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

void main(List<String> args) {
  final pack = args.first, tags = args.sublist(1);
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
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
  final runs = [
    for (final t in tags)
      (
        (jsonDecode(
          File('$_results/${pack}_$t.json').readAsStringSync(),
        ) as List).cast<Map<String, Object?>>(),
        () {
          final b = File('$_results/${pack}_$t.f32').readAsBytesSync();
          return b.buffer.asFloat32List(0, b.length ~/ 4);
        }(),
      ),
  ];
  var words = 0, same = 0;
  final mistakes = List.filled(tags.length, 0);
  for (var i = 0; i < runs.first.$1.length; i++) {
    final m = runs.first.$1[i];
    final ayahId = m['ayahId']! as int;
    final expected = reference.words(
      ayahId,
      m['firstWord']! as int,
      m['lastWord']! as int,
    );
    final units = {for (final t in expected) t.unit};
    final per = <Map<WordRef, String>>[];
    for (final (meta, all) in runs) {
      final at = meta[i]['main']! as Map;
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
          for (final e in reference.pauseForms(ayahId).entries)
            if (units.contains(e.key)) e.key: e.value,
        },
      );
      final out = <WordRef, String>{};
      for (final v in vs) {
        final w = v.token.word;
        final mark = v.type.isError
            ? 'M ${v.token.symbol}→${v.observed}'
            : v.type == RecitationErrorType.uncertain
            ? '? ${v.token.symbol}'
            : '.';
        final had = out[w];
        if (had == null ||
            had == '.' ||
            (had.startsWith('?') && mark.startsWith('M'))) {
          out[w] = mark;
        }
      }
      per.add(out);
    }
    final allWords = {for (final p in per) ...p.keys}.toList()
      ..sort((a, b) => a.wordIndex.compareTo(b.wordIndex));
    final lines = <String>[];
    for (final w in allWords) {
      words++;
      final marks = [for (final p in per) p[w] ?? '.'];
      final kinds = {for (final k in marks) k[0]};
      if (kinds.length == 1) same++;
      for (var t = 0; t < tags.length; t++) {
        if (marks[t].startsWith('M')) mistakes[t]++;
      }
      if (marks.any((k) => k != '.')) {
        lines.add(
          '  ${w.ayahId ~/ 1000}:${w.ayahId % 1000}:${w.wordIndex + 1}  '
          '${[for (var t = 0; t < tags.length; t++) '${tags[t]}: ${marks[t]}'].join('   ')}',
        );
      }
    }
    if (lines.isNotEmpty) {
      stdout.writeln('${m['name']}');
      lines.forEach(stdout.writeln);
    }
  }
  stdout.writeln(
    'words $words: same verdict in all ${(100 * same / words).toStringAsFixed(1)}%; '
    'mistakes: ${[for (var t = 0; t < tags.length; t++) '${tags[t]} ${mistakes[t]}'].join(', ')}',
  );
}
