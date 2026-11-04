import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import 'mushaf_progress_store.dart';

/// The first page on screen for a reported [page]: in a two-page spread
/// the right-hand page is always the odd one (pages 1|2, 3|4, …), whichever
/// of the two the screen reports — opening Al-Baqarah reports page 2 while
/// the spread shows pages 1 and 2.
int firstVisiblePage(int page, {required bool spread}) =>
    spread && page.isEven ? page - 1 : page;

/// Memorization "hide" mode for the Mushaf: every word hidden, ayah markers
/// and numbers left visible, and words uncovered one at a time in reading
/// order from the first word on the page.
class MushafHideModeState {
  const MushafHideModeState({
    this.enabled = false,
    this.revealed = const {},
    this.wordCounts = const {},
    this.ayahBoundaries = const {},
    this.startOn = const {},
    this.lastPage,
  });

  final bool enabled;

  /// Page number → words uncovered on that page (from its first word).
  final Map<int, int> revealed;

  /// Page number → the first word uncovered (words before it stay hidden):
  /// uncovering from a word other than the page's first ("Test me" starts
  /// at its question). Absent: from the page's first word. Revealing goes
  /// on as usual; hiding past it covers the whole page again.
  final Map<int, int> startOn;

  /// The page words were last uncovered or covered on by hand (the
  /// buttons, or an ayah opened with those before it shown); `null` until
  /// then — not kept across restarts.
  final int? lastPage;

  /// The first word uncovered on [pageNumber] (see [startOn]).
  int startOf(int pageNumber) => startOn[pageNumber] ?? 0;

  /// Page number → total words, as reported by each rendered page.
  final Map<int, int> wordCounts;

  /// Page number → where each ayah on it ends, in page words (see
  /// `QuranEngineMushafPage.ayahWordBoundaries`).
  final Map<int, List<int>> ayahBoundaries;

  int revealedOn(int pageNumber) => revealed[pageNumber] ?? 0;

  /// Whether the page's word at [wordIndex] (reading order, from 0) is
  /// currently hidden.
  /// The page a reveal is under way on: [lastPage], while uncovered in
  /// part (some of its words shown, not all); else `null`. Never another
  /// page left part-uncovered earlier (an older session's).
  int? get revealUnderWay {
    final page = lastPage;
    if (page == null) return null;
    final shown = revealedOn(page);
    final total = wordCounts[page];
    if (shown <= 0 || total == null || shown >= total) return null;
    return page;
  }

  bool isWordHidden(int pageNumber, int wordIndex) =>
      enabled &&
      (wordIndex >= revealedOn(pageNumber) || wordIndex < startOf(pageNumber));

  /// Uncovered to the page's end — from its first word, or (with
  /// [startOn]) from where uncovering began: revealing then goes on to
  /// the next page.
  bool fullyRevealed(int pageNumber) {
    final total = wordCounts[pageNumber];
    return total != null && revealedOn(pageNumber) >= total;
  }

  /// The page the next "reveal word" goes to: [currentPage], or — in a
  /// two-page spread, once [currentPage] is fully uncovered — the facing
  /// page. `null` when nothing is left to reveal.
  int? nextRevealPage(int currentPage, {required bool spread}) {
    if (!enabled) return null;
    for (final page in [currentPage, if (spread) currentPage + 1]) {
      // Only pages that are rendered (they report their word count) can
      // be revealed — never one off screen.
      if (wordCounts.containsKey(page) && !fullyRevealed(page)) return page;
    }
    return null;
  }

  /// The page the next "hide word/ayah" goes back on: the last page on
  /// screen with anything uncovered (the facing page first, in a spread).
  /// `null` when everything on screen is already hidden.
  int? previousHidePage(int currentPage, {required bool spread}) {
    if (!enabled) return null;
    for (final page in [if (spread) currentPage + 1, currentPage]) {
      if (_visibleOn(page) > 0) return page;
    }
    return null;
  }

  /// Where the uncovered words on [pageNumber] end, never past its last
  /// word.
  int _shownOn(int pageNumber) {
    final shown = revealedOn(pageNumber);
    final total = wordCounts[pageNumber];
    return total == null || shown <= total ? shown : total;
  }

