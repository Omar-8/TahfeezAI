import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';

void main() {
  test('the first word marked with a mistake: in reading order, of an ayah '
      'if asked; correct and unsure words are none', () {
    const overlay = MushafWordOverlay(
      first: (ayahId: 2001, wordIndex: 0),
      last: (ayahId: 2005, wordIndex: 9),
      marks: {
        (ayahId: 2001, wordIndex: 0): MushafWordMark.correct,
        (ayahId: 2001, wordIndex: 1): MushafWordMark.uncertain,
        (ayahId: 2003, wordIndex: 2): MushafWordMark.tajweed,
        (ayahId: 2002, wordIndex: 4): MushafWordMark.wrong,
        (ayahId: 2002, wordIndex: 1): MushafWordMark.checking,
        (ayahId: 2003, wordIndex: 0): MushafWordMark.skipped,
      },
    );
    expect(firstMarkedMistake(overlay), (ayahId: 2002, wordIndex: 4));
    expect(firstMarkedMistake(overlay, ayahId: 2003), (
      ayahId: 2003,
      wordIndex: 0,
    ));
    expect(firstMarkedMistake(overlay, ayahId: 2001), isNull);
    expect(firstMarkedMistake(null), isNull);
    // All of them, in reading order: the word sheet's "2 / 3".
    expect(markedMistakes(overlay), [
      (ayahId: 2002, wordIndex: 4),
      (ayahId: 2003, wordIndex: 0),
      (ayahId: 2003, wordIndex: 2),
    ]);
  });
}
