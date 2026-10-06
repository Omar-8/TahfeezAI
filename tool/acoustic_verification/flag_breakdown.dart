// Which sounds the verifier flags on correct recitation, by sound type:
//
//   dart run tool/acoustic_verification/flag_breakdown.dart <data.json> <data.f32>...
//       [--category C] [--all] [--margins group=error/uncertain,...] [--error 4] [--letter 4] [--missing 3] [--sukun 3] [--shadda 4] [--correct 0]
//
// For every clean case (correct recitation), each expected sound's verdict,
// grouped by the sound's class (see [soundClass]) — how often each class is
// judged a mistake or left uncertain, and the words that get flagged.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

void main(List<String> args) {
  double? opt(String name) {
    final i = args.indexOf('--$name');
    return i < 0 ? null : double.parse(args[i + 1]);
  }

  final mi = args.indexOf('--margins');
  final th = AcousticThresholds(
    error: opt('error') ?? 4,
    letterError: opt('letter') ?? 4,
    missingVowelError: opt('missing') ?? 3,
    sukunError: opt('sukun') ?? 3,
    shaddaError: opt('shadda') ?? 4,
    correct: opt('correct') ?? 0,
    sounds: {
      for (final part in (mi < 0 ? '' : args[mi + 1]).split(','))
        if (part.isNotEmpty)
          SoundGroup.values.byName(part.split('=')[0]): SoundMargins(
            error: double.parse(part.split('=')[1].split('/')[0]),
            uncertain: double.parse(part.split('=')[1].split('/')[1]),
          ),
    },
  );
  final ci = args.indexOf('--category');
  final category = ci < 0 ? null : args[ci + 1];
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--all') continue;
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    paths.add(args[i]);
  }
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final verifier = QuranAcousticVerifier(thresholds: th);
  final total = <String, int>{},
      wrong = <String, int>{},
      unsure = <String, int>{};
  final examples = <String, Map<String, int>>{};
  var words = 0, flaggedWords = 0, unsureWords = 0;
  for (var p = 0; p + 1 < paths.length; p += 2) {
    final meta = (jsonDecode(File(paths[p]).readAsStringSync()) as List)
        .cast<Map<String, Object?>>();
    final bytes = File(paths[p + 1]).readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    for (final m in meta) {
      if (m['kind'] != 'clean') continue;
      if (category != null && m['category'] != category) continue;
      final ayahId = m['ayahId']! as int;
      final expected = reference.words(
        ayahId,
        m['firstWord']! as int,
        m['lastWord']! as int,
      );
      final units = {for (final t in expected) t.unit};
      final pauses = {
        for (final e in reference.pauseForms(ayahId).entries)
          if (units.contains(e.key)) e.key: e.value,
      };
      final at = m['main']! as Map;
      final n = at['frames'] as int, off = at['offset'] as int;
      final frames = AcousticFrames(
        frames: n,
        classes: 43,
        logProbs: Float32List.sublistView(all, off, off + n * 43),
        frameDuration: const Duration(milliseconds: 40),
      );
      final vs = verifier.verify(
        frames,
        expected,
        pauses: pauses,
        openStart: m['openStart']! as bool,
        openEnd: m['openEnd']! as bool,
      );
      final byWord = <Object, Set<RecitationErrorType>>{};
      for (final v in vs) {
        (byWord[v.token.word] ??= {}).add(v.type);
      }
      for (final s in byWord.values) {
        words++;
        if (s.any((t) => t.isError)) {
          flaggedWords++;
        } else if (s.contains(RecitationErrorType.uncertain)) {
          unsureWords++;
        }
      }
      // Each verdict's place in the expected sequence, for its context.
      for (final v in vs) {
        final k = expected.indexOf(v.token);
        final c = k < 0 ? 'final vowel at a pause' : soundClass(expected, k);
        total[c] = (total[c] ?? 0) + 1;
        if (v.type.isError) wrong[c] = (wrong[c] ?? 0) + 1;
        if (v.type == RecitationErrorType.uncertain) {
          unsure[c] = (unsure[c] ?? 0) + 1;
        }
        if (v.type.isError || v.type == RecitationErrorType.uncertain) {
          final w = v.token.word;
          final key =
              '${w.ayahId ~/ 1000}:${w.ayahId % 1000}:${w.wordIndex + 1} '
              '${v.token.symbol}(${v.token.sourceChar}) ${v.type.name}'
              '${v.observed == null ? '' : '→${v.observed}'}';
          final ex = examples[c] ??= {};
          ex[key] = (ex[key] ?? 0) + 1;
        }
      }
    }
  }
  String pct(int a, int b) =>
      b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';
  stdout.writeln(
    'words $words: flagged ${pct(flaggedWords, words)}, '
    'uncertain ${pct(unsureWords, words)}',
  );
  final classes = total.keys.toList()
    ..sort(
      (a, b) => ((wrong[b] ?? 0) + (unsure[b] ?? 0)).compareTo(
        (wrong[a] ?? 0) + (unsure[a] ?? 0),
      ),
    );
  stdout.writeln('class\tsounds\tmistake\tuncertain');
  for (final c in classes) {
    final t = total[c]!;
    stdout.writeln(
      '$c\t$t\t${wrong[c] ?? 0} (${pct(wrong[c] ?? 0, t)})\t'
      '${unsure[c] ?? 0} (${pct(unsure[c] ?? 0, t)})',
    );
    final ex = (examples[c] ?? {}).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in ex.take(args.contains('--all') ? 1000 : 4)) {
      stdout.writeln('    ${e.value}× ${e.key}');
    }
  }
}

