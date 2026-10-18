// Every sound's verdict (with its likelihood ratio) in some ayahs of a
// clip, as the app's ayah check judges it:
//   dart run tool/acoustic_verification/dump_verdicts.dart <pack> <tag> \
//     <ayahId>...
// (results/<pack>_<tag>.json/.f32, the clip's whole range aligned first).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

void main(List<String> args) {
  final pack = args[0], tag = args[1];
  final ayahs = args
      .sublist(2)
      .where((a) => !a.startsWith('--'))
      .map(int.parse)
      .toList();
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  // The app's (AcousticVerificationController.calibratedThresholds).
  // --v36: v3.6's strict ones (3 / 3).
  final v36 = args.contains('--v36');
  final verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: v36 ? 3 : 4,
      letterError: v36 ? 3 : 4,
      shaddaError: v36 ? 3 : 4,
      sukunError: v36 ? 3 : 2,
      missingVowelError: v36 ? 3 : 2,
      correct: -1,
      pauseFrames: 4,
      sounds: {
        SoundGroup.shadda: SoundMargins(uncertain: 2),
        SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
        SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
        SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
        SoundGroup.nasal: SoundMargins(uncertain: 2),
        SoundGroup.throat: SoundMargins(uncertain: 2),
        SoundGroup.wordFinalVowel: SoundMargins(error: -1),
        SoundGroup.stopInFlow: SoundMargins(error: 1),
      },
    ),
  );
  final meta = (jsonDecode(
    File('$_results/${pack}_$tag.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>().first;
  final b = File('$_results/${pack}_$tag.f32').readAsBytesSync();
  final all = b.buffer.asFloat32List(0, b.length ~/ 4);
  final at = meta['main']! as Map;
  final n = at['frames'] as int, off = at['offset'] as int;
  final frames = AcousticFrames(
    frames: n,
    classes: 43,
    logProbs: Float32List.sublistView(all, off, off + n * 43),
    frameDuration: const Duration(milliseconds: 40),
  );
  // Ayah by ayah, each against the whole clip, as one ayah's check would
  // see a run of several.
  for (final ayahId in ayahs) {
    final expected = reference.words(ayahId, 0, 1 << 20);
    final vs = verifier.verify(
      frames,
      expected,
      pauses: reference.pauseForms(ayahId),
      openStart: true,
      openEnd: true,
    );
    stdout.writeln('== $ayahId');
    for (final v in vs) {
      stdout.writeln(
        '  w${v.token.word.wordIndex + 1} ${v.token.symbol} '
        '${v.type.name} llr ${v.likelihoodRatio.toStringAsFixed(2)} '
        '${v.observed ?? ''} ${v.span == null ? '' : '${v.span!.start}..${v.span!.end}'}',
      );
    }
  }
}
