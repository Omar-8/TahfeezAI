import 'dart:async';

import 'package:flutter/foundation.dart'
    show immutable, listEquals, mapEquals, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../quran/domain/models/quran_refs.dart';
import 'mushaf_progress_store.dart';

/// Reading order of canonical words (ayah ids are `chapter*1000+verse`, so
/// comparing them compares surah first, then ayah).
int compareWordRefs(WordRef a, WordRef b) =>
    a.ayahId != b.ayahId ? a.ayahId - b.ayahId : a.wordIndex - b.wordIndex;

/// How a word is marked on the page.
enum MushafWordMark {
  /// The word to recite next (a band behind it).
  current,

  /// The next word, with a mistake on it awaiting correction (a red band).
  mistake,

  /// A recited word, colored by how it went.
  correct,
  skipped,
  wrong,

  /// Recited as the right word, but the audio heard a pronunciation
  /// mistake in it (a vowel, sukun, shadda or letter).
  tashkeel,

  /// Recited as the right word, its letters and vowels right, but a tajweed
  /// rule not kept (a hidden or merged nūn said plainly, a qalqala echo or
  /// madd missing, a ghunnah not held).
  tajweed,

  /// A likely pronunciation mistake: the word's quick check heard one, its
  /// ayah's check (which confirms it as [tashkeel] or clears it) is still
  /// to come. A softer colour, no alert.
  checking,

  /// The audio could not confirm its pronunciation either way.
  uncertain,
}

/// The marks of a mistake (a word's sheet says what it was).
const mushafMistakeMarks = {
  MushafWordMark.mistake,
  MushafWordMark.skipped,
  MushafWordMark.wrong,
  MushafWordMark.tashkeel,
  MushafWordMark.tajweed,
};

/// The mistakes last looked at (a word sheet opened on one of them): the
/// bar's "Mistakes found" gone for them, back for a recitation's new ones.
class MistakesSeen extends Notifier<List<WordRef>> {
  @override
  List<WordRef> build() => const [];

  void seen(List<WordRef> mistakes) {
    if (!listEquals(state, mistakes)) state = List.unmodifiable(mistakes);
  }
}

final mistakesSeenProvider = NotifierProvider<MistakesSeen, List<WordRef>>(
  MistakesSeen.new,
);

/// Whether [word] is in [overlay]'s range: the recitation's under way, or
/// the latest one's (the colours kept from others are outside it).
bool _inRange(MushafWordOverlay overlay, WordRef word) =>
    compareWordRefs(word, overlay.first) >= 0 &&
    compareWordRefs(word, overlay.last) <= 0;

/// Every word [overlay] marks with a mistake in its range (the recitation
/// under way, or the latest one), in reading order.
List<WordRef> markedMistakes(MushafWordOverlay? overlay) => [
  if (overlay != null)
    for (final MapEntry(key: word, value: mark) in overlay.marks.entries)
      if (mushafMistakeMarks.contains(mark) && _inRange(overlay, word)) word,
]..sort(compareWordRefs);

/// The first word [overlay] marks with a mistake in its range (in ayah
/// [ayahId] only, if given); `null` without one.
WordRef? firstMarkedMistake(MushafWordOverlay? overlay, {int? ayahId}) {
  if (overlay == null) return null;
  WordRef? first;
  for (final MapEntry(key: word, value: mark) in overlay.marks.entries) {
    if (!mushafMistakeMarks.contains(mark) || !_inRange(overlay, word)) {
      continue;
    }
    if (ayahId != null && word.ayahId != ayahId) continue;
    if (first == null || compareWordRefs(word, first) < 0) first = word;
  }
  return first;
}

/// Words hidden across a range of the Mushaf (except [revealed] ones), and
/// marks drawn on individual words — set by a memorization test (Hifz
/// mode) and applied by every rendered page. Takes precedence over hide
/// mode while set.
@immutable
class MushafWordOverlay {
  const MushafWordOverlay({
    required this.first,
    required this.last,
    this.revealed = const {},
    this.marks = const {},
    this.hideUnrevealed = true,
    this.followHideMode = false,
    this.showBefore = false,
    this.heard = const {},
    this.corrected = const {},
    this.inks = const {},
  });

