import 'package:flutter/widgets.dart'
    show Widget, ValueChanged, VoidCallback, Color;

import '../../../../quran/domain/models/quran_refs.dart';
import '../../presentation/mushaf_token_hit_rect.dart' show MushafTokenHitRect;

/// A thin, platform-independent facade over Quran.ws's "Quran Engine"
/// (`https://github.com/quran-ws/quran-engine`), promoted from the
/// `poc/quran-engine` branch's evaluation
/// (`docs/poc/QURAN_ENGINE_POC.md`) into Tahfeez's production Mushaf
/// renderer — see `docs/QURAN_ENGINE_MIGRATION.md`. Quran Engine is now
/// the **only** Mushaf rendering backend (the former QPC V2 renderer was
/// removed once this migration completed).
///
/// Two implementations exist, chosen by `mushafQuranEngineBackendProvider`'s
/// single platform branch: `QuranEngineAndroidBackend` (Android, via the
/// official `qvp_flutter` wrapper) and `QuranEngineWebBackend` (Web, via
/// the official `qvp.js`/WASM wrapper).
///
/// Every hit this backend reports comes back as Tahfeez's own
/// [MushafTokenHitRect] — the same type `MushafPager`/`MushafPageView`
/// consume regardless of platform, so neither of those files needs to
/// know which platform's adapter actually drew the page. Word/ayah
/// *targets* (for highlight/mask) are expressed with Tahfeez's own
/// canonical [WordRef]/[VerseRef]
/// (`lib/quran/domain/models/quran_refs.dart`), translated to/from Quran
/// Engine's own key format exclusively by [QuranEngineRefAdapter]
/// (`../quran_engine_ref_adapter.dart`) — never parsed ad hoc here or in
/// any concrete implementation.
abstract class QuranEngineMushafBackend {
  /// Human-readable identification of the concrete Quran Engine build this
  /// backend wraps — for diagnostics only, never used for logic.
  Future<String> initialize();

  /// Loads [pageNumber]'s Quran Engine page data. Throws if the page's data
  /// isn't available for the current platform/configuration.
  Future<QuranEngineMushafPage> loadPage(int pageNumber);

  void disposePage(QuranEngineMushafPage page);

  /// Fire-and-forget warmup of [pageNumber]'s neighbors. Meaningful only
  /// for a backend with a real transport cost per page (Web, fetching
  /// over HTTP); a backend serving from bundled local assets (Android)
  /// may no-op this. Never awaited by a caller, and a failing/slow
  /// neighbor must never affect the page actually on screen.
  Future<void> preloadAround(int pageNumber, {int radius = 1});
}

/// One loaded Quran Engine page. [buildView] returns the actual platform
/// widget that draws it — the engine's own official widget/canvas, never a
/// Tahfeez-reimplemented renderer.
abstract class QuranEngineMushafPage {
  int get pageNumber;

  /// The page's own natural aspect ratio (width / height) — callers size
  /// this page's container to preserve it (uniform scale, never
  /// independent X/Y stretch).
  double get aspectRatio;

