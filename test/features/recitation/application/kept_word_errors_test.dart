import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/features/recitation/application/kept_word_errors.dart';

void main() {
  test('a word\'s mistakes kept and read back as they were heard', () {
    const word = (ayahId: 2012, wordIndex: 3);
    const vowel = RecitationError(
      word: word,
      letter: 2,
      type: RecitationErrorType.wrongVowel,
      expected: 'u',
      observed: 'a',
      likelihoodRatio: 7.5,
    );
    final ghunnah = RecitationError(
      word: word,
      letter: 0,
      type: RecitationErrorType.ghunnahMissing,
      expected: 'n',
      likelihoodRatio: 4,
      rule: TajweedRule.values.first,
    );
    final stored = jsonDecode(
      jsonEncode(
        KeptWordErrorsController.encode({
          word: [vowel, ghunnah],
        }),
      ),
    );
    final back = KeptWordErrorsController.decode(stored)[word]!;
    expect(back, hasLength(2));
    expect(back[0].type, RecitationErrorType.wrongVowel);
    expect(back[0].letter, 2);
    expect(back[0].expected, 'u');
    expect(back[0].observed, 'a');
    expect(back[1].type, RecitationErrorType.ghunnahMissing);
    expect(back[1].observed, isNull);
    expect(back[1].rule, TajweedRule.values.first);
  });

  test('what can\'t be read is left out, not a failure', () {
    expect(KeptWordErrorsController.decode('nonsense'), isEmpty);
    expect(
      KeptWordErrorsController.decode({
        'x:y': [],
        '1001:0': [
          {'t': 'noSuchType', 'l': 0, 'e': 'b'},
        ],
        '1001:1': [
          {'t': 'wrongVowel', 'l': 0, 'e': 'i'},
        ],
      }).keys,
      [(ayahId: 1001, wordIndex: 1)],
    );
  });
}