  /// Marks drawn in a colour the reader chose (ARGB) instead of the page's
  /// own: a pronunciation and a tajweed mistake (Hifz settings).
  final Map<MushafWordMark, int> inks;

  /// For a word marked wrong: what was heard in its place (phonetic).
  final Map<WordRef, String> heard;

  /// Words said wrong at first, then corrected.
  final Set<WordRef> corrected;

  /// Words are hidden as hide mode hides them, not by [revealed] — a
  /// finished recitation's colours, kept on a page the reciter may go on
  /// uncovering.
  final bool followHideMode;

  /// Words before [first] are never hidden (Follow along: the ayahs before
  /// the one being recited stay readable).
  final bool showBefore;

  final WordRef first, last;
  final Set<WordRef> revealed;
  final Map<WordRef, MushafWordMark> marks;

  /// Whether words not yet [revealed] are hidden. `false`: the page stays
  /// fully visible and only [marks] are drawn.
  final bool hideUnrevealed;

  /// With [hideUnrevealed], every word not revealed is hidden — on every
  /// page, inside or outside the range.
  /// (With [showBefore], not those before [first].)
  bool isHidden(WordRef ref) =>
      hideUnrevealed &&
      !revealed.contains(ref) &&
      !(showBefore && compareWordRefs(ref, first) < 0);

  @override
  bool operator ==(Object other) =>
      other is MushafWordOverlay &&
      other.first == first &&
      other.last == last &&
      other.hideUnrevealed == hideUnrevealed &&
      other.followHideMode == followHideMode &&
      other.showBefore == showBefore &&
      mapEquals(other.heard, heard) &&
      setEquals(other.corrected, corrected) &&
      setEquals(other.revealed, revealed) &&
      mapEquals(other.marks, marks) &&
      mapEquals(other.inks, inks);

  @override
  int get hashCode => Object.hash(first, last, revealed.length, marks.length);
}

/// The colours of the recitations finished on the Mushaf — each word's from
/// the last one that recited it — kept on the phone and shown on every
/// page (owner, 2026-11-07: "retain the session results … even if i leave
/// the page or go to another surah or close the app"), each word's until
/// it is recited again. The eye can hide every colour (see
/// [mushafColoursShownProvider]); they are still kept.
@immutable
class KeptMarks {
  const KeptMarks({
    this.marks = const {},
    this.heard = const {},
    this.corrected = const {},
    this.inks = const {},
    this.from,
    this.to,
  });

  final Map<WordRef, MushafWordMark> marks;

  final Map<WordRef, String> heard;
  final Set<WordRef> corrected;
  final Map<MushafWordMark, int> inks;

  /// The latest recitation's first and last marked words: its mistakes
  /// are the ones the bar's "Mistakes found", the results and the word
  /// sheet's "1 / 3" go through.
  final WordRef? from, to;

  static const empty = KeptMarks();

  /// The marks of a word's result, kept (not the band of the moment).
  static bool keeps(MushafWordMark mark) =>
      mark != MushafWordMark.current &&
      mark != MushafWordMark.mistake &&
      mark != MushafWordMark.checking;

  KeptMarks withLatest(Iterable<WordRef> words) {
    WordRef? from, to;
    for (final w in words) {
      if (from == null || compareWordRefs(w, from) < 0) from = w;
      if (to == null || compareWordRefs(w, to) > 0) to = w;
    }
    return KeptMarks(
      marks: marks,
      heard: heard,
      corrected: corrected,
      inks: inks,
      from: from,
      to: to,
    );
  }

