// The app pipeline's verdicts on replayed sessions (session_replay_test.dart)
// against the same words judged in per-ayah clips (the phone packs), on
// correct recitation: which flags the pipeline adds (its context: how it
// cuts and places the audio) and which the model gives anyway.
//   dart run tool/acoustic_verification/replay/replay_compare.dart <tag> \
//     <replay dir> <pack>...
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
  // The app's (streaming model's) thresholds.
  const verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: 4,
      letterError: 4,
      shaddaError: 4,
      sukunError: 2,
      missingVowelError: 2,
      correct: -1,
      pauseFrames: 4,
      qalqalaError: 1,
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
  // session -> word "ayahId:index" -> clip verdict (first error or type)
  final clip = <String, Map<String, String>>{};
  for (final pack in args.skip(2)) {
    final meta = (jsonDecode(
      File('$_results/${pack}_$tag.json').readAsStringSync(),
    ) as List).cast<Map<String, Object?>>();
    final bytes = File('$_results/${pack}_$tag.f32').readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    for (final m in meta) {
      final name = m['name']! as String;
      final session = name.substring(0, name.lastIndexOf('_'));
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
      );
      final words = clip.putIfAbsent(session, () => {});
      for (var w = m['firstWord']! as int; w <= (m['lastWord']! as int); w++) {
        words['$ayahId:$w'] = 'correct';
      }
      for (final e in verifier.errors(vs, const Duration(milliseconds: 40))) {
        final key = '${e.word.ayahId}:${e.word.wordIndex}';
        if (e.type.isError) {
          words[key] = '$e';
        } else if (words[key] == 'correct') {
          words[key] = 'uncertain';
        }
      }
    }
  }
  var judged = 0, pipeline = 0, model = 0, both = 0;
  final added = <String>[], removed = <String>[];
  for (final f in Directory(args[1]).listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final d = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final session = d['session']! as String;
    final words = clip[session] ?? const {};
    for (final w in (d['words']! as List).cast<Map<String, Object?>>()) {
      final key = w['word']! as String;
      final c = words[key];
      if (c == null) continue; // not an ayah judged correct
      judged++;
      final type = w['type']! as String;
      final p = type != 'correct' && type != 'uncertain';
      final m = c != 'correct' && c != 'uncertain';
      if (p) pipeline++;
      if (m) model++;
      if (p && m) both++;
      final errors = (w['errors']! as List).cast<String>();
      if (p && !m) {
        added.add(
          '${session.substring(0, 12)} $key ${errors.firstOrNull ?? type}',
        );
      }
      if (m && !p) removed.add('${session.substring(0, 12)} $key $c');
    }
  }
  String pct(int x) => '${(100 * x / judged).toStringAsFixed(1)}%';
  stdout.writeln(
    'words $judged: flagged by the pipeline ${pct(pipeline)}, in clips '
    '${pct(model)}, both ${pct(both)}',
  );
  stdout.writeln('\nonly the pipeline (${added.length}):');
  added.forEach(stdout.writeln);
  stdout.writeln('\nonly the clips (${removed.length}):');
  removed.forEach(stdout.writeln);
}
