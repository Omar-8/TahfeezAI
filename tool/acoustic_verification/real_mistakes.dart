// Real mistakes (QuranMB.v2: experts' annotation of what was said; pack
// built by model_work/quranmb_pack.py), judged as the app judges them:
//   dart run tool/acoustic_verification/real_mistakes.dart <data.json> <data.f32> [--minor M]
// (any pack in the bench format: a pack without targetWords is all correct
// words). Also counts words heard said as another word of the passage
// (QuranAcousticVerifier.wordSwaps): on target words, and on words heard
// right (false).
// Per clip with mistakes: is a mistake (or at least uncertainty) marked on a
// word the experts heard wrong; and across all clips, words not heard wrong
// that are flagged.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

void main(List<String> args) {
  final reference = QuranPhoneticReference.fromJson(
    jsonDecode(
      File('assets/quran/recitation/phonetic_reference_hafs.json')
          .readAsStringSync(),
    ) as Map<String, Object?>,
  );
  final meta = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  final bytes = File(args[1]).readAsBytesSync();
  final all = bytes.buffer.asFloat32List(0, bytes.length ~/ 4);
  // The app's ayah check (AcousticVerificationController).
  // --minor M: the sukun / missing-vowel thresholds to try (the app's: 3).
  final minor = args.contains('--minor')
      ? double.parse(args[args.indexOf('--minor') + 1])
      : 3.0;
  final verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      error: 4,
      letterError: 4,
      shaddaError: 4,
      sukunError: minor,
      missingVowelError: minor,
      correct: -1,
      pauseFrames: 4,
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
  var clips = 0, found = 0, noticed = 0;
  var otherWords = 0, otherFlagged = 0, otherUnsure = 0;
  var targetSwaps = 0, otherSwaps = 0, targetWords = 0;
  final swapped = <String>[];
  for (final m in meta) {
    final ayahId = m['ayahId']! as int;
    final expected = reference.words(
      ayahId,
      m['firstWord']! as int,
      m['lastWord']! as int,
    );
    final units = {for (final t in expected) t.unit};
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
      pauses: {
        for (final e in reference.pauseForms(ayahId).entries)
          if (units.contains(e.key)) e.key: e.value,
      },
      openStart: m['openStart']! as bool,
      openEnd: m['openEnd']! as bool,
    );
    final byWord = <WordRef, Set<RecitationErrorType>>{};
    for (final v in vs) {
      (byWord[v.token.word] ??= {}).add(v.type);
    }
    final targets = {
      for (final w in (m['targetWords']! as List).cast<int>())
        (ayahId: ayahId, wordIndex: w),
    };
    final passage = <WordRef, List<PhoneticToken>>{};
    for (final t in expected) {
      (passage[t.word] ??= []).add(t);
    }
    targetWords += targets.where(byWord.containsKey).length;
    for (final s in verifier.wordSwaps(frames, vs, passage)) {
      if (targets.contains(s.word)) {
        targetSwaps++;
      } else {
        otherSwaps++;
        if (swapped.length < 12) {
          swapped.add(
            '${m['name']} ${ayahId ~/ 1000}:${ayahId % 1000}:'
            '${s.word.wordIndex + 1} as :${s.said.wordIndex + 1} '
            '(${s.likelihoodRatio.toStringAsFixed(1)})',
          );
        }
      }
    }
    if (targets.isNotEmpty) {
      clips++;
      final kinds = {for (final w in targets) ...?byWord[w]};
      if (kinds.any((k) => k.isError)) found++;
      if (kinds.any((k) => k.isError || k == RecitationErrorType.uncertain)) {
        noticed++;
      }
    }
    for (final MapEntry(key: w, value: k) in byWord.entries) {
      if (targets.contains(w)) continue;
      otherWords++;
      if (k.any((t) => t.isError)) {
        otherFlagged++;
      } else if (k.contains(RecitationErrorType.uncertain)) {
        otherUnsure++;
      }
    }
  }
  String pct(int a, int b) =>
      b == 0 ? '-' : '${(100 * a / b).toStringAsFixed(1)}%';
  stdout.writeln(
    'clips with mistakes $clips: mistake marked on a wrong word '
    '${pct(found, clips)}, marked or uncertain ${pct(noticed, clips)}',
  );
  stdout.writeln(
    'words heard right $otherWords: flagged ${pct(otherFlagged, otherWords)}, '
    'only uncertain ${pct(otherUnsure, otherWords)}',
  );
  stdout.writeln(
    'said as another word: target words $targetSwaps of $targetWords, '
    'words heard right $otherSwaps (${pct(otherSwaps, otherWords)})',
  );
  for (final s in swapped) {
    stdout.writeln('  $s');
  }
}
