import 'dart:async' show Timer, unawaited;

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/foundation.dart' show mapEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mushaf_focus_ayah.dart';
import '../application/mushaf_hide_mode.dart';
import '../application/mushaf_page_verses.dart';
import '../application/mushaf_passages.dart';
import '../application/mushaf_word_overlay.dart';
import '../../recitation/application/hifz_controller.dart';
import '../application/mushaf_quran_engine_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'mushaf_token_hit_rect.dart';

/// Renders one Mushaf page through Quran Engine
/// (`mushafQuranEngineBackendProvider`'s Android/Web adapter, chosen by
/// platform) — Tahfeez's Mushaf rendering backend since the Quran Engine
/// migration completed (`docs/QURAN_ENGINE_MIGRATION.md`). Reports
/// word/decoration taps as [MushafTokenHitRect], the same type
/// `MushafPager`'s tap handling already consumes.
///
/// Colors come only from [MushafAppearanceColors] — never
/// `Theme.of(context)` — matching every other Mushaf-mode rule.
class QuranEngineMushafPageContent extends ConsumerStatefulWidget {
  const QuranEngineMushafPageContent({
    super.key,
    required this.pageNumber,
    required this.colors,
    this.onWordTap,
    this.onWordLongPress,
  });

  final int pageNumber;
  final MushafAppearanceColors colors;
  final ValueChanged<MushafTokenHitRect>? onWordTap;

  /// A long press on a word: its ayah is highlighted until the returned
  /// future completes (the ayah sheet is closed).
  final Future<void> Function(MushafTokenHitRect hit)? onWordLongPress;

  @override
  ConsumerState<QuranEngineMushafPageContent> createState() =>
      _QuranEngineMushafPageContentState();
}

