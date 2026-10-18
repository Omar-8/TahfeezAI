// Tunes the verifier's per-sound margins (AcousticThresholds.sounds) and the
// pause length, scoring each setting on every test set at once:
//
//   dart run tool/acoustic_verification/tune_sound_margins.dart <tag>
//       [--mine phone,phone2,...] [--sweep] [--margins group=error/uncertain,...]
//       [--pause N] [--correct C] [--clips]
//       [--error E (vowel, letter, shadda)] [--minor M (sukun, missing)]
//       [--madd S] (a long madd's share held)
//
// <tag>: the model outputs' tag (results/<set>_<tag>.json/.f32; the
// calibration sets as calib_<tag>, calibdeg_<tag>). Measured, per setting:
//   mine      a reciter's own correct recitation (local only): words
//             flagged / only uncertain
//   amateur   RetaSy clips judged correct: flagged / only uncertain
//   amat.err  RetaSy clips judged incorrect: flagged / flagged or uncertain
//             (a noisy measure of real mistakes still noticed)
//   calib     spliced real mistakes found with the right type, and clean
//             professional recitation flagged / uncertain; calibdeg: the
//             same mistakes through phone-like audio
// --sweep: each group's margins in turn, from the given ones.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

const _expect = {
  'vowel_DAMMA_FATHA': RecitationErrorType.wrongVowel,
  'vowel_DAMMA_KASRA': RecitationErrorType.wrongVowel,
  'vowel_FATHA_KASRA': RecitationErrorType.wrongVowel,
  'consonant': RecitationErrorType.wrongLetter,
  'sukun': RecitationErrorType.sukunError,
  'missing_vowel': RecitationErrorType.missingVowel,
  'shadda_missing': RecitationErrorType.shaddaError,
  'shadda_extra': RecitationErrorType.shaddaError,
};

late QuranPhoneticReference _reference;

void main(List<String> args) {
  final tag = args.first;
  String? opt(String name) {
    final i = args.indexOf('--$name');
    return i < 0 ? null : args[i + 1];
  }

  _reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final mine = [
    for (final s
        in (opt('mine') ?? 'phone,phone2,phone3,phone4,phone6,phone7').split(
          ',',
        ))
      ..._load('${s}_$tag'),
  ];
  final retasy = _load('retasy_$tag');
  final calib = _load('calib_$tag');
  final calibdeg = _load('calibdeg_$tag');
  final base = AcousticThresholds(
    error: double.parse(opt('error') ?? '4'),
    letterError: double.parse(opt('error') ?? '4'),
    shaddaError: double.parse(opt('error') ?? '4'),
    sukunError: double.parse(opt('minor') ?? '3'),
    missingVowelError: double.parse(opt('minor') ?? '3'),
    correct: double.parse(opt('correct') ?? '0'),
    pauseFrames: int.parse(opt('pause') ?? '6'),
    sounds: _parse(opt('margins') ?? ''),
    maddShare: double.parse(opt('madd') ?? '0.65'),
    mistakeEntropy: opt('entropy') == null
        ? null
        : double.parse(opt('entropy')!),
  );

  stdout.writeln(
    '${'setting'.padRight(34)}'
    'mine fl/unc   amateur fl/unc   amat.err fl/any   '
    'calib right cl.fl/unc   deg right',
  );
  void row(String name, AcousticThresholds th) {
    final m = _clean(mine, th, null);
    final a = _clean(retasy, th, 'retasy_correct');
    final e = _clean(retasy, th, 'retasy_incorrect');
    final (right, _) = _mistakes(calib, th);
    final c = _clean(calib, th, null);
    final (degRight, _) = _mistakes(calibdeg, th);
    String p(double v) => v.toStringAsFixed(1).padLeft(5);
    stdout.writeln(
      '${name.padRight(34)}'
      '${p(m.$1)}/${p(m.$2)}   ${p(a.$1)}/${p(a.$2)}     '
      '${p(e.$1)}/${p(e.$1 + e.$2)}    ${p(right)}  ${p(c.$1)}/${p(c.$2)}'
      '   ${p(degRight)}',
    );
  }

  row('as given', base);
  if (args.contains('--clips')) {
    // RetaSy per clip: any word flagged, in clips judged correct / incorrect.
    double share(String category) {
      var n = 0, hit = 0;
      for (final c in retasy) {
        if (c.m['category'] != category) continue;
        n++;
        if (c.judge(base).values.any((k) => k.any((t) => t.isError))) hit++;
      }
      return n == 0 ? 0 : hit * 100 / n;
    }

    stdout.writeln(
      'clips with a mistake flagged: correct '
      '${share('retasy_correct').toStringAsFixed(1)}%, incorrect '
      '${share('retasy_incorrect').toStringAsFixed(1)}%',
    );
  }
  if (args.contains('--sweep')) {
    for (final g in SoundGroup.values) {
      final at = base.sounds[g] ?? const SoundMargins();
      for (final (de, du) in [
        (0.0, 1.0),
        (0.0, 2.0),
        (0.0, 3.0),
        (1.0, 2.0),
        (2.0, 3.0),
      ]) {
        final sounds = {
          ...base.sounds,
          g: SoundMargins(error: at.error + de, uncertain: at.uncertain + du),
        };
        row('  ${g.name} +$de/+$du', base.copyWith(sounds: sounds));
      }
    }
    for (final n in [5, 4, 3]) {
      row('  pause $n frames', base.copyWith(pauseFrames: n));
    }
  }
}

Map<SoundGroup, SoundMargins> _parse(String s) => {
  for (final part in s.split(',').where((p) => p.isNotEmpty))
    SoundGroup.values.byName(part.split('=')[0]): SoundMargins(
      error: double.parse(part.split('=')[1].split('/')[0]),
      uncertain: double.parse(part.split('=')[1].split('/')[1]),
    ),
};

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
  final meta = (jsonDecode(json.readAsStringSync()) as List)
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

/// Clean words (of [category], or all): % flagged, % only uncertain.
(double, double) _clean(
  List<_Case> cases,
  AcousticThresholds th,
  String? category,
) {
  var words = 0, flagged = 0, unsure = 0;
  for (final c in cases) {
    if (c.m['set'] != 'clean') continue;
    if (category != null && c.m['category'] != category) continue;
    for (final k in c.judge(th).values) {
      words++;
      if (k.any((t) => t.isError)) {
        flagged++;
      } else if (k.contains(RecitationErrorType.uncertain)) {
        unsure++;
      }
    }
  }
  return words == 0 ? (0, 0) : (flagged * 100 / words, unsure * 100 / words);
}

/// Spliced mistakes: % found with the right type, % noticed at all.
(double, double) _mistakes(List<_Case> cases, AcousticThresholds th) {
  var n = 0, right = 0, any = 0;
  for (final c in cases) {
    if (c.m['kind'] != 'spliced') continue;
    n++;
    final judged = c.judge(th);
    final kinds = {for (final w in c.targets) ...?judged[w]};
    if (kinds.contains(_expect[c.m['category']])) right++;
    if (kinds.any((k) => k.isError || k == RecitationErrorType.uncertain)) {
      any++;
    }
  }
  return n == 0 ? (0, 0) : (right * 100 / n, any * 100 / n);
}
