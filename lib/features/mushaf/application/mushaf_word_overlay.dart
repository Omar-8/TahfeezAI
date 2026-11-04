import 'package:flutter/foundation.dart' show immutable, mapEquals, setEquals;
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

/// Every word [overlay] marks with a mistake, in reading order.
List<WordRef> markedMistakes(MushafWordOverlay? overlay) => [
  for (final MapEntry(key: word, value: mark)
      in (overlay?.marks ?? const <WordRef, MushafWordMark>{}).entries)
    if (mushafMistakeMarks.contains(mark)) word,
]..sort(compareWordRefs);

/// The first word [overlay] marks with a mistake (in ayah [ayahId] only,
/// if given); `null` without one.
WordRef? firstMarkedMistake(MushafWordOverlay? overlay, {int? ayahId}) {
  WordRef? first;
  for (final MapEntry(key: word, value: mark)
      in (overlay?.marks ?? const {}).entries) {
    if (!mushafMistakeMarks.contains(mark)) continue;
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

class MushafWordOverlayController extends Notifier<MushafWordOverlay?> {
  late MushafProgressStore _store;

  /// The colours shown are a finished recitation's from before the app was
  /// last closed (restored), not one of this run's.
  bool restored = false;

  @override
  MushafWordOverlay? build() {
    // A finished recitation's colours are kept on the phone (a recitation
    // under way, or none, clears them) and shown again when the app starts.
    _store = MushafProgressStore(ref.read(browserStorageProvider));
    if (MushafProgressStore.restoreOnce(MushafProgressStore.resultsKey)) {
      _store.loadResults().then((saved) {
        if (saved == null || !ref.mounted || state != null) return;
        restored = true;
        state = saved;
      });
    }
    return null;
  }

  void set(MushafWordOverlay? overlay) {
    if (!ref.mounted || overlay == state) return;
    restored = false;
    state = overlay;
    _store.saveResults(
      overlay != null && overlay.followHideMode && !overlay.hideUnrevealed
          ? overlay
          : null,
    );
  }
}

final mushafWordOverlayProvider =
    NotifierProvider<MushafWordOverlayController, MushafWordOverlay?>(
      MushafWordOverlayController.new,
    );
