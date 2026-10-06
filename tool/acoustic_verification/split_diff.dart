// Which calibration mistakes the split forms (stopping inside a unit) hide:
// each spliced case judged with and without them.
//   dart run tool/acoustic_verification/split_diff.dart <data.json> <data.f32>
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

void main(List<String> args) {
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final meta = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  final bytes = File(args[1]).readAsBytesSync();
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
    ),
  );
  for (final m in meta) {
    if (m['kind'] != 'spliced') continue;
    final ayahId = m['ayahId']! as int;
    final expected = reference.words(
      ayahId,
      m['firstWord']! as int,
      m['lastWord']! as int,
    );
    final units = {for (final t in expected) t.unit};
    final at = m['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    final frames = AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: Float32List.sublistView(all, off, off + n * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
    final targets = {
      for (final w in (m['targetWords']! as List).cast<int>())
        (ayahId: ayahId, wordIndex: w),
    };
    bool found(bool splits) {
      final pauses = {
        for (final e in reference.pauseForms(ayahId).entries)
          if (units.contains(e.key))
            e.key: splits
                ? e.value
                : PauseForms(
                    waqf: e.value.waqf,
                    ibtida: e.value.ibtida,
                    wasl: e.value.wasl,
                    joined: e.value.joined,
                  ),
      };
      return verifier
          .verify(
            frames,
            expected,
            pauses: pauses,
            openStart: m['openStart']! as bool,
            openEnd: m['openEnd']! as bool,
          )
          .any((v) => targets.contains(v.token.word) && v.type.isError);
    }

    final without = found(false), with_ = found(true);
    if (without != with_) {
      stdout.writeln(
        '${m['category']} ${m['name']} $ayahId '
        'words ${m['targetWords']}: without splits $without, with $with_',
      );
    }
  }
}
