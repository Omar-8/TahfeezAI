import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

QuranPhoneticReference? _reference;

QuranPhoneticReference loadTestReference() =>
    _reference ??= QuranPhoneticReference.fromJson(
      jsonDecode(
        File('assets/quran/recitation/phonetic_reference_hafs.json')
            .readAsStringSync(),
      ) as Map<String, Object?>,
    );

/// Frames that clearly hear [tokens], each for two frames then a blank —
/// with [pauseFrames] of silence after the first [pauseAfter] tokens.
AcousticFrames clearFrames(
  List<int> tokens, {
  double floor = -20,
  int? pauseAfter,
  int pauseFrames = 10,
}) {
  final classes = quranPhoneticVocabulary.length;
  final pause = pauseAfter == null ? 0 : pauseFrames;
  final frames = tokens.length * 3 + 2 + pause;
  final lp = Float32List(frames * classes)
    ..fillRange(0, frames * classes, floor);
  var f = 0;
  void emit(int c) {
    for (var k = 0; k < classes; k++) {
      lp[f * classes + k] = k == c ? 0 : floor;
    }
    f++;
  }

  emit(ctcBlank);
  for (var i = 0; i < tokens.length; i++) {
    if (i == pauseAfter) {
      for (var p = 0; p < pause; p++) {
        emit(ctcBlank);
      }
    }
    final t = tokens[i];
    emit(t);
    emit(t);
    emit(ctcBlank);
  }
  emit(ctcBlank);
  return AcousticFrames(
    frames: frames,
    classes: classes,
    logProbs: lp,
    frameDuration: const Duration(milliseconds: 40),
  );
}