class _QuranEngineMushafPageContentState
    extends ConsumerState<QuranEngineMushafPageContent> {
  QuranEngineMushafBackend? _backend;
  QuranEngineMushafPage? _page;
  Object? _loadError;
  bool _loading = false;

  /// The eye's hiding, applied once the words have faded into the paper.
  Timer? _maskLater;

  /// The phone's "remove animations": no word effects.
  bool get _calm =>
      mounted && (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// The hide-mode state last applied to [_page], so changes to other
  /// pages' reveal progress don't re-apply this one.
  ({bool hidden, int revealed})? _appliedMask;

  /// The word overlay (Hifz mode) last applied: hidden engine word indices
  /// and marks. `null` while no overlay is on this page.
  (Set<int>, Map<int, MushafWordMark>)? _appliedOverlay;

  /// Bands behind the next word; ink colours on recited words.
  static const _markStyles = {
    MushafWordMark.current: (color: Color(0x552F80ED), ink: false),
    MushafWordMark.mistake: (color: Color(0x77E53935), ink: false),
    MushafWordMark.correct: (color: Color(0xFF43A047), ink: true),
    MushafWordMark.skipped: (color: Color(0xFFE0A800), ink: true),
    MushafWordMark.wrong: (color: Color(0xFFD32F2F), ink: true),
    MushafWordMark.tashkeel: (color: Color(0xFFEF6C00), ink: true),
    MushafWordMark.tajweed: (color: Color(0xFF039BE5), ink: true),
    MushafWordMark.checking: (color: Color(0xFFFFAB91), ink: true),
    MushafWordMark.uncertain: (color: Color(0xFFFBC02D), ink: true),
  };

  /// The highlights last drawn on [_page] (see [_applyHighlights]); `null`
  /// once cleared.
  ({
    Map<int, MushafWordMark> marks,
    int? focus,
    Map<int, Color>? passages,
    Set<int> hidden,
    Map<MushafWordMark, int> inks,
  })?
  _appliedHighlights;

  /// The ayah being long-pressed (its sheet open): highlighted like the
  /// focus ayah.
  int? _pressedAyah;

  static bool _isInk(MushafWordMark mark) => _markStyles[mark]!.ink;

  /// Applies the masks, then the highlights over them — and animates what
  /// changed on the page's words.
  void _applyMasks() {
    final before = _appliedOverlay;
    _applyMasksOnly();
    _applyHighlights();
    _playWordEffects(before, _appliedOverlay);
  }

  /// More words changed at once than a recitation changes (a page turned,
  /// a loop starting again, every ayah shown): no animations.
  static const _maxEffects = 12;

  /// More words revealed at once than an ayah or two (a page shown whole):
  /// no animations.
  static const _maxReveals = 60;

  /// A word revealed: its ink fading in, with a soft glow in its own
  /// colour ([color], else the page's ink) behind it — the words revealed
  /// together (an ayah) all at once, so they glow and fade as one.
  void _reveal(
    MushafWordEffectsPage effects,
    int word,
    Color? color, {
    bool glow = true,
  }) {
    effects.playWordEffect(word, MushafWordEffect.inkIn);
    if (!glow) return;
    effects.playWordEffect(
      word,
      MushafWordEffect.bloom,
      color: (color ?? widget.colors.text).withValues(alpha: 0.35),
      // A soft band behind each word, the letters not blurred: an ayah's
      // words revealed quickly one after another stay smooth.
      letters: false,
    );
  }

  /// A recitation's changes on this page, animated (where the page can):
  /// a word recited right glows, a mistake sways, a word revealed fades in
  /// — and a page recited to its last word gives a gentle double tap.
  /// Nothing as a page first shows its marks.
  void _playWordEffects(
    (Set<int>, Map<int, MushafWordMark>)? before,
    (Set<int>, Map<int, MushafWordMark>)? after,
  ) {
    final page = _page;
    if (page == null || before == null || after == null) return;
    if (page is! MushafWordEffectsPage) return;
    // Animations turned off on the phone: none played (the rest — a page's
    // gentle tap — still).
    final effects = _calm ? const _NoEffects() : page as MushafWordEffectsPage;
    final inks =
        ref.read(mushafWordOverlayProvider)?.inks ??
        const <MushafWordMark, int>{};
    Color colorOf(MushafWordMark mark) {
      final ink = inks[mark];
      return ink != null ? Color(ink) : _markStyles[mark]!.color;
    }

    final revealed = before.$1.difference(after.$1);
    final changed = [
      for (final MapEntry(key: i, value: mark) in after.$2.entries)
        if (before.$2[i] != mark) (i, mark),
    ];
    if (changed.length > _maxEffects) return;
    if (revealed.length <= _maxReveals) {
      final blooming = {
        for (final (i, mark) in changed)
          if (mark == MushafWordMark.correct || mark == MushafWordMark.mistake)
            i,
      };
      for (final i in revealed) {
        final mark = after.$2[i];
        _reveal(
          effects,
          i,
          mark != null && _isInk(mark) ? colorOf(mark) : null,
          glow: !blooming.contains(i),
        );
      }
    }
    for (final (i, mark) in changed) {
      switch (mark) {
        case MushafWordMark.correct:
          effects.playWordEffect(
            i,
            MushafWordEffect.bloom,
            color: colorOf(mark),
          );
        case MushafWordMark.wrong ||
            MushafWordMark.skipped ||
            MushafWordMark.tashkeel ||
            MushafWordMark.tajweed:
          effects.playWordEffect(i, MushafWordEffect.shake);
        case MushafWordMark.mistake:
          effects.playWordEffect(
            i,
            MushafWordEffect.bloom,
            color: colorOf(mark),
          );
        case MushafWordMark.current ||
            MushafWordMark.checking ||
            MushafWordMark.uncertain:
          break;
      }
    }
    // The page recited to its end (or the recitation's range to its end on
    // it): the last of its words in the range newly marked (in ink), and
    // nearly all of them marked — a word no recitation marks (a printed
    // basmalah, say) does not hold it back.
    final overlay = ref.read(mushafWordOverlayProvider);
    final refs = page.wordRefs;
    final inRange = [
      for (var i = 0; i < refs.length; i++)
        if (overlay != null &&
            compareWordRefs(refs[i], overlay.first) >= 0 &&
            compareWordRefs(refs[i], overlay.last) <= 0)
          i,
    ];
    bool inked(MushafWordMark? mark) => mark != null && _isInk(mark);
    bool complete((Set<int>, Map<int, MushafWordMark>) applied) {
      if (inRange.isEmpty || !inked(applied.$2[inRange.last])) return false;
      final marked = inRange.where((i) => inked(applied.$2[i])).length;
      return marked >= inRange.length * 0.9;
    }

    if (changed.isNotEmpty && complete(after) && !complete(before)) {
      if (ref.read(hifzSettingsProvider).alert.vibrates) {
        ref.read(hifzPageDoneHapticsProvider)();
      }
    }
  }

  /// Draws every highlight on the page at once, each word's by priority:
  /// the focus (or long-pressed) ayah's blue, then a recitation's marks,
  /// then — with "Colour thematic passages" on — its passage's tint, on
  /// the words not hidden (in hide mode, as they are revealed). Ink marks
  /// colour the letters over whichever band is behind them.
  void _applyHighlights() {
    final page = _page;
    if (page == null) return;
    final refs = page.wordRefs;
    final marks = _appliedOverlay?.$2 ?? const <int, MushafWordMark>{};
    // Colours the reader chose for some marks (Hifz settings).
    final inks =
        ref.read(mushafWordOverlayProvider)?.inks ??
        const <MushafWordMark, int>{};
    Color colorOf(MushafWordMark mark) {
      final ink = inks[mark];
      return ink != null ? Color(ink) : _markStyles[mark]!.color;
    }

    final focusId = _pressedAyah ?? ref.read(mushafFocusAyahProvider)?.ayahId;
    final focus = focusId != null && refs.any((w) => w.ayahId == focusId)
        ? focusId
        : null;
    final passages = ref.read(mushafPassagesProvider)
        ? ref.read(passageColorsProvider).value
        : null;
    // Hidden words' places stay plain: a recitation's own reveals while
    // one runs, else hide mode's.
    final hideMode = ref.read(mushafHideModeProvider);
    final hidden = passages == null
        ? const <int>{}
        : _appliedOverlay?.$1 ??
              {
                for (var i = 0; i < refs.length; i++)
                  if (hideMode.isWordHidden(widget.pageNumber, i)) i,
              };
    final applied = _appliedHighlights;
    if (applied != null &&
        applied.focus == focus &&
        identical(applied.passages, passages) &&
        mapEquals(applied.marks, marks) &&
        mapEquals(applied.inks, inks) &&
        setEquals(applied.hidden, hidden)) {
      return;
    }
    if (applied == null && focus == null && marks.isEmpty && passages == null) {
      return; // nothing drawn, nothing to draw
    }
    final highlights = <({int word, Color color, bool ink})>[];
    // Passages as seamless bands (word by word, the see-through bands
    // would overlap into darker seams): runs of whole ayahs, markers
    // included — or, in an ayah with a mark band or the focus, its other
    // words.
    final bands = <PageBand>[];
    // Ayahs tinted only in part: with a mark band, or words hidden.
    final banded = <int>{
      for (final MapEntry(key: i, value: mark) in marks.entries)
        if (!_isInk(mark)) refs[i].ayahId,
      for (final i in hidden) refs[i].ayahId,
    };
    final tintedWords = <int, List<int>>{};
    for (var i = 0; i < refs.length; i++) {
      final mark = marks[i];
      final ayah = refs[i].ayahId;
      if (mark != null && !_isInk(mark)) {
        highlights.add((word: i, color: colorOf(mark), ink: false));
      } else if (passages != null && ayah != focus && !hidden.contains(i)) {
        final tint = passages[ayah];
        if (tint != null) {
          if (banded.contains(ayah)) {
            (tintedWords[ayah] ??= []).add(i);
          } else if (bands.isNotEmpty &&
              bands.last.isAyahs &&
              bands.last.color == tint &&
              bands.last.surah == ayah ~/ 1000 &&
              bands.last.toAyah >= ayah % 1000 - 1) {
            final last = bands.removeLast();
            bands.add(
              PageBand.ayahs(last.surah, last.fromAyah, ayah % 1000, tint),
            );
          } else {
            bands.add(
              PageBand.ayahs(ayah ~/ 1000, ayah % 1000, ayah % 1000, tint),
            );
          }
        }
      }
      if (mark != null && _isInk(mark)) {
        highlights.add((word: i, color: colorOf(mark), ink: true));
      }
    }
    for (final MapEntry(key: ayah, value: words) in tintedWords.entries) {
      bands.add(PageBand.words(words, passages![ayah]!));
    }
    page.setWordHighlights(highlights, bands: bands);
    if (focus != null) {
      page.highlightAyah((chapterNo: focus ~/ 1000, verseNo: focus % 1000));
    }
    _appliedHighlights = (
      marks: marks,
      focus: focus,
      passages: passages,
      hidden: hidden,
      inks: inks,
    );
  }

  /// Applies whichever mask is active: a word overlay (Hifz mode) wins
  /// over hide mode. (Its marks are drawn by [_applyHighlights].)
  void _applyMasksOnly() {
    final page = _page;
    if (page == null) return;
    final overlay = ref.read(mushafWordOverlayProvider);
    if (overlay != null) {
      final refs = page.wordRefs;
      final hideMode = ref.read(mushafHideModeProvider);
      final uncovered = hideMode.revealedOn(widget.pageNumber);
      final hidden = <int>{
        for (var i = 0; i < refs.length; i++)
          if (overlay.followHideMode
              ? hideMode.enabled && i >= uncovered
              : overlay.isHidden(refs[i]))
            i,
      };
      final marks = <int, MushafWordMark>{
        for (var i = 0; i < refs.length; i++)
          if (overlay.marks.containsKey(refs[i])) i: overlay.marks[refs[i]]!,
      };
      final applied = _appliedOverlay;
      if (applied == null || !setEquals(applied.$1, hidden)) {
        page.setHiddenWords(hidden);
      }
      _appliedOverlay = (hidden, marks);
      _appliedMask = null;
      return;
    }
    if (_appliedOverlay != null) {
      page.setHiddenWords(const {});
      _appliedOverlay = null;
      _appliedMask = null;
    }
    _applyMask(ref.read(mushafHideModeProvider));
  }

  void _applyMask(MushafHideModeState hideMode) {
    final page = _page;
    if (page == null) return;
    final wanted = (
      hidden: hideMode.enabled,
      revealed: hideMode.enabled ? hideMode.revealedOn(widget.pageNumber) : 0,
    );
    if (wanted == _appliedMask) return;
    // A page that was never masked needs no unmasking.
    if (_appliedMask == null && !wanted.hidden) {
      _appliedMask = wanted;
      return;
    }
    final before = _appliedMask;
    _appliedMask = wanted;
    _maskLater?.cancel();
    // The eye: the whole page hidden or shown — fading.
    if (page is MushafWordEffectsPage &&
        !_calm &&
        before != null &&
        before.hidden != wanted.hidden) {
      final effects = page as MushafWordEffectsPage;
      if (wanted.hidden) {
        // Into the paper first, then hidden.
        for (var i = wanted.revealed; i < page.wordCount; i++) {
          effects.playWordEffect(i, MushafWordEffect.inkOut);
        }
        _maskLater = Timer(MushafWordEffect.inkOutTime, () {
          if (!mounted || _page != page || _appliedMask != wanted) return;
          page.setMemorizationMask(
            hidden: wanted.hidden,
            revealedWords: wanted.revealed,
          );
        });
        return;
      }
      page.setMemorizationMask(hidden: false);
      for (var i = before.revealed; i < page.wordCount; i++) {
        effects.playWordEffect(i, MushafWordEffect.inkIn);
      }
      return;
    }
    page.setMemorizationMask(
      hidden: wanted.hidden,
      revealedWords: wanted.revealed,
    );
    // Words uncovered with hide mode's buttons: animated in, in order.
    if (page is MushafWordEffectsPage &&
        !_calm &&
        before != null &&
        before.hidden &&
        wanted.hidden &&
        wanted.revealed > before.revealed &&
        wanted.revealed - before.revealed <= _maxReveals) {
      for (var i = before.revealed; i < wanted.revealed; i++) {
        _reveal(page as MushafWordEffectsPage, i, null);
      }
    }
  }

  @override
  void didUpdateWidget(covariant QuranEngineMushafPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      setState(() {
        _page = null;
        _loadError = null;
        _appliedMask = null;
        _appliedOverlay = null;
        _appliedHighlights = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final backend = await ref.read(mushafQuranEngineBackendProvider.future);
      final page = await backend.loadPage(widget.pageNumber);
      if (!mounted) return;
      // Publish the page's real aspect ratio so `MushafPager` can size its
      // web frame tightly around the printed page (see
      // `mushafPageAspectRatiosProvider`). This widget keeps sole ownership
      // of the loaded page itself; the ratio is just a number.
      ref
          .read(mushafPageAspectRatiosProvider.notifier)
          .report(widget.pageNumber, page.aspectRatio);
      final hideMode = ref.read(mushafHideModeProvider.notifier);
      hideMode.reportPageWords(
        widget.pageNumber,
        wordCount: page.wordCount,
        ayahBoundaries: page.ayahWordBoundaries,
      );
      final words = page.wordRefs;
      if (words.isNotEmpty) {
        ref.read(mushafPageWordRangesProvider.notifier).report(
          widget.pageNumber,
          (first: words.first, last: words.last),
        );
      }
      final span = page.verseSpan;
      if (span != null) {
        ref
            .read(mushafPageVersesProvider.notifier)
            .report(widget.pageNumber, span);
      }
      final previous = _page;
      if (previous != null) backend.disposePage(previous);
      setState(() {
        _backend = backend;
        _page = page;
        _appliedMask = null;
        _appliedOverlay = null;
        _appliedHighlights = null;
      });
      _applyMasks();
      // Fire-and-forget: never awaited, never allowed to affect the page
      // actually on screen.
      unawaited(backend.preloadAround(widget.pageNumber));
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _maskLater?.cancel();
    final backend = _backend;
    final page = _page;
    if (backend != null && page != null) backend.disposePage(page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mushafHideModeProvider, (_, _) => _applyMasks());
    ref.listen(mushafWordOverlayProvider, (_, _) => _applyMasks());
    ref.listen(mushafFocusAyahProvider, (_, _) => _applyHighlights());
    // Thematic passages: their tints once loaded, on or off.
    if (ref.watch(mushafPassagesProvider)) {
      ref.listen(passageColorsProvider, (_, _) => _applyHighlights());
    }
    ref.listen(mushafPassagesProvider, (_, _) => _applyHighlights());
    if (_page == null && _loadError == null) {
      // Fire-and-forget: harmless to call every build (a no-op once a
      // load is in flight or complete) -- the same pattern
      // `_ensureMushafPageResolvedOnce` uses elsewhere in this feature.
      _load();
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).readerPageError,
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.colors.secondaryText),
          ),
        ),
      );
    }

    final page = _page;
    if (page == null) {
      return Center(
        child: CircularProgressIndicator(color: widget.colors.secondaryText),
      );
    }

    // No outer AspectRatio/FittedBox wrapper here -- deliberately. Both
    // platform implementations already receive whatever raw box this
    // widget is given (via their own internal LayoutBuilder:
    // `QvpPageView.build()` on Android, `_QuranEngineWebPageViewState
    // .build()` on Web) and compute their own uniform fit-to-box scale
    // and centering internally, using the engine's own layout call --
    // there is nothing left for a Flutter-level wrapper to usefully add.
    //
    // An earlier version of this widget wrapped `buildView()` first in
    // `AspectRatio` (which pre-shapes the box to the page's exact
    // proportions *before* the platform view ever sees it -- defeating
    // the point: the box handed down was never wider than natural to
    // begin with) and later in `FittedBox(fit: BoxFit.cover)` (which
    // does fill the box completely, but by cropping the printed page's
    // own edges when the box's proportions don't match closely enough --
    // real content, not just margin, on a sufficiently mismatched
    // viewport). Neither is used any more: `QvpPageView`'s own built-in
    // ceiling on how much wider than natural it would draw
    // (`QvpDefaults.aspectSlack`, 15%) turned out to be the actual cause
    // of the leftover space this was working around, not anything a
    // wrapper here could fix -- see `quran_engine_android_backend.dart`
    // and `third_party/qvp_flutter/PATCHES.md`. Any space still visible
    // beyond that is the genuine, unavoidable consequence of the printed
    // page's own aspect ratio differing from the device's -- the engine
    // already computes the true maximum uniform scale that shows the
    // entire page, uncropped and undistorted, and centers it.
    final onWordTap = widget.onWordTap;
    final onWordLongPress = widget.onWordLongPress;
    bool isHidden(MushafTokenHitRect hit) {
      final applied = _appliedOverlay;
      return applied != null
          ? applied.$1.contains(hit.sourceTokenId)
          : ref
                .read(mushafHideModeProvider)
                .isWordHidden(widget.pageNumber, hit.sourceTokenId);
    }

    return page.buildView(
      ink: widget.colors.text,
      paper: widget.colors.background,
      // A word hidden on the page must not be revealed by its word sheet:
      // hidden as the page shows it — by a recitation's own reveals while
      // one runs (hide mode catches up only when it ends), else by hide mode.
      onWordHit: onWordTap == null
          ? null
          : (hit) {
              if (!isHidden(hit)) onWordTap(hit);
            },
      onDecorationHit: widget.onWordTap,
      onWordLongHit: onWordLongPress == null
          ? null
          : (hit) async {
              final ayahId = hit.canonicalAyahId;
              if (ayahId == null || isHidden(hit)) return;
              _pressedAyah = ayahId;
              _applyHighlights();
              await onWordLongPress(hit);
              if (!mounted || _page != page) return;
              _pressedAyah = null;
              _applyHighlights();
            },
    );
  }
}

/// Word effects when animations are turned off: none.
class _NoEffects implements MushafWordEffectsPage {
  const _NoEffects();

  @override
  void playWordEffect(
    int wordIndex,
    MushafWordEffect effect, {
    Color? color,
    Duration delay = Duration.zero,
    bool halo = true,
    bool letters = true,
  }) {}
}