  /// [result]'s words recolored as it marks them; the rest as they were.
  KeptMarks merged(MushafWordOverlay result) {
    final marks = {
      for (final e in result.marks.entries)
        if (keeps(e.value)) e.key: e.value,
    };
    if (marks.isEmpty) return this;
    return KeptMarks(
      marks: {...this.marks, ...marks},
      heard: {
        for (final e in heard.entries)
          if (!marks.containsKey(e.key)) e.key: e.value,
        for (final e in result.heard.entries)
          if (marks.containsKey(e.key)) e.key: e.value,
      },
      corrected: {
        ...corrected.where((w) => !marks.containsKey(w)),
        ...result.corrected.where(marks.containsKey),
      },
      inks: result.inks,
    ).withLatest(marks.keys);
  }

  /// Whether a word from [from] to [to] is marked.
  bool anyIn(WordRef from, WordRef to) => marks.keys.any(
    (w) => compareWordRefs(w, from) >= 0 && compareWordRefs(w, to) <= 0,
  );
}

/// Whether recitation colours are drawn at all — the eye's: in colour (the
/// default), or plain (reciting without any: owner, 2026-11-07). Hidden,
/// they are still kept, and a recitation's still replace them. Kept on the
/// phone.
class MushafColoursShown extends Notifier<bool> {
  MushafColoursShown({this.initial = true});

  final bool initial;
  late MushafProgressStore _store;

  @override
  bool build() {
    _store = MushafProgressStore(ref.read(browserStorageProvider));
    if (MushafProgressStore.restoreOnce(MushafProgressStore.coloursKey)) {
      _store.loadColoursShown().then((shown) {
        if (shown != null && ref.mounted) state = shown;
      });
    }
    return initial;
  }

  void set(bool shown) {
    if (state == shown) return;
    state = shown;
    unawaited(_store.saveColoursShown(shown));
  }
}

final mushafColoursShownProvider = NotifierProvider<MushafColoursShown, bool>(
  MushafColoursShown.new,
);

class MushafWordOverlayController extends Notifier<MushafWordOverlay?> {
  late MushafProgressStore _store;

  /// The overlay of a recitation under way ([set]), drawn over [kept].
  MushafWordOverlay? _live;
  KeptMarks _kept = KeptMarks.empty;

  /// Kept colours shown (Hifz settings: words colored, mistakes shown).
  bool _showKept = true, _keptMistakes = true;
  Timer? _save;
  bool _coloursShown = true;

  KeptMarks get kept => _kept;

  @override
  MushafWordOverlay? build() {
    // The colours kept are on the phone, shown again when the app starts.
    _store = MushafProgressStore(ref.read(browserStorageProvider));
    ref.onDispose(() => _save?.cancel());
    // (The eye's: colours drawn or not.)
    _coloursShown = ref.read(mushafColoursShownProvider);
    ref.listen(mushafColoursShownProvider, (_, shown) {
      _coloursShown = shown;
      _publish();
    });
    if (MushafProgressStore.restoreOnce(MushafProgressStore.keptKey)) {
      _store.loadKept().then((saved) {
        if (saved == null || !ref.mounted || _kept.marks.isNotEmpty) return;
        _kept = saved;
        _publish();
      });
    }
    return null;
  }

  /// A recitation's overlay (`null`: none under way). A finished one's
  /// colours ([MushafWordOverlay.followHideMode], the page visible) are
  /// kept, its words' earlier colours replaced.
  void set(MushafWordOverlay? overlay) {
    if (!ref.mounted) return;
    if (overlay != null && overlay.followHideMode && !overlay.hideUnrevealed) {
      _live = null;
      final kept = _kept.merged(overlay);
      if (!identical(kept, _kept)) {
        _kept = kept;
        _saveSoon();
      }
    } else {
      _live = overlay;
    }
    _publish();
  }

  /// How the Hifz settings show the kept colours.
  void showKept({required bool words, required bool mistakes}) {
    if (_showKept == words && _keptMistakes == mistakes) return;
    _showKept = words;
    _keptMistakes = mistakes;
    if (ref.mounted) _publish();
  }

