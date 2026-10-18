// A blind listening sample: words of the held-out Juz 30 reciters (juz30h) that
// one model flags and the other does not, for a person to judge by ear.
//
//   dart run tool/acoustic_verification/listen_sample.dart <tagA> <tagB> <out.json>
//       [--a 50 --b 20 --both 10 --seed 1]
//
// tagA at v3.6's strict settings, tagB at v3.5's (as bootstrap.dart). Groups: "a" =
// flagged by A only, "b" = by B only, "both". Written per item: the clip, the ayah's
// words, the word, and its time in the clip (A's alignment, 40 ms frames).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

const _margins = {
  SoundGroup.shadda: SoundMargins(uncertain: 2),
  SoundGroup.reducedVowel: SoundMargins(error: 1, uncertain: 2),
  SoundGroup.finalVowel: SoundMargins(error: 2, uncertain: 2),
  SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
  SoundGroup.nasal: SoundMargins(uncertain: 2),
  SoundGroup.throat: SoundMargins(uncertain: 2),
  SoundGroup.wordFinalVowel: SoundMargins(error: -1),
  SoundGroup.stopInFlow: SoundMargins(error: 1),
};

AcousticThresholds _th(bool v36) => AcousticThresholds(
  error: v36 ? 3 : 4,
  letterError: v36 ? 3 : 4,
  shaddaError: v36 ? 3 : 4,
  sukunError: v36 ? 3 : 2,
  missingVowelError: v36 ? 3 : 2,
  correct: -1,
  pauseFrames: 4,
  sounds: {
    ..._margins,
    if (v36) SoundGroup.hiddenNasal: const SoundMargins(error: 2, uncertain: 4),
  },
);

void main(List<String> args) {
  int opt(String n, int d) =>
      args.contains('--$n') ? int.parse(args[args.indexOf('--$n') + 1]) : d;
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final data = jsonDecode(
    File('assets/quran/quran_dataset.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final words = <int, List<String>>{};
  for (final w in (data['ayahWords']! as List).cast<Map<String, Object?>>()) {
    (words[w['ayahId']! as int] ??= []).add(w['text']! as String);
  }

  // per model: case -> (flagged words, word -> (first, last) frame)
  List<(Set<int>, Map<int, (int, int)>)> judge(String tag, bool v36) {
    final meta = (jsonDecode(
      File('$_results/juz30h_$tag.json').readAsStringSync(),
    ) as List).cast<Map<String, Object?>>();
    final bytes = File('$_results/juz30h_$tag.f32').readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    final verifier = QuranAcousticVerifier(thresholds: _th(v36));
    return [
      for (final m in meta)
        () {
          final ayahId = m['ayahId']! as int;
          final expected = reference.words(
            ayahId,
            m['firstWord']! as int,
            m['lastWord']! as int,
          );
          final units = {for (final t in expected) t.unit};
          final at = m['main']! as Map;
          final n = at['frames'] as int, off = at['offset'] as int;
          final flagged = <int>{};
          final spans = <int, (int, int)>{};
          for (final v in verifier.verify(
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
          )) {
            final w = v.token.word.wordIndex;
            if (v.type.isError) flagged.add(w);
            final s = v.span;
            if (s != null) {
              final old = spans[w];
              spans[w] = old == null
                  ? (s.start, s.end)
                  : (min(old.$1, s.start), max(old.$2, s.end));
            }
          }
          return (flagged, spans);
        }(),
    ];
  }

  final a = judge(args[0], true), b = judge(args[1], false);
  final cases = (jsonDecode(
    File('tool/acoustic_verification/model_work/artifacts/juz30h_cases.json')
        .readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final pools = <String, List<(int, int)>>{'a': [], 'b': [], 'both': []};
  for (var i = 0; i < cases.length; i++) {
    for (final w in {...a[i].$1, ...b[i].$1}) {
      final inA = a[i].$1.contains(w), inB = b[i].$1.contains(w);
      final span = a[i].$2[w] ?? b[i].$2[w];
      if (span == null) continue; // a skipped word: nothing to play
      pools[inA && inB
              ? 'both'
              : inA
              ? 'a'
              : 'b']!
          .add((i, w));
    }
  }
  final rng = Random(opt('seed', 1));
  final items = <Map<String, Object?>>[];
  for (final (g, want) in [
    ('a', opt('a', 50)),
    ('b', opt('b', 20)),
    ('both', opt('both', 10)),
  ]) {
    final pool = pools[g]!..shuffle(rng);
    // at most two words per clip, so the sample spreads over clips and reciters
    final perClip = <int, int>{};
    for (final (i, w) in pool) {
      if (items.where((x) => x['group'] == g).length >= want) break;
      if ((perClip[i] ?? 0) >= 2) continue;
      perClip[i] = (perClip[i] ?? 0) + 1;
      final c = cases[i];
      final span = a[i].$2[w] ?? b[i].$2[w]!;
      items.add({
        'group': g,
        'clip': i,
        'reciter': c['reciter'],
        'ayahId': c['ayahId'],
        'words': words[c['ayahId']],
        'word': w,
        'start': span.$1 * 0.04,
        'end': (span.$2 + 1) * 0.04,
      });
    }
  }
  items.shuffle(rng);
  for (var k = 0; k < items.length; k++) {
    items[k]['id'] = 'w${k + 1}';
  }
  File(args[2]).writeAsStringSync(jsonEncode(items));
  stdout.writeln(
    'pools: a ${pools['a']!.length}, b ${pools['b']!.length}, both '
    '${pools['both']!.length}; sampled ${items.length} from '
    '${{for (final x in items) x['clip']}.length} clips',
  );
}
