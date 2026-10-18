// How sure a difference between models is: each measure with a 95% interval from
// resampling whole speakers (not words), and each model's difference from the first
// model's on the same resamples (paired).
//
//   dart run tool/acoustic_verification/bootstrap.dart v35ss=v35 r6g2e8=v36 r7g48=v36 ...
//       [--n 2000]
//
// A model's settings: v35 = v3.5 as the app ran it (vowel / letter / shadda 4, sukun /
// missing vowel 2); v36 = v3.6's strict ones (3 / 3, hidden nasal +2/+4). Measures:
//   mine      the user's correct words flagged (phone..phone7), speaker = session
//   amateur   RetaSy correct clips' words flagged, speaker = reciter
//             (model_work/retasy_reciters.py)
//   qmb       QuranMB held-out (quranmbh): clips whose mistake is marked on a wrong word;
//   qmb.fl    and its words heard right flagged; speaker = QuranMB speaker
//   ikh       Al-Ikhlas held-out (ikhlash) the same; speaker = reciter
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';
const _art = 'tool/acoustic_verification/model_work/artifacts';

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

AcousticThresholds _settings(String preset) {
  final v36 = preset == 'v36';
  final e = v36 ? 3.0 : 4.0, m = v36 ? 3.0 : 2.0;
  return AcousticThresholds(
    error: e,
    letterError: e,
    shaddaError: e,
    sukunError: m,
    missingVowelError: m,
    correct: -1,
    pauseFrames: 4,
    sounds: {
      ..._margins,
      if (v36)
        SoundGroup.hiddenNasal: const SoundMargins(error: 2, uncertain: 4),
    },
  );
}

late QuranPhoneticReference _reference;

/// Per speaker: [numerator, denominator] of a measure.
typedef Counts = Map<String, List<int>>;

void main(List<String> args) {
  final n = args.contains('--n')
      ? int.parse(args[args.indexOf('--n') + 1])
      : 2000;
  final models = [
    for (final a in args.where((a) => a.contains('=')))
      (tag: a.split('=')[0], th: _settings(a.split('=')[1])),
  ];
  _reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final reciters = (jsonDecode(
    File('$_art/retasy_case_reciters.json').readAsStringSync(),
  ) as List).cast<String>();

  // measure -> model -> speaker counts
  final all = <String, List<Counts>>{};
  for (final m in models) {
    final mine = <String, List<int>>{};
    for (final s in [
      'phone',
      'phone2',
      'phone3',
      'phone4',
      'phone6',
      'phone7',
    ]) {
      for (final c in _load('${s}_${m.tag}')) {
        _addClean(
          mine,
          '$s/${(c.m['name']! as String).split('_').first}',
          c,
          m.th,
        );
      }
    }
    final amateur = <String, List<int>>{};
    final retasy = _load('retasy_${m.tag}');
    for (var i = 0; i < retasy.length; i++) {
      if (retasy[i].m['category'] == 'retasy_correct') {
        _addClean(amateur, reciters[i], retasy[i], m.th);
      }
    }
    final (qmb, qmbFl) = _real(
      _load('quranmbh_${m.tag}'),
      m.th,
      (c) => (c.m['name']! as String).split('_')[1],
    );
    final (ikh, ikhFl) = _real(
      _load('ikhlash_${m.tag}'),
      m.th,
      (c) => '${c.m['reciter']}',
    );
    for (final (k, v) in [
      ('mine', mine),
      ('amateur', amateur),
      ('qmb', qmb),
      ('qmb.fl', qmbFl),
      ('ikh', ikh),
      ('ikh.fl', ikhFl),
    ]) {
      (all[k] ??= []).add(v);
    }
  }

  final rng = Random(1);
  stdout.writeln(
    'measure   model      value   95% interval     vs ${models.first.tag} (95% interval)',
  );
  for (final e in all.entries) {
    final speakers = e.value.first.keys.toList();
    double pct(Counts c, List<String> pick) {
      var a = 0, b = 0;
      for (final s in pick) {
        a += c[s]?[0] ?? 0;
        b += c[s]?[1] ?? 0;
      }
      return b == 0 ? 0 : a * 100 / b;
    }

    final draws = List.generate(e.value.length, (_) => <double>[]);
    final diffs = List.generate(e.value.length, (_) => <double>[]);
    for (var r = 0; r < n; r++) {
      final pick = [
        for (var i = 0; i < speakers.length; i++)
          speakers[rng.nextInt(speakers.length)],
      ];
      final base = pct(e.value.first, pick);
      for (var j = 0; j < e.value.length; j++) {
        final v = pct(e.value[j], pick);
        draws[j].add(v);
        diffs[j].add(v - base);
      }
    }
    String ci(List<double> x) {
      x.sort();
      return '${x[(x.length * 0.025).floor()].toStringAsFixed(1)}–'
          '${x[(x.length * 0.975).floor()].toStringAsFixed(1)}';
    }

    for (var j = 0; j < e.value.length; j++) {
      final v = pct(e.value[j], speakers);
      stdout.writeln(
        '${e.key.padRight(9)} ${models[j].tag.padRight(9)} '
        '${v.toStringAsFixed(1).padLeft(5)}   ${ci(draws[j]).padRight(15)}'
        '${j == 0 ? '  (${speakers.length} speakers)' : '  ${ci(diffs[j])}'}',
      );
    }
  }
}

