// Real recitation: Alafasy with the recorded audio of a minimal-pair word
// spliced in where the other word is expected (and each case's unspliced
// control), as heard by obadx/muaalem-model-v3_2. The Dart verifier must
// match the Python prototype (tool/acoustic_verification/acoustic.py)
// verdict for verdict.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';

import 'acoustic_test_support.dart';

const _names = {
  'CORRECT': RecitationErrorType.correct,
  'WRONG_LETTER': RecitationErrorType.wrongLetter,
  'WRONG_VOWEL': RecitationErrorType.wrongVowel,
  'MISSING_VOWEL': RecitationErrorType.missingVowel,
  'SUKUN_ERROR': RecitationErrorType.sukunError,
  'SHADDA_ERROR': RecitationErrorType.shaddaError,
  'QALQALA_MISSING': RecitationErrorType.qalqalaMissing,
  'UNCERTAIN': RecitationErrorType.uncertain,
  'PAUSE': RecitationErrorType.pause,
  'SKIPPED': RecitationErrorType.skipped,
};

void main() {
  final reference = loadTestReference();
  // The prototype's single threshold (the app's defaults are tuned per
  // mistake type).
  const verifier = QuranAcousticVerifier(
    thresholds: AcousticThresholds(
      letterError: 2.0,
      missingVowelError: 2.0,
      sukunError: 2.0,
    ),
  );
  final cases =
      ((jsonDecode(
                File('test/fixtures/acoustic/alafasy_minimal_pairs.json')
                    .readAsStringSync(),
              ) as Map)['cases']
              as List)
          .cast<Map<String, Object?>>();

  for (final c in cases) {
    test('${c['name']}: ${c['expectedWord']} ← ${c['audioWord']}', () {
      final bytes = base64Decode(c['logProbs']! as String);
      final frames = AcousticFrames(
        frames: c['frames']! as int,
        classes: 43,
        logProbs: Float32List.view(bytes.buffer, bytes.offsetInBytes),
        frameDuration: const Duration(milliseconds: 40),
      );
      final ayahId = c['ayahId']! as int;
      final expected = reference.words(
        ayahId,
        c['firstWord']! as int,
        c['lastWord']! as int,
      );
      final units = {for (final t in expected) t.unit};
      final verdicts = verifier.verify(
        frames,
        expected,
        pauses: {
          for (final MapEntry(:key, :value)
              in reference.pauseForms(ayahId).entries)
            if (units.contains(key)) key: value,
        },
        openStart: c['openStart']! as bool,
        openEnd: c['openEnd']! as bool,
      );
      final want = (c['verdicts']! as List).cast<String>();
      final llr = (c['llr']! as List).cast<num>();
      expect(verdicts.length, want.length);
      final symbols = (c['symbols']! as List).cast<String>();
      for (var k = 0; k < want.length; k++) {
        expect(verdicts[k].token.symbol, symbols[k], reason: 'token $k');
        expect(verdicts[k].type, _names[want[k]], reason: 'token $k');
        expect(verdicts[k].likelihoodRatio, closeTo(llr[k], 1e-2));
      }
    });
  }

  test('the spliced mistakes are found in the word; controls are not', () {
    final byName = {for (final c in cases) c['name']! as String: c};
    Set<String> inWord(String name) {
      final c = byName[name]!;
      final ayahId = c['ayahId']! as int;
      final expected = reference.words(
        ayahId,
        c['firstWord']! as int,
        c['lastWord']! as int,
      );
      final unit = c['targetUnit']! as int;
      final symbolsInUnit = [
        for (final t in expected)
          if (t.unit == unit) t.symbol,
      ];
      expect(symbolsInUnit, isNotEmpty);
      // Verdicts are per token; match those of the target unit by order.
      final verdicts = (c['verdicts']! as List).cast<String>();
      final symbols = (c['symbols']! as List).cast<String>();
      final first = expected.indexWhere((t) => t.unit == unit);
      return {
        for (
          var k = first;
          k < verdicts.length && k < first + symbolsInUnit.length + 2;
          k++
        )
          if (symbolsInUnit.contains(symbols[k])) verdicts[k],
      };
    }

    expect(inWord('vowel_FATHA_KASRA_0_spliced'), contains('WRONG_VOWEL'));
    expect(inWord('vowel_DAMMA_FATHA_0_spliced'), contains('WRONG_VOWEL'));
    expect(inWord('consonant_0_spliced'), contains('WRONG_LETTER'));
    expect(inWord('sukun_0_spliced'), contains('SUKUN_ERROR'));
    expect(inWord('shadda_missing_0_spliced'), contains('SHADDA_ERROR'));
    expect(inWord('shadda_extra_0_spliced'), contains('SHADDA_ERROR'));
    for (final name in [
      'vowel_FATHA_KASRA_0_control',
      'vowel_DAMMA_FATHA_0_control',
      'consonant_0_control',
    ]) {
      expect(
        (byName[name]!['verdicts']! as List).where((v) => _names[v]!.isError),
        isEmpty,
        reason: name,
      );
    }
  });
}
