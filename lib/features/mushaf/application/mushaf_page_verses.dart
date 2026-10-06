import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_refs.dart';

/// First and last ayah on a Mushaf page.
typedef MushafPageVerseSpan = ({VerseRef first, VerseRef last});

/// Page number → the ayahs it shows, as reported by each rendered page
/// (from Quran Engine's own per-word data — the production renderer, so
/// this works in every build, unlike the dev-only page-layout tables).
/// Used to start live recitation matching at the visible page.
class MushafPageVerses extends Notifier<Map<int, MushafPageVerseSpan>> {
  @override
  Map<int, MushafPageVerseSpan> build() => const {};

  void report(int pageNumber, MushafPageVerseSpan span) {
    if (state[pageNumber] == span) return;
    state = {...state, pageNumber: span};
  }
}

final mushafPageVersesProvider =
    NotifierProvider<MushafPageVerses, Map<int, MushafPageVerseSpan>>(
      MushafPageVerses.new,
    );

/// First and last word on a Mushaf page (a page may start or end
/// mid-ayah).
typedef MushafPageWordRange = ({WordRef first, WordRef last});

/// Page number → its exact first and last word, as reported by each
/// rendered page from Quran Engine's own word list.
class MushafPageWordRanges extends Notifier<Map<int, MushafPageWordRange>> {
  @override
  Map<int, MushafPageWordRange> build() => const {};

  void report(int pageNumber, MushafPageWordRange range) {
    if (state[pageNumber] == range) return;
    state = {...state, pageNumber: range};
  }
}

final mushafPageWordRangesProvider =
    NotifierProvider<MushafPageWordRanges, Map<int, MushafPageWordRange>>(
      MushafPageWordRanges.new,
    );