const _qalqala = 'قطبجد';
const _heavy = 'صضطظقغخ';

/// The class of the expected sound at [k], for grouping flags.
String soundClass(List<PhoneticToken> ts, int k) {
  final t = ts[k];
  final next = k + 1 < ts.length ? ts[k + 1] : null;
  final prev = k > 0 ? ts[k - 1] : null;
  final unitEnd = next == null || next.unit != t.unit;
  switch (t.kind) {
    case PhoneticTokenKind.vowel:
      final beforeLong = next != null && next.kind == PhoneticTokenKind.long;
      if (t.unitFinalVowel) return 'vowel: unit-final';
      if (beforeLong) return 'vowel: before a madd';
      if (prev != null && 'نم'.contains(prev.symbol) && prev.geminate) {
        return 'vowel: after ghunnah (نّ مّ)';
      }
      if (prev != null && _heavy.contains(prev.symbol)) {
        return 'vowel: after a heavy letter';
      }
      return 'vowel: other';
    case PhoneticTokenKind.consonant:
      final afterLong = prev != null && prev.kind == PhoneticTokenKind.long;
      if (t.geminate ||
          (next != null && next.geminate && next.token == t.token)) {
        return 'نم'.contains(t.symbol)
            ? 'shadda: ghunnah (نّ مّ)'
            : 'shadda: other';
      }
      final sakin =
          next == null ||
          next.unit != t.unit ||
          next.kind == PhoneticTokenKind.consonant ||
          next.kind == PhoneticTokenKind.marker;
      if (sakin && _qalqala.contains(t.symbol)) return 'sakin: qalqala letter';
      if (sakin && afterLong) {
        return unitEnd
            ? 'sakin: after a madd, at the end'
            : 'sakin: after a madd';
      }
      if (sakin && 'نم'.contains(t.symbol)) return 'sakin: ن م';
      if (sakin) return unitEnd ? 'sakin: unit-final' : 'sakin: other';
      if (_heavy.contains(t.symbol)) return 'letter: heavy';
      if ('عحهءغخ'.contains(t.symbol)) return 'letter: throat';
      return 'letter: other';
    case PhoneticTokenKind.long:
      return 'long';
    case PhoneticTokenKind.marker:
      return 'marker';
  }
}
