import 'package:flutter_test/flutter_test.dart';

import '../matching/corpus_fixture.dart';
import 'acoustic_test_support.dart';

bool _isLetter(int c) =>
    ((c >= 0x0621 && c <= 0x064A) || c == 0x0671 || c == 0x0670) && c != 0x0640;

/// Integrity of `phonetic_reference_hafs.json` against Tahfeez's Quran text.
void main() {
  final corpus = loadTestCorpus();
  final reference = loadTestReference();
  final words = <int, List<String>>{};
  for (final w in corpus.words) {
    (words[w.ref.ayahId] ??= []).add(w.text);
  }

  test('every ayah has a pronunciation mapped onto its own words', () {
    expect(words.keys.every(reference.hasAyah), isTrue);
    var tokens = 0;
    for (final MapEntry(key: id, value: ws) in words.entries) {
      final ts = reference.ayah(id);
      tokens += ts.length;
      expect(ts, isNotEmpty, reason: '$id');
      // Every word is pronounced, in order.
      final seen = {for (final t in ts) t.word.wordIndex}.toList()..sort();
      expect(seen, List.generate(ws.length, (i) => i), reason: '$id');
      for (var i = 1; i < ts.length; i++) {
        expect(ts[i].unit, greaterThanOrEqualTo(ts[i - 1].unit));
      }
    }
    expect(tokens, 551252);
  });

  test('each sound points at a real letter of Tahfeez\'s text', () {
    var checked = 0;
    for (final MapEntry(key: id, value: ws) in words.entries) {
      for (final t in reference.ayah(id)) {
        final letters = [
          for (final r in ws[t.word.wordIndex].runes)
            if (_isLetter(r)) String.fromCharCode(r),
        ];
        expect(t.letter, lessThan(letters.length), reason: '$id ${t.word}');
        // When the source is a letter, it is that very letter.
        if (_isLetter(t.sourceChar.runes.single)) {
          expect(letters[t.letter], t.sourceChar, reason: '$id ${t.word}');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(200000));
  });

  test('1:2 «رَبِّ» has a doubled ب and a kasra from its kasra mark', () {
    final rabbi = reference.words(1002, 2, 2);
    expect(rabbi.map((t) => t.symbol).join(), 'رَببِ');
    expect(rabbi[3].geminate, isTrue);
    expect(rabbi.last.sourceChar, 'ِ');
    expect(rabbi.last.unitFinalVowel, isTrue);
    expect(rabbi.last.word, (ayahId: 1002, wordIndex: 2));
  });
}