  /// How many words on [pageNumber] are uncovered (from [startOf]).
  int _visibleOn(int pageNumber) {
    final n = _shownOn(pageNumber) - startOf(pageNumber);
    return n < 0 ? 0 : n;
  }

  MushafHideModeState copyWith({
    bool? enabled,
    Map<int, int>? revealed,
    Map<int, int>? wordCounts,
    Map<int, List<int>>? ayahBoundaries,
    Map<int, int>? startOn,
    int? lastPage,
  }) {
    return MushafHideModeState(
      enabled: enabled ?? this.enabled,
      revealed: revealed ?? this.revealed,
      wordCounts: wordCounts ?? this.wordCounts,
      ayahBoundaries: ayahBoundaries ?? this.ayahBoundaries,
      startOn: startOn ?? this.startOn,
      lastPage: lastPage ?? this.lastPage,
    );
  }
}

class MushafHideModeController extends Notifier<MushafHideModeState> {
  @override
  MushafHideModeState build() {
    // Kept on the phone: hide mode and the words uncovered, as they were
    // when the app was last closed — restored when it starts again.
    final store = MushafProgressStore(ref.read(browserStorageProvider));
    listenSelf((previous, next) {
      if (previous != null &&
          previous.enabled == next.enabled &&
          mapEquals(previous.revealed, next.revealed) &&
          mapEquals(previous.startOn, next.startOn)) {
        return;
      }
      store.saveHide(
        enabled: next.enabled,
        revealed: next.revealed,
        startOn: next.startOn,
      );
    });
    if (MushafProgressStore.restoreOnce(MushafProgressStore.hideKey)) {
      store.loadHide().then((saved) {
        // Only into a state not yet touched (nothing uncovered, hide mode
        // not turned on since the app started).
        if (saved == null || !ref.mounted) return;
        if (state.enabled || state.revealed.isNotEmpty) return;
        state = state.copyWith(
          enabled: saved.enabled,
          revealed: saved.revealed,
          startOn: saved.startOn,
        );
      });
    }
    return const MushafHideModeState();
  }

  /// Turns hide mode on or off. Either way every page starts over fully
  /// hidden next time it is enabled.
  void toggle() {
    state = MushafHideModeState(
      enabled: !state.enabled,
      wordCounts: state.wordCounts,
      ayahBoundaries: state.ayahBoundaries,
    );
  }

  /// Uncovers one more word — see [MushafHideModeState.nextRevealPage].
  /// Returns the page it was revealed on, or `null`.
  int? revealNextWord(int currentPage, {bool spread = false}) {
    final page = state.nextRevealPage(currentPage, spread: spread);
    if (page == null) return null;
    state = state.copyWith(
      revealed: {...state.revealed, page: state.revealedOn(page) + 1},
      lastPage: page,
    );
    return page;
  }

  /// Uncovers the rest of the ayah the next hidden word belongs to (or the
  /// whole next ayah, when the previous one is fully shown). Returns the
  /// page it was revealed on, or `null`.
  int? revealNextAyah(int currentPage, {bool spread = false}) {
    final page = state.nextRevealPage(currentPage, spread: spread);
    if (page == null) return null;
    final shown = state.revealedOn(page);
    final boundaries = state.ayahBoundaries[page] ?? const <int>[];
    final end = boundaries.firstWhere(
      (b) => b > shown,
      orElse: () => state.wordCounts[page] ?? shown + 1,
    );
    state = state.copyWith(
      revealed: {...state.revealed, page: end},
      lastPage: page,
    );
    return page;
  }

  /// Hides the last uncovered word again. Returns the page it was hidden
  /// on, or `null` when everything on screen is already hidden.
  int? hideLastWord(int currentPage, {bool spread = false}) {
    final page = state.previousHidePage(currentPage, spread: spread);
    if (page == null) return null;
    _hideTo(page, state._shownOn(page) - 1);
    state = state.copyWith(lastPage: page);
    return page;
  }

