import 'models/mushaf_token_models.dart';
import 'mushaf_token_source.dart';

/// One thing [MushafTokenClassifier] could not classify with confidence,
/// surfaced rather than silently guessed at — see its doc comment.
class MushafTokenClassificationWarning {
  const MushafTokenClassificationWarning({
    required this.surahNumber,
    required this.ayahNumber,
    required this.message,
  });

  final int surahNumber;
  final int ayahNumber;
  final String message;

  @override
  String toString() => 'Ayah $surahNumber:$ayahNumber — $message';
}

/// The result of classifying one Mushaf token source's raw stream.
class MushafTokenClassificationResult {
  const MushafTokenClassificationResult({
    required this.tokens,
    required this.warnings,
  });

  /// Every token, in the same order [MushafTokenClassifier.classify] was
  /// given its raw tokens in (ascending `sourceTokenId`).
  final List<MushafToken> tokens;

  /// Every ayah [MushafTokenClassifier] could not confidently classify.
  /// Never empty silently — a non-empty list here means some of [tokens]
  /// are [MushafTokenType.unknown] and need a human decision before this
  /// source is treated as production-ready.
  final List<MushafTokenClassificationWarning> warnings;
}

/// Turns a Mushaf token source's raw, unclassified stream
/// (`lib/quran/domain/mushaf_token_source.dart`) into real [MushafToken]s,
/// deciding — per ayah, from the data itself — which tokens are real Quran
/// words and which are something else.
///
/// The rule this milestone's investigation validated against QUL's real
/// KFGQPC V2 word-by-word export (`docs/QURAN_DATA_PROVENANCE.md`):
///
/// - If an ayah's token count equals its canonical [AyahWord] count, every
///   token is [MushafTokenType.quranWord], mapped 1:1 in order.
/// - If an ayah's token count is exactly one more than its canonical count,
///   every token except the *last* is [MushafTokenType.quranWord] (mapped
///   1:1), and the last is [MushafTokenType.ayahMarker] with no canonical
///   mapping — the small ayah-end ornament every printed ayah carries,
///   confirmed present in 6,235 of the Quran's 6,236 ayahs (the sole
///   documented exception, 37:130, has none — this classifier detects that
///   from the data itself via the token-count comparison above, rather
///   than hardcoding that one ayah).
/// - Any other token count for an ayah (or an ayah id the canonical dataset
///   doesn't recognize at all) is a pattern this classifier has never seen
///   validated data for: **every** token for that ayah becomes
///   [MushafTokenType.unknown], and a [MushafTokenClassificationWarning] is
///   recorded — never guessed at, per this project's explicit
///   "do not guess token type aggressively" instruction.
///
/// [MushafTokenType.otherMarker] is never produced by this classifier: no
/// token pattern seen in the currently-vendored QUL data warrants it. It
/// remains part of [MushafTokenType] for a future source that might.
class MushafTokenClassifier {
  const MushafTokenClassifier();

  MushafTokenClassificationResult classify({
    required int mushafId,
    required List<RawMushafToken> rawTokens,
    required Map<int, int> canonicalWordCountByAyahId,
  }) {
    // First pass: decide, per ayah, which position(s) are quranWord vs.
    // ayahMarker vs. unknown — grouping does not reorder rawTokens itself,
    // it only informs the per-token decision made in the second pass below.
    final tokensByAyah = <int, List<RawMushafToken>>{};
    for (final token in rawTokens) {
      final ayahId = token.surahNumber * 1000 + token.ayahNumber;
      tokensByAyah.putIfAbsent(ayahId, () => []).add(token);
    }

    final warnings = <MushafTokenClassificationWarning>[];
    // ayahId -> (quranWordCount, isLastTokenMarker)
    final decisions = <int, (int, bool)>{};
    for (final entry in tokensByAyah.entries) {
      final ayahId = entry.key;
      final group = entry.value;
      final canonicalCount = canonicalWordCountByAyahId[ayahId];
      final surah = ayahId ~/ 1000;
      final ayah = ayahId % 1000;

      if (canonicalCount == null) {
        decisions[ayahId] = (0, false);
        warnings.add(
          MushafTokenClassificationWarning(
            surahNumber: surah,
            ayahNumber: ayah,
            message:
                'No canonical ayah found for this id — all ${group.length} '
                'token(s) marked unknown.',
          ),
        );
      } else if (group.length == canonicalCount) {
        decisions[ayahId] = (canonicalCount, false);
      } else if (group.length == canonicalCount + 1) {
        decisions[ayahId] = (canonicalCount, true);
      } else {
        decisions[ayahId] = (0, false);
        warnings.add(
          MushafTokenClassificationWarning(
            surahNumber: surah,
            ayahNumber: ayah,
            message:
                'Unexpected token count ${group.length} (canonical word '
                'count is $canonicalCount, expected it or +1) — all tokens '
                'marked unknown.',
          ),
        );
      }
    }

    // Second pass: emit one MushafToken per raw token, in original order,
    // using each ayah's position within its own group to decide quranWord
    // vs. ayahMarker vs. unknown.
    final positionWithinAyah = <int, int>{};
    final tokens = <MushafToken>[];
    for (var i = 0; i < rawTokens.length; i++) {
      final raw = rawTokens[i];
      final ayahId = raw.surahNumber * 1000 + raw.ayahNumber;
      final position = positionWithinAyah[ayahId] ?? 0;
      positionWithinAyah[ayahId] = position + 1;

      final (quranWordCount, hasMarker) = decisions[ayahId]!;
      final MushafTokenType tokenType;
      int? canonicalWordIndex;
      int? canonicalAyahId;
      if (position < quranWordCount) {
        tokenType = MushafTokenType.quranWord;
        canonicalWordIndex = position;
        canonicalAyahId = ayahId;
      } else if (hasMarker && position == quranWordCount) {
        tokenType = MushafTokenType.ayahMarker;
      } else {
        tokenType = MushafTokenType.unknown;
      }

      tokens.add(
        MushafToken(
          mushafId: mushafId,
          sourceTokenId: raw.sourceTokenId,
          sequenceIndex: i,
          tokenType: tokenType,
          displayText: raw.displayText,
          surahNumber: raw.surahNumber,
          ayahNumber: raw.ayahNumber,
          sourceWordPosition: raw.sourceWordPosition,
          canonicalWordIndex: canonicalWordIndex,
          canonicalAyahId: canonicalAyahId,
        ),
      );
    }

    return MushafTokenClassificationResult(tokens: tokens, warnings: warnings);
  }
}
