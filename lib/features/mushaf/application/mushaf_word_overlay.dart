import 'package:flutter/foundation.dart' show immutable, mapEquals, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_refs.dart';

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

  /// A likely pronunciation mistake: the word's quick check heard one, its
  /// ayah's check (which confirms it as [tashkeel] or clears it) is still
  /// to come. A softer colour, no alert.
  checking,

  /// The audio could not confirm its pronunciation either way.
  uncertain,
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
    this.heard = const {},
    this.corrected = const {},
  });

  /// For a word marked wrong: what was heard in its place (phonetic).
  final Map<WordRef, String> heard;

  /// Words said wrong at first, then corrected.
  final Set<WordRef> corrected;

  /// Words are hidden as hide mode hides them, not by [revealed] — a
  /// finished recitation's colours, kept on a page the reciter may go on
  /// uncovering.
  final bool followHideMode;

  final WordRef first, last;
  final Set<WordRef> revealed;
  final Map<WordRef, MushafWordMark> marks;

  /// Whether words not yet [revealed] are hidden. `false`: the page stays
  /// fully visible and only [marks] are drawn.
  final bool hideUnrevealed;

  /// With [hideUnrevealed], every word not revealed is hidden — on every
  /// page, inside or outside the range.
  bool isHidden(WordRef ref) => hideUnrevealed && !revealed.contains(ref);

  @override
  bool operator ==(Object other) =>
      other is MushafWordOverlay &&
      other.first == first &&
      other.last == last &&
      other.hideUnrevealed == hideUnrevealed &&
      other.followHideMode == followHideMode &&
      mapEquals(other.heard, heard) &&
      setEquals(other.corrected, corrected) &&
      setEquals(other.revealed, revealed) &&
      mapEquals(other.marks, marks);

  @override
  int get hashCode => Object.hash(first, last, revealed.length, marks.length);
}

class MushafWordOverlayController extends Notifier<MushafWordOverlay?> {
  @override
  MushafWordOverlay? build() => null;

  void set(MushafWordOverlay? overlay) {
    if (!ref.mounted || overlay == state) return;
    state = overlay;
  }
}

final mushafWordOverlayProvider =
    NotifierProvider<MushafWordOverlayController, MushafWordOverlay?>(
      MushafWordOverlayController.new,
    );
