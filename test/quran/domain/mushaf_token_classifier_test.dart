// Tests the GENERIC classification logic in mushaf_token_classifier.dart
// using small synthetic fixtures. This tests the classification mechanism
// itself, never real Mushaf token content — no synthetic Mushaf token data
// is shipped or treated as real anywhere in this project; see
// docs/QURAN_DATA_PROVENANCE.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_token_classifier.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_token_source.dart';

RawMushafToken _tok(int id, int surah, int ayah, int word, String text) =>
    RawMushafToken(
      sourceTokenId: id,
      surahNumber: surah,
      ayahNumber: ayah,
      sourceWordPosition: word,
      displayText: text,
    );

void main() {
  const classifier = MushafTokenClassifier();

  test('an ayah with exactly one extra trailing token gets an ayahMarker', () {
    final raw = [
      _tok(1, 1, 1, 1, 'a'),
      _tok(2, 1, 1, 2, 'b'),
      _tok(3, 1, 1, 3, 'marker'),
    ];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      canonicalWordCountByAyahId: {1001: 2},
    );

    expect(result.warnings, isEmpty);
    expect(result.tokens, hasLength(3));
    expect(result.tokens[0].tokenType, MushafTokenType.quranWord);
    expect(result.tokens[0].canonicalAyahId, 1001);
    expect(result.tokens[0].canonicalWordIndex, 0);
    expect(result.tokens[1].tokenType, MushafTokenType.quranWord);
    expect(result.tokens[1].canonicalWordIndex, 1);
    expect(result.tokens[2].tokenType, MushafTokenType.ayahMarker);
    expect(result.tokens[2].canonicalAyahId, isNull);
    expect(result.tokens[2].canonicalWordIndex, isNull);
  });

  test('an ayah whose token count exactly matches canonical has no marker '
      '(the real 37:130 case)', () {
    final raw = [
      _tok(1, 37, 130, 1, 'a'),
      _tok(2, 37, 130, 2, 'b'),
      _tok(3, 37, 130, 3, 'c'),
      _tok(4, 37, 130, 4, 'd'),
    ];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      canonicalWordCountByAyahId: {37130: 4},
    );

    expect(result.warnings, isEmpty);
    expect(
      result.tokens.every((t) => t.tokenType == MushafTokenType.quranWord),
      isTrue,
    );
    expect(result.tokens.map((t) => t.canonicalWordIndex), [0, 1, 2, 3]);
  });

  test('an unrecognized token-count pattern is marked unknown with a warning, '
      'never guessed at', () {
    final raw = [
      _tok(1, 2, 1, 1, 'a'),
      _tok(2, 2, 1, 2, 'b'),
      _tok(3, 2, 1, 3, 'c'),
    ];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      // Canonical count is 5, but only 3 tokens exist — neither the
      // exact-match nor the +1 pattern applies.
      canonicalWordCountByAyahId: {2001: 5},
    );

    expect(result.warnings, hasLength(1));
    expect(result.warnings.single.surahNumber, 2);
    expect(result.warnings.single.ayahNumber, 1);
    expect(
      result.tokens.every((t) => t.tokenType == MushafTokenType.unknown),
      isTrue,
    );
    expect(result.tokens.every((t) => t.canonicalAyahId == null), isTrue);
  });

  test('an ayah id absent from the canonical dataset is marked unknown with a '
      'warning', () {
    final raw = [_tok(1, 999, 1, 1, 'a')];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      canonicalWordCountByAyahId: const {},
    );

    expect(result.warnings, hasLength(1));
    expect(result.tokens.single.tokenType, MushafTokenType.unknown);
  });

  test('sequenceIndex tracks position in the given raw-token order', () {
    final raw = [_tok(10, 1, 1, 1, 'a'), _tok(11, 1, 1, 2, 'b')];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      canonicalWordCountByAyahId: {1001: 2},
    );
    expect(result.tokens[0].sequenceIndex, 0);
    expect(result.tokens[0].sourceTokenId, 10);
    expect(result.tokens[1].sequenceIndex, 1);
    expect(result.tokens[1].sourceTokenId, 11);
  });

  test('never produces otherMarker without evidence for it', () {
    final raw = [_tok(1, 1, 1, 1, 'a'), _tok(2, 1, 1, 2, 'marker')];
    final result = classifier.classify(
      mushafId: 1,
      rawTokens: raw,
      canonicalWordCountByAyahId: {1001: 1},
    );
    expect(
      result.tokens.any((t) => t.tokenType == MushafTokenType.otherMarker),
      isFalse,
    );
  });
}
