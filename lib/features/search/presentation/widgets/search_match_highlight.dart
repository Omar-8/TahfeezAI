import 'package:flutter/material.dart';

/// Wraps every case-insensitive occurrence of any of [tokens] in [text]
/// with [highlightStyle] — this milestone's "clear ... states" polish for
/// result rows, independently designed (styling itself is
/// `NEEDS_VERIFICATION` in `docs/reference/07_SEARCH_SPEC.md` §9, so
/// Tahfeez does not copy anything here).
///
/// Only used for Latin-script (translation) text: token positions are
/// found by direct case-insensitive substring search, which only lines up
/// with the *displayed* canonical text when normalization does not change
/// character positions/counts. `SearchNormalizer.normalizeLatin` only
/// lowercases and collapses whitespace, so this holds for translations.
/// It does **not** hold for Arabic text (`SearchNormalizer.normalizeArabic`
/// strips diacritics and folds letters, changing the text), so Arabic
/// results are rendered as plain, unhighlighted canonical text instead —
/// a deliberate scope trim, not an oversight.
List<InlineSpan> highlightMatches(
  String text,
  List<String> tokens,
  TextStyle? baseStyle,
  TextStyle highlightStyle,
) {
  if (tokens.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final lowerText = text.toLowerCase();
  final spans = <InlineSpan>[];
  var cursor = 0;
  while (cursor < text.length) {
    var earliestMatch = -1;
    var earliestLength = 0;
    for (final token in tokens) {
      final index = lowerText.indexOf(token, cursor);
      if (index != -1 && (earliestMatch == -1 || index < earliestMatch)) {
        earliestMatch = index;
        earliestLength = token.length;
      }
    }
    if (earliestMatch == -1) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
      break;
    }
    if (earliestMatch > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, earliestMatch), style: baseStyle),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(earliestMatch, earliestMatch + earliestLength),
        style: highlightStyle,
      ),
    );
    cursor = earliestMatch + earliestLength;
  }
  return spans;
}
