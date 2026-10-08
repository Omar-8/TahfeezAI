// A phone session's qalqala letters, as the app judges them: the session's
// frames (bench_run.py --pack <pack>, a stateful streaming run over the whole
// recording) cut per ayah where the tracker placed it (frames, 40 ms, with
// the app's 1 s margin), verified with the app's thresholds, and the echo's
// margin printed per letter ("without" more likely by >= 1: a mistake).
//   dart run tool/acoustic_verification/session_qalqala.dart <tag> \
//     <ayahId:firstWord:lastWord:fromFrame:toFrame> ...
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
    File('$_results/${args[0]}.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final at = meta.single['main']! as Map;
  final n = at['frames'] as int, off = at['offset'] as int;
  final bytes = File('$_results/${args[0]}.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(off * 4, n * 43);
  // The app's (AcousticVerificationController.calibratedThresholds, with
  // the streaming model's margins: minor mistakes 2, qalqala 1).
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
  // Every word of the Quran, in order.
  final order =
      [
        for (final w
            in (jsonDecode(
                  File('assets/quran/quran_dataset.json').readAsStringSync(),
                ) as Map)['ayahWords']
                as List)
          (ayahId: w['ayahId'] as int, wordIndex: w['wordIndex'] as int),
      ]..sort(
        (a, b) => a.ayahId != b.ayahId
            ? a.ayahId - b.ayahId
            : a.wordIndex - b.wordIndex,
      );
  final locate = !args.contains('--placed');
  for (final spec in args.skip(1).where((a) => !a.startsWith('--'))) {
    final [ayah, firstWord, lastWord, from, to] = spec
        .split(':')
        .map(int.parse)
        .toList();
    final f0 = math.max(0, from - 25), f1 = math.min(n, to + 26);
    final frames = AcousticFrames(
      frames: f1 - f0,
      classes: 43,
      logProbs: Float32List.sublistView(all, f0 * 43, f1 * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
    // As the app: located among the words around the piece's own (3 before,
    // 6 after); failing that, judged as the words placed.
    final targets = [
      for (var w = firstWord; w <= lastWord; w++) (ayahId: ayah, wordIndex: w),
    ];
    final i0 = order.indexOf(targets.first), i1 = order.indexOf(targets.last);
    final span = reference.span(
      order.sublist(math.max(0, i0 - 3), math.min(order.length, i1 + 7)),
    );
    final placed = [
      for (final t in span.tokens)
        if (targets.contains(t.word)) t.unit,
    ];
    final located = locate ? verifier.locate(frames, span.tokens) : null;
    final (lo, hi) =
        located ?? (placed.reduce(math.min), placed.reduce(math.max));
    stdout.writeln(
      '-- $spec: ${located == null ? 'placed' : 'located'} units $lo..$hi '
      '(placed ${placed.reduce(math.min)}..${placed.reduce(math.max)})',
    );
    final expected = [
      for (final t in span.tokens)
        if (t.unit >= lo && t.unit <= hi) t,
    ];
    final vs = verifier.verify(
      frames,
      expected,
      pauses: {
        for (final MapEntry(:key, :value) in span.pauses.entries)
          if (key >= lo && key <= hi) key: value,
      },
      openStart: firstWord != 0,
    );
    for (final v in vs) {
      final w = v.token.word;
      final echo = v.token.symbol == 'ڇ';
      final letter =
          v.type == RecitationErrorType.qalqalaMissing ||
          (v.type.isError || v.type == RecitationErrorType.uncertain);
      if ((!echo && !letter) || !targets.contains(w)) continue;
      stdout.writeln(
        '${w.ayahId ~/ 1000}:${w.ayahId % 1000}:${w.wordIndex + 1} '
        '${echo ? 'echo' : v.token.symbol} ${v.type.name} '
        '${v.likelihoodRatio.toStringAsFixed(2)}',
      );
    }
  }
}
