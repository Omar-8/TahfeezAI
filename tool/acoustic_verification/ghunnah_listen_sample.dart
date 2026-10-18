// A blind listening sample of the owner's ghunnahs from his phone sessions
// (phone..phone9): doubled noons / meems the ghunnah check (ghunnahHold 1.0, v3.6)
// flags and ones it does not, with each one's time in its clip, for judging by ear.
//   dart run tool/acoustic_verification/ghunnah_listen_sample.dart <out.json> [--flagged 35 --plain 15]
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _r = 'tool/acoustic_verification/model_work/artifacts/results';

void main(List<String> args) {
  int opt(String n, int d) =>
      args.contains('--$n') ? int.parse(args[args.indexOf('--$n') + 1]) : d;
  final ref = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final data = jsonDecode(
    File('assets/quran/quran_dataset.json').readAsStringSync(),
  ) as Map;
  final words = <int, List<String>>{};
  for (final w in (data['ayahWords'] as List).cast<Map>()) {
    (words[w['ayahId'] as int] ??= []).add(w['text'] as String);
  }
  const v = QuranAcousticVerifier(
    thresholds: AcousticThresholds(error: 3, pauseFrames: 4, ghunnahHold: 1.0),
  );
  final flagged = <Map<String, Object?>>[], plain = <Map<String, Object?>>[];
  for (final p in [
    'phone',
    'phone2',
    'phone3',
    'phone4',
    'phone6',
    'phone7',
    'phone8',
    'phone9', //
  ]) {
    final f = File('$_r/${p}_r6g2e8.json');
    if (!f.existsSync()) continue;
    final meta = (jsonDecode(f.readAsStringSync()) as List)
        .cast<Map<String, Object?>>();
    final b = File('$_r/${p}_r6g2e8.f32').readAsBytesSync();
    final all = b.buffer.asFloat32List(0, b.length ~/ 4);
    for (var i = 0; i < meta.length; i++) {
      final m = meta[i];
      final at = m['main']! as Map;
      final n = at['frames'] as int, off = at['offset'] as int;
      final ayahId = m['ayahId']! as int;
      final expected = ref.words(
        ayahId,
        m['firstWord']! as int,
        m['lastWord']! as int,
      );
      final vs = v.verify(
        AcousticFrames(
          frames: n,
          classes: 43,
          logProbs: Float32List.sublistView(all, off, off + n * 43),
          frameDuration: const Duration(milliseconds: 40),
        ),
        expected,
        openStart: m['openStart']! as bool,
        openEnd: m['openEnd']! as bool,
      );
      for (final x in vs) {
        final t = x.token;
        if (!t.geminate || (t.symbol != 'ن' && t.symbol != 'م')) continue;
        final s = x.span;
        if (s == null) continue;
        final item = {
          'pack': p,
          'clip': i,
          'ayahId': ayahId,
          'words': words[ayahId],
          'word': t.word.wordIndex,
          'start': max(0, s.start - 4) * 0.04,
          'end': (s.end + 5) * 0.04,
          'flagged': x.type == RecitationErrorType.ghunnahMissing,
        };
        (item['flagged']! as bool ? flagged : plain).add(item);
      }
    }
  }
  final rng = Random(3);
  flagged.shuffle(rng);
  plain.shuffle(rng);
  final items = [
    ...flagged.take(opt('flagged', 35)),
    ...plain.take(opt('plain', 15)),
  ]..shuffle(rng);
  for (var k = 0; k < items.length; k++) {
    items[k]['id'] = 'h${k + 1}';
  }
  File(args[0]).writeAsStringSync(jsonEncode(items));
  stdout.writeln(
    'flagged ${flagged.length}, not ${plain.length}; sampled ${items.length}',
  );
}