  /// Hides back to the start of the ayah the last uncovered word belongs to
  /// (or the whole previous ayah, when an ayah is fully shown). Returns the
  /// page it was hidden on, or `null`.
  int? hideLastAyah(int currentPage, {bool spread = false}) {
    final page = state.previousHidePage(currentPage, spread: spread);
    if (page == null) return null;
    final shown = state._shownOn(page);
    final boundaries = state.ayahBoundaries[page] ?? const <int>[];
    final start = boundaries.lastWhere((b) => b < shown, orElse: () => 0);
    _hideTo(page, start);
    state = state.copyWith(lastPage: page);
    return page;
  }

  /// Covers [page] back to word [end]; hidden past where uncovering began
  /// ([MushafHideModeState.startOn]): the whole page covered, as usual.
  void _hideTo(int page, int end) {
    if (end <= state.startOf(page)) {
      state = state.copyWith(
        revealed: {...state.revealed, page: 0},
        startOn: {...state.startOn}..remove(page),
      );
    } else {
      state = state.copyWith(revealed: {...state.revealed, page: end});
    }
  }

  /// Uncovers [count] words of [page] from its word [start] (the words
  /// before it stay covered) — "Test me" at its question.
  void showFrom(int page, {required int start, required int count}) {
    state = state.copyWith(
      revealed: {...state.revealed, page: start + count},
      startOn: {...state.startOn, page: start},
      lastPage: page,
    );
  }

  /// Marks [pages] fully uncovered — used when going back to a previous
  /// page, which is then hidden again from its end. A page whose word count
  /// isn't known yet is clamped once it reports it.
  void revealPagesFully(Iterable<int> pages) {
    state = state.copyWith(
      revealed: {
        ...state.revealed,
        for (final page in pages) page: state.wordCounts[page] ?? _allWords,
      },
      startOn: {...state.startOn}..removeWhere((p, _) => pages.contains(p)),
    );
  }

  /// Sets how many words are uncovered on each page in [revealed] (from
  /// its first word) — used to carry a recitation test's progress back
  /// into hide mode.
  /// Uncovering goes on at [page] (an ayah opened there): its
  /// [MushafHideModeState.lastPage].
  void goOnAt(int page) {
    if (state.lastPage != page) state = state.copyWith(lastPage: page);
  }

  /// ([lastPage]: uncovered there by hand — see
  /// [MushafHideModeState.lastPage].)
  void setRevealed(Map<int, int> revealed, {int? lastPage}) {
    state = state.copyWith(
      revealed: {...state.revealed, ...revealed},
      startOn: {...state.startOn}
        ..removeWhere((p, _) => revealed.containsKey(p)),
      lastPage: lastPage,
    );
  }

  /// Sets the words uncovered on each page in [shown]: from its word
  /// `start` (the words before it stay covered) to before its word `end` —
  /// a recitation test begun mid-page carried back into hide mode.
  void setShown(Map<int, ({int start, int end})> shown) {
    state = state.copyWith(
      revealed: {
        ...state.revealed,
        for (final MapEntry(key: page, value: run) in shown.entries)
          page: run.end,
      },
      startOn: {
        for (final MapEntry(key: page, value: start) in state.startOn.entries)
          if (!shown.containsKey(page)) page: start,
        for (final MapEntry(key: page, value: run) in shown.entries)
          if (run.start > 0 && run.end > run.start) page: run.start,
      },
    );
  }

  /// Stand-in for "every word" before a page has reported its count.
  static const _allWords = 1 << 20;

  /// Called by each rendered page once it knows its words.
  void reportPageWords(
    int pageNumber, {
    required int wordCount,
    List<int> ayahBoundaries = const [],
  }) {
    if (state.wordCounts[pageNumber] == wordCount &&
        listEquals(state.ayahBoundaries[pageNumber], ayahBoundaries)) {
      return;
    }
    final revealed = state.revealedOn(pageNumber);
    state = state.copyWith(
      wordCounts: {...state.wordCounts, pageNumber: wordCount},
      ayahBoundaries: {...state.ayahBoundaries, pageNumber: ayahBoundaries},
      revealed: revealed > wordCount
          ? {...state.revealed, pageNumber: wordCount}
          : null,
    );
  }
}

final mushafHideModeProvider =
    NotifierProvider<MushafHideModeController, MushafHideModeState>(
      MushafHideModeController.new,
    );
