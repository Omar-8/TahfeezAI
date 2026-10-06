import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';

import 'acoustic_test_support.dart';

void main() {
  final reference = loadTestReference();
  const verifier = QuranAcousticVerifier();
  // 1:2 «ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ», words 2–3 in the middle.
  final expected = reference.words(1002, 1, 2); // لِلَّهِ رَبِّ
  List<int> said() => [for (final t in expected) t.token];

  PhonemeVerdict at(List<PhonemeVerdict> vs, String word, int n) => vs
      .where((v) => v.token.word.wordIndex == (word == 'lillahi' ? 1 : 2))
      .elementAt(n);

  List<PhonemeVerdict> verify(List<int> heard) =>
      verifier.verify(clearFrames(heard), expected);

  test('a correct recitation is correct throughout', () {
    final vs = verify(said());
    expect(vs.map((v) => v.type).toSet(), {RecitationErrorType.correct});
  });

  test('damma expected, kasra heard: the letter is right, the vowel wrong', () {
    // «رَبِّ» said «رُبِّ»: first vowel of word 3.
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.kind == PhoneticTokenKind.vowel,
    );
    heard[k] = ShortVowel.damma.token;
    final vs = verify(heard);
    expect(at(vs, 'rabbi', 0).type, RecitationErrorType.correct); // ر
    expect(vs[k].type, RecitationErrorType.wrongVowel);
    expect(vs[k].observed, 'DAMMA');
    expect(vs[k].token.sourceChar, 'َ');
    final errors = verifier.errors(vs, const Duration(milliseconds: 40));
    expect(errors.single.word, (ayahId: 1002, wordIndex: 2));
    expect(errors.single.letter, 0); // on ر
  });

  test('a missing shadda is a shadda error', () {
    final heard = said();
    final k = expected.indexWhere((t) => t.word.wordIndex == 2 && t.geminate);
    heard.removeAt(k);
    final vs = verify(heard);
    expect(vs[k].type, RecitationErrorType.shaddaError);
    expect(vs[k].observed, 'NO_SHADDA');
  });

  test('a wrong consonant is a wrong letter', () {
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.symbol == 'ر',
    );
    heard[k] = phoneticClassOf('ل');
    final vs = verify(heard);
    expect(vs[k].type, RecitationErrorType.wrongLetter);
    expect(vs[k].observed, 'ل');
  });

  test('a dropped vowel mid-word is a missing vowel', () {
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.kind == PhoneticTokenKind.vowel,
    );
    heard.removeAt(k);
    final vs = verify(heard);
    expect(vs[k].type, RecitationErrorType.missingVowel);
  });

  test('weak evidence is uncertain, never a mistake', () {
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.kind == PhoneticTokenKind.vowel,
    );
    final frames = clearFrames(heard);
    // The expected fatha and a damma equally likely where it was said.
    final damma = ShortVowel.damma.token;
    for (var f = 0; f < frames.frames; f++) {
      if (frames.at(f, heard[k]) == 0) {
        frames.logProbs[f * frames.classes + heard[k]] = -0.693;
        frames.logProbs[f * frames.classes + damma] = -0.693;
      }
    }
    final vs = verifier.verify(frames, expected);
    expect(vs[k].type, RecitationErrorType.uncertain);
  });

  test("a sound group's margins apply to its own alternatives only", () {
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.kind == PhoneticTokenKind.vowel,
    );
    heard.removeAt(k); // a vowel dropped mid-word: clearly missing
    QuranAcousticVerifier withMargins(SoundMargins m) => QuranAcousticVerifier(
      thresholds: AcousticThresholds(sounds: {SoundGroup.reducedVowel: m}),
    );
    final frames = clearFrames(heard);
    // Needing far more evidence to be a mistake, it is only uncertain…
    final loose = withMargins(const SoundMargins(error: 100))
        .verify(frames, expected)[k];
    expect(loose.type, RecitationErrorType.uncertain);
    expect(loose.observed, 'SUKUN');
    // …and far more to be uncertain too, the dropped vowel no longer decides
    // (the other vowels, as unheard as the expected one, still may).
    final passed = withMargins(const SoundMargins(error: 100, uncertain: 100))
        .verify(frames, expected)[k];
    expect(passed.type.isError, isFalse);
    expect(passed.observed, isNot('SUKUN'));
    // Another group's margins leave a wrong letter a wrong letter.
    final letter = said();
    final r = expected.indexWhere(
      (t) => t.word.wordIndex == 2 && t.symbol == 'ر',
    );
    letter[r] = phoneticClassOf('ل');
    expect(
      withMargins(const SoundMargins(error: 100, uncertain: 100))
          .verify(clearFrames(letter), expected)[r]
          .type,
      RecitationErrorType.wrongLetter,
    );
  });

  test('sound groups: which alternatives are naturally weak evidence', () {
    // 1:7 «صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ …»
    final ts = reference.ayah(1007);
    int find(String symbol, {int word = 0}) =>
        ts.indexWhere((t) => t.symbol == symbol && t.word.wordIndex == word);
    SoundGroup? letter(int k, String heard) => SoundGroup.of(
      ts,
      k,
      RecitationErrorType.wrongLetter,
      phoneticClassOf(heard),
    );
    expect(letter(find('ص'), 'س'), SoundGroup.heavyLight);
    expect(letter(find('ط'), 'ت'), SoundGroup.heavyLight);
    expect(letter(find('ص'), 'ش'), isNull);
    expect(letter(find('ن', word: 2), 'م'), SoundGroup.nasal);
    expect(letter(find('ع', word: 2), 'ء'), SoundGroup.throat);
    expect(letter(find('ر'), 'ل'), isNull);
    final vowel = ts.indexWhere((t) => t.kind == PhoneticTokenKind.vowel);
    expect(
      SoundGroup.of(ts, vowel, RecitationErrorType.missingVowel, null),
      SoundGroup.reducedVowel,
    );
    final last = ts.indexWhere((t) => t.unitFinalVowel);
    expect(
      SoundGroup.of(ts, last, RecitationErrorType.missingVowel, null),
      SoundGroup.finalVowel,
    );
    expect(
      SoundGroup.of(ts, vowel, RecitationErrorType.wrongVowel, null),
      isNull,
    );
    // 112:3 «لَمْ يَلِدْ وَلَمْ يُولَدْ»: د with sukun, a qalqala letter.
    final ikhlas = reference.ayah(112003);
    final dal = ikhlas.indexWhere((t) => t.symbol == 'د');
    expect(
      SoundGroup.of(
        ikhlas,
        dal,
        RecitationErrorType.wrongLetter,
        phoneticClassOf('ت'),
      ),
      SoundGroup.qalqala,
    );
  });

  test('stopping inside a joined unit is a stop, not a mistake', () {
    // 2:7 «غِشَٰوَةٌ ۖ وَلَهُمْ»: in flow one unit (the tanween merges into the
    // و); stopping after غِشَٰوَةٌ (a waqf mark) it is said «غِشَاوَه», and
    // «وَلَهُمْ» starts afresh.
    final expected = reference.words(2007, 8, 9);
    final unit = expected.first.unit;
    final forms = reference.pauseForms(2007);
    final pauses = {
      for (final e in forms.entries)
        if (expected.any((t) => t.unit == e.key)) e.key: e.value,
    };
    final split = forms[unit]!.splits[8]!;
    final heard = [for (final t in split) t.token];
    final cut = split.indexWhere((t) => t.word.wordIndex == 9);
    final stopped = verifier.verify(
      clearFrames(heard, pauseAfter: cut),
      expected,
      pauses: pauses,
    );
    expect(stopped.where((v) => v.type.isError), isEmpty);
    // The same sounds with no pause between them are judged as said in
    // flow, where «غِشَاوَه» is wrong.
    final flowing = verifier.verify(
      clearFrames(heard),
      expected,
      pauses: pauses,
    );
    expect(flowing.where((v) => v.type.isError), isNotEmpty);
  });

  test('a unit-final vowel dropped at a pause is a pause, not a mistake', () {
    final heard = said();
    final k = expected.indexWhere(
      (t) => t.word.wordIndex == 1 && t.unitFinalVowel,
    );
    heard.removeAt(k);
    // …with a pause after it.
    final vs = verifier.verify(clearFrames(heard, pauseAfter: k), expected);
    expect(vs[k].type, RecitationErrorType.pause);
    // Without the pause the same drop is a mistake.
    expect(verify(heard)[k].type, RecitationErrorType.missingVowel);
  });

  test('two ayahs recited joined are correct, not waqf/ibtida mistakes', () {
    // 1:1's last word and 1:2's first, «ٱلرَّحِيمِ ٱلْحَمْدُ», said without
    // stopping: the kasra of «ٱلرَّحِيمِ» kept, no hamza on «ٱلْحَمْدُ».
    final span = reference.span([
      (ayahId: 1001, wordIndex: 3),
      (ayahId: 1002, wordIndex: 0),
    ]);
    final joined = [
      for (final u in {for (final t in span.tokens) t.unit})
        ...span.pauses[u]!.apply(
          [
            for (final t in span.tokens)
              if (t.unit == u) t,
          ],
          stop: false,
          start: false,
        ),
    ];
    expect(
      joined.map((t) => t.symbol).join(),
      'ررَحِۦمِلحَمدُ',
      reason: 'the phonetizer\'s joined forms',
    );
    final frames = clearFrames([for (final t in joined) t.token]);
    // The audio runs on past 1:2's first word (openEnd).
    final vs = verifier.verify(
      frames,
      span.tokens,
      pauses: span.pauses,
      openEnd: true,
    );
    expect(vs.where((v) => v.type.isError), isEmpty);
    // Without the joined forms, the same audio would be marked wrong.
    final strict = verifier.verify(frames, span.tokens, openEnd: true);
    expect(strict.where((v) => v.type.isError), isNotEmpty);
  });

  test('a qalqala echo is not an added vowel', () {
    // 112:2 «ٱللَّهُ ٱلصَّمَدُ», stopped on: «…صصَمَدڇ», the د with qalqala.
    final words = reference.words(112002, 0, 1);
    final q = words.lastIndexWhere((t) => t.symbol == 'د');
    expect(words[q + 1].symbol, 'ڇ');
    // The echo heard as a short vowel after the د.
    for (final echo in [ShortVowel.fatha, ShortVowel.kasra]) {
      final heard = [for (final t in words) t.token];
      heard[q + 1] = echo.token;
      final vs = verifier.verify(clearFrames(heard), words);
      expect(vs.where((v) => v.type.isError), isEmpty, reason: '$echo');
    }
  });
}