  /// Builds the rendering + gesture-handling widget for this page, themed
  /// from [ink]/[paper] (mapped directly from `MushafAppearanceColors.text`/
  /// `.background` at the one call site,
  /// `QuranEngineMushafPageContent.build` in
  /// `../../presentation/quran_engine_mushaf_page_content.dart`).
  /// [onWordHit]/[onDecorationHit] fire with [MushafTokenHitRect];
  /// [onWordLongHit] on a long press on a word (Android only for now).
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  });

  /// Highlights [target] (a [WordRef] or [VerseRef]) — 'band' is the only
  /// mode this migration currently exercises (selected/current-word style
  /// highlighting for future audio/memorization use).
  int highlightWord(WordRef target, {String mode = 'band'});
  int highlightAyah(VerseRef target, {String mode = 'band'});

  void clearHighlights();

  /// Masks (hides) [target] for memorization practice.
  void maskWord(WordRef target, {String mode = 'hide'});
  void maskAyah(VerseRef target, {String mode = 'hide'});

  /// Reveals the next [count] currently-masked word(s), in reading order.
  void revealNext([int count = 1]);

  void unmask();

  /// Memorization "hide" mode: hides every word on the page — ayah-end
  /// markers/numbers, Surah headers and other decorations stay visible —
  /// then uncovers the first [revealedWords] words in reading order
  /// (starting from the first word of the page's first ayah).
  /// `hidden: false` shows the whole page again. Idempotent: callers pass
  /// the full desired state every time.
  void setMemorizationMask({required bool hidden, int revealedWords = 0});

  /// Number of words on this page — the most [setMemorizationMask] can
  /// reveal.
  int get wordCount;

  /// Where each ayah on this page ends, as a count of the page's words in
  /// reading order: for the first ayah on the page, the second, and so
  /// on — e.g. `[4, 21, 58]`. The last entry equals [wordCount].
  List<int> get ayahWordBoundaries;

  /// The first and last ayah with words on this page, from the engine's own
  /// per-word surah/ayah data; `null` for a page without words.
  ({VerseRef first, VerseRef last})? get verseSpan;

  /// This page's words as canonical refs, in the engine's reading order:
  /// index i is the engine's page-local word index i.
  List<WordRef> get wordRefs;

  /// Hides exactly the page words at the [hidden] engine word indices;
  /// every other word, and every ayah marker/decoration, stays visible.
  /// Replaces any previous mask (including [setMemorizationMask]'s).
  void setHiddenWords(Set<int> hidden);

  /// Highlights the page word at engine index [wordIndex] with a band of
  /// [color] — drawn even where the word itself is hidden. Returns the
  /// highlight handle.
  int highlightWordAt(int wordIndex, {required Color color});

  /// Replaces every highlight on the page at once: first the [bands] —
  /// each one seamless band (no darker seams where words meet), reaching
  /// into the gaps between lines ([PageBand]) — then,
  /// for each engine word index in [highlights], a [color] either as a
  /// band behind the word or, with `ink`, on the word's own letters. One
  /// repaint for the whole set.
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights, {
    List<PageBand> bands = const [],
  });

  void dispose();
}

/// A tint behind part of a page, drawn as one seamless band: a run of
/// whole ayahs of one surah ([surah], [fromAyah]..[toAyah], their ayah-end
/// markers included), or else a set of engine word indices ([words]).
/// Filling its lines' whole height, so a passage's lines meet with no gaps:
/// on Android each line's full layout slot (qvp_flutter patch 0003); on the
/// web, [fill] of the line pitch above and below.
class PageBand {
  const PageBand.ayahs(this.surah, this.fromAyah, this.toAyah, this.color)
    : words = const [];

  const PageBand.words(this.words, this.color)
    : surah = 0,
      fromAyah = 0,
      toAyah = 0;

  final int surah, fromAyah, toAyah;
  final List<int> words;
  final Color color;

  bool get isAyahs => surah > 0;

  /// The web: the share of the line pitch each band reaches past its
  /// line's top and bottom.
  static const fill = 0.5;
}

/// A short animation on one word of a page: a recitation's feedback.
enum MushafWordEffect {
  /// A soft glow behind the word, spreading as it fades (a word recited
  /// right; a page complete).
  bloom,

  /// The word's coloured ink sways sideways a few times (a mistake).
  shake,

  /// The word's ink fades in (a hidden word revealed).
  inkIn,

  /// The word's ink fades into the paper (before it is hidden), over
  /// [MushafWordEffect.inkOutTime].
  inkOut;

  /// How long [inkOut] takes to reach the paper.
  static const inkOutTime = Duration(milliseconds: 400);
}

/// A [QuranEngineMushafPage] that can animate its words ([MushafWordEffect]):
/// Android's. Pages without one simply show the marks.
abstract interface class MushafWordEffectsPage {
  /// Plays [effect] on the page word at engine index [wordIndex] (in
  /// [color], for a [MushafWordEffect.bloom] — with a band behind the word
  /// unless not [halo], a glow around its letters unless not [letters]),
  /// after [delay].
  void playWordEffect(
    int wordIndex,
    MushafWordEffect effect, {
    Color? color,
    Duration delay = Duration.zero,
    bool halo = true,
    bool letters = true,
  });
}
