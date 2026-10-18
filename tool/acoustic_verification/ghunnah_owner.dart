// The owner's ghunnah session (20 ayahs, each said correctly and with the ghunnah
// cut short: model_work/artifacts/ghown_*): per take, how each candidate measure
// reads the highlighted doubled noon / meem, and how well it tells the two apart.
//   dart run tool/acoustic_verification/ghunnah_owner.dart <tag>
// Measures, on the token's frames and 3 either side, against the reciter's pace
// (frames per aligned sound in the ayah):
//   span   its aligned frames / pace
//   held   frames where the letter is ≥ 30% likely / pace
//   pieces the letter heard as separate sounds (1 = one continuous sound)
//   mass   the letter's summed probability / pace
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _art = 'tool/acoustic_verification/model_work/artifacts';

void main(List<String> args) {
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final meta = (jsonDecode(
    File('$_art/results/ghown_${args[0]}.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final bytes = File('$_art/results/ghown_${args[0]}.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  const verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(error: 3, pauseFrames: 4),
  );
  // item -> take -> measures (averaged over its highlighted tokens)
  final byItem = <String, Map<String, List<double>>>{};
  for (final m in meta) {
    final at = m['main']! as Map;
    final n = at['frames'] as int, off = at['offset'] as int;
    final frames = AcousticFrames(
      frames: n,
      classes: 43,
      logProbs: Float32List.sublistView(all, off, off + n * 43),
      frameDuration: const Duration(milliseconds: 40),
    );
    final ayahId = m['ayahId']! as int;
    final expected = reference.ayah(ayahId);
    final vs = verifier.verify(frames, expected, openStart: true, openEnd: true);
    final spans = [for (final v in vs) ?v.span];
    if (spans.length < 4) continue;
    final pace = (spans.last.end - spans.first.start + 1) / spans.length;
    final words = (m['ghunnahWords']! as List).cast<int>().toSet();
    final ms = <List<double>>[];
    for (final v in vs) {
      final t = v.token;
      if (!words.contains(t.word.wordIndex) || !t.geminate) continue;
      if (t.symbol != 'ن' && t.symbol != 'م') continue;
      final s = v.span;
      if (s == null) continue;
      var held = 0, pieces = 0;
      var mass = 0.0;
      var inside = false;
      for (var f = max(0, s.start - 3); f <= min(n - 1, s.end + 3); f++) {
        final p = exp(frames.at(f, t.token));
        mass += p;
        if (p >= 0.3) held++;
        var best = 0;
        for (var c = 1; c < 43; c++) {
          if (frames.at(f, c) > frames.at(f, best)) best = c;
        }
        final now = best == t.token;
        if (now && !inside) pieces++;
        inside = now;
      }
      ms.add([
        (s.end - s.start + 1) / pace,
        held / pace,
        pieces.toDouble(),
        mass / pace,
      ]);
    }
    if (ms.isEmpty) continue;
    final avg = [
      for (var j = 0; j < 4; j++) ms.map((x) => x[j]).reduce((a, b) => a + b) / ms.length,
    ];
    final name = m['name']! as String;
    (byItem[name.split('-')[0]] ??= {})[m['take']! as String] = avg;
  }
  const names = ['span', 'held', 'pieces', 'mass'];
  stdout.writeln('item   ${names.map((x) => 'correct/cut ${x.padRight(6)}').join('  ')}');
  for (final e in byItem.entries) {
    final c = e.value['correct'], u = e.value['cut'];
    if (c == null || u == null) continue;
    stdout.writeln(
      '${e.key.padRight(5)}  ${[for (var j = 0; j < 4; j++) '${c[j].toStringAsFixed(2).padLeft(5)}/${u[j].toStringAsFixed(2).padRight(5)}       '].join('  ')}',
    );
  }
  for (var j = 0; j < 4; j++) {
    var shorter = 0, pairs = 0;
    var auc = 0.0, cmp = 0;
    final cs = <double>[], us = <double>[];
    for (final e in byItem.values) {
      final c = e['correct'], u = e['cut'];
      if (c == null || u == null) continue;
      pairs++;
      if (u[j] < c[j]) shorter++;
      cs.add(c[j]);
      us.add(u[j]);
    }
    for (final a in us) {
      for (final b in cs) {
        auc += a < b ? 1 : (a == b ? 0.5 : 0);
        cmp++;
      }
    }
    stdout.writeln(
      '${names[j].padRight(6)}: cut take lower in $shorter of $pairs pairs; '
      'AUC (cut lower) ${(auc / max(1, cmp)).toStringAsFixed(2)}',
    );
  }
}
