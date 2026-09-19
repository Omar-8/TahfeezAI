import 'package:freezed_annotation/freezed_annotation.dart';

part 'mushaf_token_models.freezed.dart';

/// What one [MushafToken] actually is, as far as Tahfeez can determine from
/// its source data.
///
/// Deliberately **not** just `word`/`marker`: a Mushaf layout's word-id
/// stream can contain more than plain Quran text (confirmed for QUL's
/// KFGQPC V2 word-by-word export — see `docs/QURAN_DATA_PROVENANCE.md`,
/// which every printed ayah ends with a small ayah-number ornament that
/// occupies its own id in the same stream as real words), and a future
/// Mushaf source might contain still other non-lexical print elements
/// (rub-el-hizb marks, sajdah ornaments, etc.) this project has not seen
/// evidence of yet. [unknown] exists so the importer can say "I don't know
/// what this is" instead of guessing — see [MushafTokenClassifier].
enum MushafTokenType {
  /// A real, canonical Quran word — the only type that may carry
  /// [MushafToken.canonicalAyahId]/[MushafToken.canonicalWordIndex].
  quranWord,

  /// The small ayah-end/verse-number ornament every ayah (with one
  /// documented exception) carries as its own token, immediately after its
  /// last real word.
  ayahMarker,

  /// A non-lexical print element identified as *not* a Quran word and *not*
  /// an ayah marker (e.g. a Sajdah or Rub-el-Hizb ornament), once a source
  /// is found to actually contain one. No token in the currently-vendored
  /// QUL data classifies as this — it exists for forward compatibility.
  otherMarker,

  /// The classifier could not determine what this token is from the
  /// source data available (e.g. an ayah whose token count didn't match
  /// any recognized pattern). Reported as an import warning, never
  /// silently treated as a Quran word.
  unknown,
}

/// One entry in a Mushaf edition's exact, ordered printed-token stream —
/// the "printed sequence" authority, distinct from and complementary to
/// [AyahWord] (`lib/quran/domain/models/ayah_models.dart`), which remains
/// the sole authority for canonical Quran word *semantics* (search,
/// sharing, word-by-word translation, AI alignment).
///
/// Named `MushafToken` rather than `MushafWord` deliberately: the id range
/// a Mushaf layout's lines reference is not guaranteed to contain only real
/// words (see [MushafTokenType]'s doc comment), so "word" would overclaim
/// what every entry in this stream actually is.
///
/// [canonicalWordIndex]/[canonicalAyahId] are populated **only** for
/// [MushafTokenType.quranWord] tokens, and only once
/// [MushafTokenClassifier] has validated the mapping is reliable for that
/// ayah (`lib/quran/domain/mushaf_token_classifier.dart`) — an
/// [MushafTokenType.ayahMarker]/[MushafTokenType.otherMarker]/
/// [MushafTokenType.unknown] token never receives a fabricated canonical
/// reference merely to make the relationship total. There is no
/// `canonicalAyahWordId` field: [AyahWord] has no surrogate key of its own
/// (it is identified by the composite `(ayahId, scriptId, wordIndex)`), so
/// [canonicalAyahId] + [canonicalWordIndex] together are already the
/// complete, minimal join key — a separate id would only duplicate them.
@freezed
abstract class MushafToken with _$MushafToken {
  const factory MushafToken({
    required int mushafId,

    /// The exact id this token's source uses (QUL's `words.id`, i.e. the
    /// same value a [MushafLine]'s `first_word_id`/`last_word_id` bounds
    /// reference) — preserved exactly, never renumbered, so a line's word
    /// range always resolves against this id unambiguously.
    required int sourceTokenId,

    /// This token's 0-based position in the full printed sequence (Mushaf
    /// page 1, line 1 first token = 0, monotonically increasing). Equal to
    /// `sourceTokenId - 1` for the current QUL source (whose ids are
    /// already contiguous from 1), but kept as its own field rather than
    /// reusing [sourceTokenId] directly, since a future/alternate source
    /// is not guaranteed to number its own ids as a dense 1-based sequence.
    required int sequenceIndex,
    required MushafTokenType tokenType,

    /// The token's raw display text, exactly as the source provides it
    /// (for QUL: QCF V2 glyph text — private-use/remapped-Unicode
    /// codepoints meaningful only when rendered with that specific page's
    /// own font; see `docs/QURAN_DATA_PROVENANCE.md`).
    required String displayText,
    int? surahNumber,
    int? ayahNumber,

    /// The token's 1-based position within its ayah, exactly as the source
    /// gives it (QUL's `words.word`) — raw provenance data kept for
    /// auditing/debugging the classifier's decisions, not used by any
    /// renderer or repository.
    int? sourceWordPosition,

    /// Set only for [MushafTokenType.quranWord]; joins to
    /// [AyahWord.wordIndex] together with [canonicalAyahId].
    int? canonicalWordIndex,

    /// Set only for [MushafTokenType.quranWord]; joins to [AyahWord.ayahId]
    /// (and [Ayah.id]) together with [canonicalWordIndex].
    int? canonicalAyahId,
  }) = _MushafToken;
}
