// Can a ghunnah's length be read from a model's frames? On QDAT's expert labels
// for the ghunnah of «إِنَّكَ» (5:109, word 11): per clip, how long the doubled
// noon's sound lasts, as its frames in the verifier's alignment and as frames
// where «ن» stays likely, each relative to the reciter's pace (frames per sound
// over the phrase); then how well each separates ghunnah applied from missed.
//   dart run tool/acoustic_verification/ghunnah_length.dart <tag> [--pack qdath]
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _art = 'tool/acoustic_verification/model_work/artifacts';

void main(List<String> args) {
  final pi = args.indexOf('--pack');
  final pack = pi < 0 ? 'qdath' : args[pi + 1];
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
  final noon = phoneticClassOf('ن');
  const verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(error: 3, pauseFrames: 4),
  );
  final feats = <bool, List<(double, double)>>{true: [], false: []};
  for (final m in meta) {
    final l = labels[m['name']] as Map?;
    final v = l?['the_tight_noon'];
    if (v == null) continue;
    final expected = reference.words(5109, 7, 14);
    final at = m['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    final frames = AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: Float32List.sublistView(all, off, off + n * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
    final vs = verifier.verify(frames, expected);
    final spans = [
      for (final x in vs)
        if (x.span != null) x.span!,
    ];
    if (spans.length < 4) continue;
    final pace = (spans.last.end - spans.first.start + 1) / spans.length;
    final target = vs.where(
      (x) => x.token.word.wordIndex == 11 && x.token.geminate && x.span != null,
    );
    if (target.isEmpty) continue;
    final s = target.first.span!;
    // frames around the noon's span where «ن» is at least 30% likely
    var held = 0;
    for (var f = max(0, s.start - 3); f <= min(n - 1, s.end + 3); f++) {
      if (exp(frames.at(f, noon)) >= 0.3) held++;
    }
    feats[(v as num) >= 1]!.add(((s.end - s.start + 1) / pace, held / pace));
  }
  for (final (name, pick) in [
    ('aligned span', (double a, double b) => a),
    ('noon held   ', (double a, double b) => b),
  ]) {
    final ok = [for (final f in feats[true]!) pick(f.$1, f.$2)]..sort();
    final miss = [for (final f in feats[false]!) pick(f.$1, f.$2)]..sort();
    double q(List<double> x, double p) =>
        x[(x.length * p).floor().clamp(0, x.length - 1)];
    // AUC: chance a missed ghunnah is shorter than an applied one
    var auc = 0.0;
    for (final a in miss) {
      for (final b in ok) {
        auc += a < b ? 1 : (a == b ? 0.5 : 0);
      }
    }
    auc /= miss.length * ok.length;
    for (final t in [0.6, 0.7, 0.8, 0.9, 1.0, 1.2]) {
      String pct(List<double> x) =>
          '${(100 * x.where((v) => v > t).length / x.length).toStringAsFixed(1)}%';
      stdout.writeln(
        '  over $t: missed caught ${pct(miss)}, applied flagged ${pct(ok)}',
      );
    }
    stdout.writeln(
      '$name applied (${ok.length}): median ${q(ok, .5).toStringAsFixed(2)} '
      '[${q(ok, .1).toStringAsFixed(2)}–${q(ok, .9).toStringAsFixed(2)}]   '
      'missed (${miss.length}): median ${q(miss, .5).toStringAsFixed(2)} '
      '[${q(miss, .1).toStringAsFixed(2)}–${q(miss, .9).toStringAsFixed(2)}]   '
      'AUC ${auc.toStringAsFixed(2)}',
    );
  }
}