  void _saveSoon() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 300), () {
      unawaited(_store.saveKept(_kept));
    });
  }

  /// The overlay drawn: a recitation's under way, with the kept colours
  /// before its first word (not on words it hides) — those from its start
  /// on are its own to color; with none under way, the kept colours.
  void _publish() {
    final live = _live;
    final kept = _shown();
    final MushafWordOverlay? next;
    if (live != null) {
      final before = _before(kept, live.first);
      next = MushafWordOverlay(
        first: live.first,
        last: live.last,
        revealed: live.revealed,
        // Colours off: the current word's band only, as in colour (a
        // pending mistake's too, as the next word's) — the reciter followed,
        // no trail, nothing judged (owner, 2026-11-08).
        marks: !_coloursShown
            ? {
                for (final e in live.marks.entries)
                  if (e.value == MushafWordMark.current ||
                      e.value == MushafWordMark.mistake)
                    e.key: MushafWordMark.current,
              }
            : {
                // (Hiding every word not revealed: only the revealed ones'.)
                if (live.hideUnrevealed && !live.showBefore)
                  for (final w in live.revealed) w: ?before[w],
                if (!live.hideUnrevealed || live.showBefore) ...before,
                ...live.marks,
              },
        hideUnrevealed: live.hideUnrevealed,
        followHideMode: live.followHideMode,
        showBefore: live.showBefore,
        heard: {..._kept.heard, ...live.heard},
        corrected: {..._kept.corrected, ...live.corrected},
        inks: live.inks,
      );
    } else if (kept.isEmpty || !_coloursShown) {
      next = null;
    } else {
      // Its range the latest recitation's: its mistakes the ones gone
      // through (those shown).
      next = MushafWordOverlay(
        first: _kept.from ?? nowhere,
        last: _kept.to ?? nowhere,
        marks: kept,
        hideUnrevealed: false,
        followHideMode: true,
        heard: _kept.heard,
        corrected: _kept.corrected,
        inks: _kept.inks,
      );
    }
    if (next != state) state = next;
  }

  /// No word: the range of kept colours without a latest recitation.
  static const nowhere = (ayahId: 0, wordIndex: 0);

  (KeptMarks, bool, bool, Map<WordRef, MushafWordMark>)? _shownCache;
  (Map<WordRef, MushafWordMark>, WordRef, Map<WordRef, MushafWordMark>)?
  _beforeCache;

  /// The kept colours as the settings show them.
  Map<WordRef, MushafWordMark> _shown() {
    final cache = _shownCache;
    if (cache != null &&
        identical(cache.$1, _kept) &&
        cache.$2 == _showKept &&
        cache.$3 == _keptMistakes) {
      return cache.$4;
    }
    final shown = !_showKept
        ? const <WordRef, MushafWordMark>{}
        : _keptMistakes
        ? _kept.marks
        : {
            for (final e in _kept.marks.entries)
              if (!mushafMistakeMarks.contains(e.value) &&
                  e.value != MushafWordMark.uncertain)
                e.key: e.value,
          };
    _shownCache = (_kept, _showKept, _keptMistakes, shown);
    return shown;
  }

  /// [kept]'s colours before [first] (a recitation's start: worked out
  /// once, not for each word it hears).
  Map<WordRef, MushafWordMark> _before(
    Map<WordRef, MushafWordMark> kept,
    WordRef first,
  ) {
    final cache = _beforeCache;
    if (cache != null && identical(cache.$1, kept) && cache.$2 == first) {
      return cache.$3;
    }
    final before = {
      for (final e in kept.entries)
        if (compareWordRefs(e.key, first) < 0) e.key: e.value,
    };
    _beforeCache = (kept, first, before);
    return before;
  }
}

final mushafWordOverlayProvider =
    NotifierProvider<MushafWordOverlayController, MushafWordOverlay?>(
      MushafWordOverlayController.new,
    );
