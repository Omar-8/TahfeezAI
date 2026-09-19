/// One row of a Mushaf token source's raw data, before classification.
///
/// This is the seam a word/glyph provider (currently: QUL's KFGQPC V2
/// word-by-word export) produces — analogous to [RawMushafLine]'s role for
/// layout data (`lib/quran/domain/mushaf_data_source.dart`), kept as a
/// separate type because a token source and a layout source are genuinely
/// different upstream resources (confirmed: QUL ships them as two
/// independently-downloaded files). [MushafTokenClassifier]
/// (`lib/quran/domain/mushaf_token_classifier.dart`) is the only thing that
/// turns a list of these into real [MushafToken]s.
class RawMushafToken {
  const RawMushafToken({
    required this.sourceTokenId,
    required this.surahNumber,
    required this.ayahNumber,
    required this.sourceWordPosition,
    required this.displayText,
  });

  /// The source's own id for this token (QUL's `words.id`) — the same value
  /// a Mushaf line's `first_word_id`/`last_word_id` bounds reference.
  final int sourceTokenId;
  final int surahNumber;
  final int ayahNumber;

  /// This token's 1-based position within its ayah, exactly as the source
  /// gives it (QUL's `words.word`).
  final int sourceWordPosition;
  final String displayText;
}

/// Where Tahfeez gets a Mushaf edition's raw, ordered token stream from.
///
/// The only implementation as of this milestone reads QUL's KFGQPC V2
/// word-by-word export (`tool/quran_data/src/mushaf_wbw_source.dart`,
/// build-time tooling only — QUL's own download is gated behind a required
/// user login, same as the layout source). No synthetic or placeholder
/// implementation exists or may be created.
abstract class MushafTokenSource {
  /// Every token this source provides, in ascending [RawMushafToken.sourceTokenId]
  /// order.
  Future<List<RawMushafToken>> loadRawTokens();
}
