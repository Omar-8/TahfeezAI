import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_model.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_phonetic_reference.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

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
    expect(letter(find('ر'), 'ل'), SoundGroup.similarLetter);
    expect(letter(find('ت', word: 2), 'ف'), SoundGroup.similarLetter);
    expect(letter(find('ر'), 'ق'), isNull);
    // Phone-weak pairs, one direction each: «ٱلْمَغْضُوبِ»'s ض heard as د and
    // «أَنْعَمْتَ»'s ء heard as ي are judged leniently; ي heard as ء is not,
    // and ض heard as ظ stays a heavy/light pair.
    expect(letter(find('ض', word: 5), 'د'), SoundGroup.phoneWeak);
    expect(letter(find('ء', word: 2), 'ي'), SoundGroup.phoneWeak);
    expect(letter(find('ي', word: 3), 'ء'), isNull);
    expect(letter(find('ض', word: 5), 'ظ'), SoundGroup.heavyLight);
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

  test('a hidden nūn said plainly is a mistake: ikhfāʾ and iqlāb', () {
    // 2:10 «فِى قُلُوبِهِم مَّرَضٌ فَزَادَهُمُ … عَذَابٌ أَلِيمٌۢ بِمَا»: the
    // tanween of مَرَضٌ hidden before ف (ں), that of أَلِيمٌ turned to a
    // hidden mīm before ب (۾).
    final expected = reference.ayah(2010);
    for (final hidden in ['ں', '۾']) {
      final k = expected.indexWhere((t) => t.symbol == hidden);
      final said = [for (final t in expected) t.token];
      expect(
        verifier.verify(clearFrames(said), expected)[k].type,
        RecitationErrorType.correct,
        reason: '$hidden said as written',
      );
      said[k] = phoneticClassOf('ن');
      final v = verifier.verify(clearFrames(said), expected)[k];
      expect(v.type, RecitationErrorType.wrongLetter, reason: hidden);
      expect(v.observed, 'ن');
    }
  });

  test('with tajweed off, only the letters and vowels are judged', () {
    const plain = QuranAcousticVerifier(
      thresholds: AcousticThresholds(tajweed: false),
    );
    // 2:10: ikhfāʾ and iqlāb said with a plain nūn — fine with tajweed off.
    final ayah10 = reference.ayah(2010);
    for (final hidden in ['ں', '۾']) {
      final k = ayah10.indexWhere((t) => t.symbol == hidden);
      final said = [for (final t in ayah10) t.token];
      said[k] = phoneticClassOf('ن');
      expect(
        plain.verify(clearFrames(said), ayah10)[k].type.isError,
        isFalse,
        reason: hidden,
      );
    }
    // 2:7 «غِشَٰوَةٌ وَلَهُمْ» joined, the tanween's nūn said (no idghām).
    final ayah7 = reference.ayah(2007);
    final merged = ayah7.indexWhere(
      (t) =>
          t.kind == PhoneticTokenKind.consonant &&
          t.sourceChar == 'ٌ' &&
          t.symbol == 'و' &&
          !t.geminate,
    );
    final said7 = [for (final t in ayah7) t.token];
    said7[merged] = phoneticClassOf('ن');
    expect(
      plain.verify(clearFrames(said7), ayah7).where((v) => v.type.isError),
      isEmpty,
    );
    expect(
      verifier.verify(clearFrames(said7), ayah7).where((v) => v.type.isError),
      isNotEmpty,
      reason: 'with tajweed on, it is a mistake',
    );
    // A wrong letter is still a mistake.
    final k = ayah7.indexWhere((t) => t.symbol == 'خ');
    final wrong = [for (final t in ayah7) t.token];
    wrong[k] = phoneticClassOf('ح');
    expect(
      plain.verify(clearFrames(wrong), ayah7)[k].type,
      RecitationErrorType.wrongLetter,
    );
  });

  test('a qalqala letter without its echo is a tajweed mistake', () {
    // 112:3 «لَمْ يَلِدْ وَلَمْ يُولَدْ»: the stop on د — with its echo
    // (ڇ) and without.
    final expected = reference.ayah(112003);
    final k = expected.lastIndexWhere((t) => t.symbol == 'ڇ');
    final withEcho = [for (final t in expected) t.token];
    final without = [...withEcho]..removeAt(k);
    final heard = verifier.verify(clearFrames(withEcho), expected);
    expect(heard[k].type, RecitationErrorType.correct);
    final missing = verifier.verify(clearFrames(without), expected);
    expect(missing[k].type, RecitationErrorType.qalqalaMissing);
    expect(
      const QuranAcousticVerifier(
        thresholds: AcousticThresholds(tajweed: false),
      ).verify(clearFrames(without), expected).where((v) => v.type.isError),
      isEmpty,
      reason: 'tajweed off',
    );
  });

  test('a madd of four counts held for two is a tajweed mistake', () {
    // 5:109 «قَالُوا۟ لَا عِلْمَ لَنَآ إِنَّكَ …»: each madd held its count (the
    // model repeats a long vowel as it is held), then «لَنَآ»'s four-count
    // madd cut to one beat.
    final expected = reference.words(5109, 7, 14);
    final k = expected.indexWhere(
      (t) => t.kind == PhoneticTokenKind.long && t.count == 4,
    );
    List<int> said({required bool cut}) => [
      for (var i = 0; i < expected.length; i++)
        if (expected[i].kind == PhoneticTokenKind.long)
          ...List.filled(
            cut && i == k ? 1 : expected[i].count,
            expected[i].token,
          )
        else
          expected[i].token,
    ];
    final held = verifier.verify(clearFrames(said(cut: false)), expected);
    expect(held[k].type, isNot(RecitationErrorType.maddShort));
    final cut = verifier.verify(clearFrames(said(cut: true)), expected);
    expect(cut[k].type, RecitationErrorType.maddShort);
    expect(
      const QuranAcousticVerifier(
        thresholds: AcousticThresholds(tajweed: false),
      ).verify(clearFrames(said(cut: true)), expected)[k].type,
      isNot(RecitationErrorType.maddShort),
      reason: 'tajweed off',
    );
    // The madd rule alone off; another rule's mistake is still judged.
    const noMadd = QuranAcousticVerifier(
      thresholds: AcousticThresholds(
        tajweedRules: {TajweedRule.ikhfa, TajweedRule.qalqala},
      ),
    );
    expect(
      noMadd.verify(clearFrames(said(cut: true)), expected)[k].type,
      isNot(RecitationErrorType.maddShort),
      reason: 'madd off',
    );
    final ikhfa = expected.indexWhere((t) => t.symbol == 'ں');
    // «أَنتَ»'s hidden noon said as a clear «ن».
    final plain = [
      for (var i = 0; i < expected.length; i++)
        if (expected[i].kind == PhoneticTokenKind.long)
          ...List.filled(
            expected[i].count,
            i == ikhfa ? phoneticClassOf('ن') : expected[i].token,
          )
        else
          expected[i].token,
    ];
    expect(
      noMadd.verify(clearFrames(plain), expected)[ikhfa].type,
      RecitationErrorType.wrongLetter,
      reason: 'ikhfa still on',
    );
    expect(
      const QuranAcousticVerifier(
        thresholds: AcousticThresholds(tajweedRules: {TajweedRule.madd}),
      ).verify(clearFrames(plain), expected)[ikhfa].type,
      isNot(RecitationErrorType.wrongLetter),
      reason: 'ikhfa off',
    );
  });

  test(
    'a madd heard in fewer spikes is still held while its vowel returns',
    () {
      // As a streaming model hears «لَنَآ»'s four-count madd: one clear spike,
      // the vowel returning under the blank at each later beat. Still heard
      // (probability 0.3), it is held its four counts; gone (0.05), cut short.
      final expected = reference.words(5109, 7, 14);
      final k = expected.indexWhere(
        (t) => t.kind == PhoneticTokenKind.long && t.count == 4,
      );
      final said = [
        for (var i = 0; i < expected.length; i++)
          if (expected[i].kind == PhoneticTokenKind.long)
            ...List.filled(expected[i].count, expected[i].token)
          else
            expected[i].token,
      ];
      var at = 0; // the madd's first spike in [said]
      for (var i = 0; i < k; i++) {
        at += expected[i].kind == PhoneticTokenKind.long
            ? expected[i].count
            : 1;
      }
      AcousticFrames ghosts(double p) {
        final f = clearFrames(said);
        final classes = f.classes;
        final alif = expected[k].token;
        // clearFrames: a blank, then each token twice and a blank.
        for (var r = 1; r < 4; r++) {
          for (final frame in [1 + 3 * (at + r), 2 + 3 * (at + r)]) {
            f.logProbs[frame * classes + ctcBlank] = 0;
            f.logProbs[frame * classes + alif] = log(p);
          }
        }
        return f;
      }

      expect(
        verifier.verify(ghosts(0.3), expected)[k].type,
        isNot(RecitationErrorType.maddShort),
      );
      expect(
        verifier.verify(ghosts(0.05), expected)[k].type,
        RecitationErrorType.maddShort,
      );
    },
  );

  test('a word checked alone judges its madd against the session beat', () {
    // 5:109: the whole stretch sets the beat (its two-count madds); then
    // «لَنَآ» alone, its four-count madd cut to one beat, holds no two-count
    // madd of its own — judged only with the session's beat.
    final stretch = reference.words(5109, 7, 14);
    List<int> said(List<PhoneticToken> ts, {int? cut}) => [
      for (var i = 0; i < ts.length; i++)
        if (ts[i].kind == PhoneticTokenKind.long)
          ...List.filled(i == cut ? 1 : ts[i].count, ts[i].token)
        else
          ts[i].token,
    ];
    final meter = BeatMeter();
    verifier.verify(clearFrames(said(stretch)), stretch, beat: meter);
    expect(meter.value, isNotNull);
    final word = reference.words(5109, 10, 10);
    final k = word.indexWhere(
      (t) => t.kind == PhoneticTokenKind.long && t.count == 4,
    );
    final cut = clearFrames(said(word, cut: k));
    expect(
      verifier.verify(cut, word, openStart: true, openEnd: true)[k].type,
      isNot(RecitationErrorType.maddShort),
      reason: 'no beat of its own',
    );
    expect(
      verifier
          .verify(cut, word, openStart: true, openEnd: true, beat: meter)[k]
          .type,
      RecitationErrorType.maddShort,
    );
  });

  test('a word said in another word\'s place is named, not spelled', () {
    // 103:3 «… وَتَوَاصَوْا۟ بِٱلْحَقِّ وَتَوَاصَوْا۟ بِٱلصَّبْرِ»: «بِٱلصَّبْرِ» said
    // where «بِٱلْحَقِّ» belongs.
    final passage = reference.words(103003, 0, 8);
    final byWord = <WordRef, List<PhoneticToken>>{};
    for (final t in passage) {
      (byWord[t.word] ??= []).add(t);
    }
    final haqq = byWord.keys.firstWhere((w) => w.wordIndex == 6);
    final sabr = byWord.keys.firstWhere((w) => w.wordIndex == 8);
    final said = [
      for (final t in passage)
        if (t.word == haqq) ...[
          if (t == byWord[haqq]!.first)
            for (final u in byWord[sabr]!)
              if (!u.optional) u.token,
        ] else if (!t.optional)
          t.token,
    ];
    final frames = clearFrames(said);
    final verdicts = verifier.verify(frames, passage, openEnd: true);
    final swaps = verifier.wordSwaps(frames, verdicts, byWord);
    expect(swaps.map((s) => (s.word, s.said)), [(haqq, sabr)]);
    // Said as written, nothing is swapped.
    final right = clearFrames([
      for (final t in passage)
        if (!t.optional) t.token,
    ]);
    expect(
      verifier.wordSwaps(right, verifier.verify(right, passage), byWord),
      isEmpty,
    );
  });

  test('a vowel kept on «ٱلْقَارِعَةُ» at the ayah\'s stop is a mistake', () {
    // 101:1 ends the ayah: recited alone it stops on «…عَهْ». Said in its
    // flow form with a fatha instead («…عَتَ»), or a damma («…عَتُ»), the
    // stop is not kept.
    final expected = reference.words(101001, 0, 0);
    final stop = [
      for (final t in expected)
        if (!t.optional) t.token,
    ];
    final ta = quranPhoneticVocabulary.indexOf('ت');
    List<int> kept(ShortVowel v) => [
      ...stop.sublist(0, stop.length - 1),
      ta,
      v.token,
    ];
    bool flagged(List<int> said) =>
        verifier.verify(clearFrames(said), expected).any((v) => v.type.isError);
    expect(flagged(stop), isFalse, reason: 'the stop form «…عَهْ»');
    expect(flagged(kept(ShortVowel.fatha)), isTrue);
    expect(flagged(kept(ShortVowel.damma)), isTrue);
  });

  test('two ayahs joined: the end in flow and the next start joined, as a '
      'pair', () {
    // 106:3-4 «…ٱلْبَيْتِ ٱلَّذِىٓ…» said on without a stop: «-bayti-lladhī»,
    // the ت with its kasra and no hamza before «لَّذِي». Judged one unit at a
    // time against the next ayah's fresh start, the kasra read as a sukun
    // mistake.
    final span = reference.span([
      (ayahId: 106003, wordIndex: 3),
      (ayahId: 106004, wordIndex: 0),
    ]);
    final units = {for (final t in span.tokens) t.unit}.toList()..sort();
    List<PhoneticToken> unit(int u) => [
      for (final t in span.tokens)
        if (t.unit == u) t,
    ];
    final end = units.first, next = units.last;
    final joined = [
      ...span.pauses[end]!.apply(
        unit(end),
        stop: false,
        start: false,
        begin: false,
      ),
      ...span.pauses[next]!.apply(
        unit(next),
        stop: false,
        start: false,
        end: false,
      ),
    ];
    final heard = [
      for (final t in joined)
        if (!t.optional) t.token,
    ];
    final verdicts = verifier.verify(
      clearFrames(heard),
      span.tokens,
      pauses: span.pauses,
      openStart: true,
      openEnd: true,
    );
    expect(verdicts.where((v) => v.type.isError), isEmpty);
    // Stopped instead, and started afresh: fine too.
    final stopped = [
      for (final t in [...unit(end), ...unit(next)])
        if (!t.optional) t.token,
    ];
    final cut = unit(end).where((t) => !t.optional).length;
    expect(
      verifier
          .verify(
            clearFrames(stopped, pauseAfter: cut),
            span.tokens,
            pauses: span.pauses,
            openStart: true,
            openEnd: true,
          )
          .where((v) => v.type.isError),
      isEmpty,
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