/// A clean case's words, flagged ones counted, into its speaker's counts.
void _addClean(Counts out, String speaker, _Case c, AcousticThresholds th) {
  final k = out[speaker] ??= [0, 0];
  for (final kinds in c.judge(th).values) {
    k[1]++;
    if (kinds.any((t) => t.isError)) k[0]++;
  }
}

/// Real mistakes: per speaker, clips whose mistake is marked on a wrong word
/// / clips with mistakes; and words heard right flagged / words heard right.
(Counts, Counts) _real(
  List<_Case> cases,
  AcousticThresholds th,
  String Function(_Case) speaker,
) {
  final found = <String, List<int>>{}, flagged = <String, List<int>>{};
  for (final c in cases) {
    final s = speaker(c);
    final judged = c.judge(th);
    if (c.targets.isNotEmpty) {
      final k = found[s] ??= [0, 0];
      k[1]++;
      if (c.targets.any((w) => judged[w]?.any((t) => t.isError) ?? false))
        k[0]++;
    }
    final k = flagged[s] ??= [0, 0];
    for (final e in judged.entries) {
      if (c.targets.contains(e.key)) continue;
      k[1]++;
      if (e.value.any((t) => t.isError)) k[0]++;
    }
  }
  return (found, flagged);
}

class _Case {
  _Case(this.m, this.frames, this.expected, this.pauses, this.targets);
  final Map<String, Object?> m;
  final AcousticFrames frames;
  final List<PhoneticToken> expected;
  final Map<int, PauseForms> pauses;
  final Set<WordRef> targets;

  Map<WordRef, Set<RecitationErrorType>> judge(AcousticThresholds th) {
    final out = <WordRef, Set<RecitationErrorType>>{};
    for (final v in QuranAcousticVerifier(thresholds: th).verify(
      frames,
      expected,
      pauses: pauses,
      openStart: m['openStart']! as bool,
      openEnd: m['openEnd']! as bool,
    )) {
      (out[v.token.word] ??= {}).add(v.type);
    }
    return out;
  }
}

List<_Case> _load(String name) {
  final json = File('$_results/$name.json');
  if (!json.existsSync()) {
    stderr.writeln('missing $name');
    return const [];
  }
  final raw = jsonDecode(json.readAsStringSync());
  final meta = (raw is List ? raw : (raw as Map)['cases'] as List)
      .cast<Map<String, Object?>>();
  final bytes = File('$_results/$name.f32').readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  return [
    for (final m in meta)
      () {
        final ayahId = m['ayahId']! as int;
        final expected = _reference.words(
          ayahId,
          m['firstWord']! as int,
          m['lastWord']! as int,
        );
        final units = {for (final t in expected) t.unit};
        final at = m['main']! as Map;
        final n = at['frames'] as int, off = at['offset'] as int;
        return _Case(
          m,
          AcousticFrames(
            frames: n,
            classes: 43,
            logProbs: Float32List.sublistView(all, off, off + n * 43),
            frameDuration: const Duration(milliseconds: 40),
          ),
          expected,
          {
            for (final e in _reference.pauseForms(ayahId).entries)
              if (units.contains(e.key)) e.key: e.value,
          },
          {
            for (final w in (m['targetWords']! as List).cast<int>())
              (ayahId: ayahId, wordIndex: w),
          },
        );
      }(),
  ];
}
