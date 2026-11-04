// How often given words are flagged on correct recitation, at the app's own
// settings (balanced: AcousticVerificationController's calibrated thresholds
// with the streaming model's, tajweed on), and on which sound — the words
// users report as marked wrongly while said right:
//
//   dart run tool/acoustic_verification/word_flags.dart <tag> <regex> <pack>...
//   (results/<pack>_<tag>.json/.f32; <regex> over each word's spoken form in
//   the phonetic reference, e.g. 'لَذِ[يى]' for الَّذِينَ / الَّذِي)
//
// [--error X] [--letter X]: the app's 3.6 / 4.1 changed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

const _results = 'tool/acoustic_verification/model_work/artifacts/results';

// AcousticVerificationController.learnerSounds (2026-11-04).
const _learnerSounds = {
  SoundGroup.shadda: SoundMargins(uncertain: 2),
  SoundGroup.relativeLam: SoundMargins(error: 4, uncertain: 2),
  SoundGroup.reducedVowel: SoundMargins(error: 0, uncertain: 2),
  SoundGroup.finalVowel: SoundMargins(error: 1, uncertain: 2),
  SoundGroup.qalqala: SoundMargins(error: 2, uncertain: 4),
  SoundGroup.nasal: SoundMargins(uncertain: 2),
  SoundGroup.hiddenNasal: SoundMargins(error: -1),
  SoundGroup.throat: SoundMargins(uncertain: 2),
  SoundGroup.similarLetter: SoundMargins(error: 4),
  SoundGroup.phoneWeak: SoundMargins(error: 2, uncertain: 2),
  SoundGroup.wordFinalVowel: SoundMargins(error: -2.6),
  SoundGroup.stopInFlow: SoundMargins(error: 1),
};

void main(List<String> args) {
  double? opt(String name) {
    final i = args.indexOf('--$name');
    return i < 0 ? null : double.parse(args[i + 1]);
  }

  final plain = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      i++;
      continue;
    }
    plain.add(args[i]);
  }
  final tag = plain[0];
  final pattern = RegExp(plain[1]);
  final packs = plain.sublist(2);
  final error = opt('error') ?? 3.6;
  // --lam X: [SoundGroup.relativeLam]'s margin (the app's otherwise).
  final lam = opt('lam');
  // The app's balanced setting with the streaming model
  // (AcousticVerificationController._withTajweed).
  final verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: error,
      letterError: opt('letter') ?? 4.1,
      shaddaError: error,
      sukunError: 3,
      missingVowelError: 3,
      correct: -1,
      pauseFrames: 4,
      sounds: {
        ..._learnerSounds,
        if (lam != null)
          SoundGroup.relativeLam: SoundMargins(error: lam, uncertain: 2),
      },
      qalqalaError: -1.5,
      ghunnahHold: 1.5,
    ),
  );
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  for (final pack in packs) {
    final meta = (jsonDecode(
      File('$_results/${pack}_$tag.json').readAsStringSync(),
    ) as List).cast<Map<String, Object?>>();
    final bytes = File('$_results/${pack}_$tag.f32').readAsBytesSync();
    final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
    var said = 0, flagged = 0, unsure = 0, otherWords = 0, otherFlagged = 0;
    final sounds = <String, int>{};
    for (final m in meta) {
      if (m['kind'] != 'clean') continue;
      final ayahId = m['ayahId']! as int;
      final expected = reference.words(
        ayahId,
        m['firstWord']! as int,
        m['lastWord']! as int,
      );
      // The words matching, by their spoken form.
      final forms = <Object, StringBuffer>{};
      for (final t in expected) {
        if (t.kind == PhoneticTokenKind.marker) continue;
        (forms[t.word] ??= StringBuffer()).write(t.sourceChar);
      }
      final chosen = {
        for (final e in forms.entries)
          if (pattern.hasMatch(e.value.toString())) e.key,
      };
      final units = {for (final t in expected) t.unit};
      final at = m['main']! as Map;
      final n = at['frames'] as int, off = at['offset'] as int;
      final vs = verifier.verify(
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
        openStart: m['openStart']! as bool,
        openEnd: m['openEnd']! as bool,
      );
      final byWord = <Object, List<PhonemeVerdict>>{};
      for (final v in vs) {
        (byWord[v.token.word] ??= []).add(v);
      }
      for (final MapEntry(key: word, value: verdicts) in byWord.entries) {
        final error = verdicts.any((v) => v.type.isError);
        if (!chosen.contains(word)) {
          otherWords++;
          if (error) otherFlagged++;
          continue;
        }
        said++;
        if (error) {
          flagged++;
        } else if (verdicts.any(
          (v) => v.type == RecitationErrorType.uncertain,
        )) {
          unsure++;
        }
        for (final v in verdicts) {
          if (!v.type.isError) continue;
          final k = expected.indexOf(v.token);
          final before = k > 0 ? expected[k - 1].symbol : '';
          final key =
              '${v.token.symbol}(${v.token.sourceChar}) after «$before» '
              '${v.type.name}${v.observed == null ? '' : '→${v.observed}'}';
          sounds[key] = (sounds[key] ?? 0) + 1;
        }
      }
    }
    String pct(int a, int b) =>
        b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';
    stdout.writeln(
      '== $pack: matching words said $said, flagged $flagged '
      '(${pct(flagged, said)}), uncertain $unsure; other words flagged '
      '${pct(otherFlagged, otherWords)} of $otherWords',
    );
    final top = sounds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in top.take(12)) {
      stdout.writeln('    ${e.value}× ${e.key}');
    }
  }
}
