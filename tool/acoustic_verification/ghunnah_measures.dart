// Ghunnah measures (as ghunnah_owner.dart) for the owner's labelled everyday
// ghunnahs (model_work/artifacts/ghunnah_listen_labelled.json) and his deliberate
// pairs (ghown): per item its label and held / pace, pieces, span / pace, for
// choosing a check that catches deliberate cuts without firing on held ones.
//   dart run tool/acoustic_verification/ghunnah_measures.dart <tag>
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _art = 'tool/acoustic_verification/model_work/artifacts';
late QuranPhoneticReference _ref;

List<double>? _measure(Map<String, Object?> m, Float32List all, int word) {
  final at = m['main']! as Map;
  final n = at['frames'] as int, off = at['offset'] as int;
  final frames = AcousticFrames(
    frames: n,
    classes: 43,
    logProbs: Float32List.sublistView(all, off, off + n * 43),
    frameDuration: const Duration(milliseconds: 40),
  );
  final expected = _ref.words(
    m['ayahId']! as int,
    m['firstWord']! as int,
    m['lastWord']! as int,
  );
  const v = QuranAcousticVerifier(
    thresholds: AcousticThresholds(error: 3, pauseFrames: 4),
  );
  final vs = v.verify(frames, expected, openStart: true, openEnd: true);
  final spans = [for (final x in vs) ?x.span];
  if (spans.length < 4) return null;
  final pace = (spans.last.end - spans.first.start + 1) / spans.length;
  List<double>? best;
  for (final x in vs) {
    final t = x.token;
    if (t.word.wordIndex != word || !t.geminate) continue;
    if (t.symbol != 'ن' && t.symbol != 'م') continue;
    final s = x.span;
    if (s == null) continue;
    var held = 0, pieces = 0;
    var inside = false;
    for (var f = max(0, s.start - 3); f <= min(n - 1, s.end + 3); f++) {
      if (exp(frames.at(f, t.token)) >= 0.3) held++;
      var b = 0;
      for (var c = 1; c < 43; c++) {
        if (frames.at(f, c) > frames.at(f, b)) b = c;
      }
      final now = b == t.token;
      if (now && !inside) pieces++;
      inside = now;
    }
    final r = [held / pace, pieces.toDouble(), (s.end - s.start + 1) / pace];
    if (best == null || r[0] > best[0]) best = r;
  }
  return best;
}

void main(List<String> args) {
  final tag = args.first;
  _ref = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  (List<Map<String, Object?>>, Float32List) load(String pack) {
    final meta = (jsonDecode(
      File('$_art/results/${pack}_$tag.json').readAsStringSync(),
    ) as List).cast<Map<String, Object?>>();
    final b = File('$_art/results/${pack}_$tag.f32').readAsBytesSync();
    return (meta, b.buffer.asFloat32List(0, b.length ~/ 4));
  }

  final rows = <(String, String, List<double>)>[];
  final own = load('ghown');
  for (final m in own.$1) {
    final r = _measure(m, own.$2, (m['ghunnahWords']! as List).first as int);
    if (r != null) {
      rows.add(('session', m['take'] == 'correct' ? 'held' : 'cut', r));
    }
  }
  final labelled = (jsonDecode(
    File('$_art/ghunnah_listen_labelled.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final cache = <String, (List<Map<String, Object?>>, Float32List)>{};
  for (final x in labelled) {
    final p = cache[x['pack']! as String] ??= load(x['pack']! as String);
    final r = _measure(p.$1[x['clip']! as int], p.$2, x['word']! as int);
    if (r == null) continue;
    final l = x['label'];
    rows.add((
      'everyday',
      l == 'correct'
          ? 'held'
          : l == 'mistake'
          ? 'cut'
          : 'unsure',
      r,
    ));
  }
  for (final g in ['session', 'everyday']) {
    for (final l in ['held', 'cut', 'unsure']) {
      final v = [
        for (final r in rows)
          if (r.$1 == g && r.$2 == l) r.$3,
      ];
      if (v.isEmpty) continue;
      final held = [for (final x in v) x[0]]..sort();
      stdout.writeln(
        '$g $l (${v.length}): held/pace ${held.map((x) => x.toStringAsFixed(2)).join(' ')}',
      );
      stdout.writeln(
        '   pieces ${[for (final x in v) x[1].toInt()].join(' ')}',
      );
    }
  }
  for (final t in [1.2, 1.5, 1.8, 2.0, 2.2, 2.5]) {
    for (final needPieces in [false, true]) {
      bool flag(List<double> x) => x[0] > t && (!needPieces || x[1] >= 2);
      String rate(String g, String l) {
        final v = [
          for (final r in rows)
            if (r.$1 == g && r.$2 == l) r.$3,
        ];
        return '${v.where(flag).length}/${v.length}';
      }

      stdout.writeln(
        'held > $t${needPieces ? ' and 2+ pieces' : ''}: session cut ${rate('session', 'cut')}, '
        'session held ${rate('session', 'held')}; everyday held ${rate('everyday', 'held')}, '
        'everyday cut ${rate('everyday', 'cut')}',
      );
    }
  }
}
