import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_turn.dart';
import '../application/mushaf_quran_engine_providers.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';
import 'ayah_mode_continuous.dart';
import 'mushaf_ayah_sheet.dart';
import 'mushaf_token_hit_rect.dart';
import 'mushaf_page_view.dart';

/// A [MaterialScrollBehavior] that additionally accepts mouse-drag input.
///
/// Flutter's default [ScrollBehavior.dragDevices] excludes
/// [PointerDeviceKind.mouse] — a deliberate default everywhere else in the
/// app (mouse drag colliding with text/word selection would be worse), but
/// the Mushaf pager on web has no such conflict and reads more like a
/// document viewer, where click-and-drag page turning is expected.
class _MushafWebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

/// The swipeable Mushaf page surface — extracted from [MushafPageView] one
/// level up so both the standalone Mushaf route (reached from the Quran
/// index's Page tab, with no underlying verse-by-verse [QuranLocation] to
/// anchor to) and the Reader's own in-place Mushaf mode
/// (`lib/features/reader/presentation/reader_screen.dart`) share the exact
/// same swipe/two-page-spread mechanics rather than maintaining two copies.
///
/// Device modes (`docs/DESIGN_DIRECTION.md`'s responsive guidance):
/// - **Phone / portrait**: one page, horizontal swipe.
/// - **Tablet landscape / wide desktop**: an optional two-page spread, with
///   the lower-numbered (earlier-read) page on the right and the next page
///   on the left, matching how a physical Mushaf opens right-to-left.
///
/// A `PageView.builder` with no explicit `controller:` — Flutter manages
/// its own internal `PageController` when none is given, which naturally
/// resets to a fresh position when this widget's `key` changes (used here
/// to reset cleanly when switching between single-page and two-page-spread
/// layouts, e.g. on rotation, rather than trying to remap one controller's
/// index meaning across two different pagination schemes).
///
/// On web only ([PlatformCapabilities.isWeb]), this also adds: extra gutter
/// spacing and a thin border around each page of a two-page spread, mouse
/// click-and-drag (see [_MushafWebScrollBehavior]), left/right arrow-key
/// navigation, and a vertical-mouse-wheel handler (see
/// [_handleWheelPointerSignal]) that turns exactly one page per wheel
/// notch, with a short cooldown, instead of a continuous multi-page
/// scroll — native/mobile behavior is untouched.
class MushafPager extends ConsumerStatefulWidget {
  const MushafPager({
    super.key,
    required this.mushafId,
    required this.pageCount,
    required this.initialPageNumber,
    required this.onPageChanged,
  });

  final int mushafId;
  final int pageCount;
  final int initialPageNumber;
  final ValueChanged<int> onPageChanged;

  @override
  ConsumerState<MushafPager> createState() => _MushafPagerState();
}

class _MushafPagerState extends ConsumerState<MushafPager> {
  bool? _twoPageSpread;
  late PageController _controller;

  /// The pager's own authoritative "current page" — distinct from *any*
  /// [MushafPageView] merely existing in the tree, since
  /// `allowImplicitScrolling`/`scrollCacheExtent` below keep neighboring
  /// pages' widgets built too. Only the page number matching this drives
  /// [MushafPageView.isCurrentPage], and so only it may trigger render
  /// -model prewarming — see that field's own doc comment for why every
  /// pre-built neighbor doing so independently is a real bug, not just a
  /// redundant one.
  late int _currentPageNumber = widget.initialPageNumber;

  /// Web-only keyboard focus for arrow-key page navigation.
  final FocusNode _webFocusNode = FocusNode(debugLabel: 'MushafPager (web)');

  /// The last index the pager was fully settled on — the fallback
  /// [_animateToAdjacentIndex] starts from when [PageController.page] isn't
  /// available yet (e.g. before the controller has laid out any clients).
  int? _lastSettledIndex;

  /// The current `itemCount` of whichever [PageView.builder] is showing
  /// (page count in single-page mode, spread count in two-page mode) — the
  /// clamp bound for keyboard/wheel page-index navigation.
  int _itemCount = 1;

  void _onPageChanged(int pageNumber) {
    setState(() => _currentPageNumber = pageNumber);
    widget.onPageChanged(pageNumber);
  }

  void _ensureController(bool useTwoPageSpread) {
    if (_twoPageSpread == useTwoPageSpread) return;
    if (_twoPageSpread != null) _controller.dispose();
    _twoPageSpread = useTwoPageSpread;
    final initialIndex = useTwoPageSpread
        ? ((_currentPageNumber - 1) ~/ 2).clamp(
            0,
            (widget.pageCount / 2).ceil() - 1,
          )
        : (_currentPageNumber - 1).clamp(0, widget.pageCount - 1);
    _controller = PageController(initialPage: initialIndex);
    _lastSettledIndex = initialIndex;
  }

  @override
  void dispose() {
    _requestedFullBleed = false;
    _scheduleFullBleedApply();
    if (_twoPageSpread != null) _controller.dispose();
    _webFocusNode.dispose();
    super.dispose();
  }

  // Requests the shell's full content area while this pager renders a
  // two-page spread, and releases it otherwise. Deliberately driven from the
  // pager rather than a whole-screen wrapper: verse-by-verse mode never hosts
  // this pager (it stays in the app shell's reading column), a single-page
  // Mushaf view has no fixed-aspect surface worth expanding, and only the
  // spread — two fixed-aspect pages that the reading cap only ever squeezes —
  // earns full-bleed.
  bool _requestedFullBleed = false;
  bool _appliedFullBleed = false;
  bool _applyScheduled = false;
  // Cached (never touched via `ref` at callback time, since `ref` is invalid
  // once the element unmounts) so the deferred apply below can still mutate
  // the keepAlive notifier afterwards.
  FullBleedContent? _fullBleedNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fullBleedNotifier ??= ref.read(fullBleedContentProvider.notifier);
  }

  /// Applies [_requestedFullBleed] to the shell's latch after the current
  /// frame. Riverpod forbids mutating a provider from a widget life-cycle
  /// (`build`/`dispose`/...), so the mutation is deferred a frame and
  /// coalesced to at most one pending apply. The apply is best-effort
  /// bookkeeping: in production the app-root `ProviderScope` outlives this
  /// pager, so it always finds a live container; a test that swaps out the
  /// whole `ProviderScope` can dispose it before the apply runs — then the
  /// latch belongs to a dead container and there is nothing left to hold or
  /// release (the exception, if any, is deliberately swallowed).
  void _scheduleFullBleedApply() {
    if (_applyScheduled) return;
    _applyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyScheduled = false;
      if (_appliedFullBleed == _requestedFullBleed) return;
      final notifier = _fullBleedNotifier;
      if (notifier == null) return;
      _appliedFullBleed = _requestedFullBleed;
      try {
        if (_requestedFullBleed) {
          notifier.request();
        } else {
          notifier.release();
        }
      } catch (_) {
        // Container/ref torn down between scheduling and apply.
      }
    });
  }

  void _animateToAdjacentIndex(int direction) {
    if (!_controller.hasClients) return;
    final current = _controller.page?.round() ?? _lastSettledIndex ?? 0;
    final target = (current + direction).clamp(0, _itemCount - 1);
    if (target == current) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// Shows [pageNumber] (its spread in two-page mode): an adjacent index
  /// turns as a swipe would, a farther one jumps there at once — passing
  /// through every page between would report each as visited.
  void _goToPage(int pageNumber) {
    if (!_controller.hasClients) return;
    final current = _controller.page?.round() ?? _lastSettledIndex ?? 0;
    final target =
        ((_twoPageSpread ?? false) ? (pageNumber - 1) ~/ 2 : pageNumber - 1)
            .clamp(0, _itemCount - 1);
    if (target == current) return;
    if ((target - current).abs() == 1) {
      _animateToAdjacentIndex(target - current);
    } else {
      _controller.jumpToPage(target);
    }
  }

  /// Left/right arrow keys move one page-index at a time. The pager reads
  /// right-to-left (`reverse: true`, matching a physical Mushaf: the
  /// lower-numbered/earlier page is on the right), so Left advances to the
  /// next index (visually moves left, forward in reading order) and Right
  /// goes back — the same mapping an RTL PDF reader uses.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _animateToAdjacentIndex(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _animateToAdjacentIndex(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The last time a wheel notch turned a page — a short cooldown after
  /// this is what makes wheel input "one page per gesture" instead of a
  /// rapid trackpad-inertia burst continuously flipping through several.
  DateTime? _lastWheelSnapAt;

  /// Turns a vertical mouse-wheel scroll into a single, complete page
  /// change instead of leaving it unhandled.
  ///
  /// This pager's `PageView` scrolls horizontally, and Flutter's
  /// `Scrollable` only ever reads a `PointerScrollEvent`'s `dx` for a
  /// horizontal axis (see `Scrollable._pointerSignalEventDelta` — it reads
  /// `dy` instead only when a modifier key is held), so a plain vertical
  /// mouse-wheel scroll — the ordinary way most people scroll with a mouse
  /// — otherwise does *nothing at all* here, not even a continuous
  /// free-scroll. That also means it's safe to handle it directly: since
  /// `Scrollable` never registers interest in a `dy`-dominant signal over
  /// a horizontal `PageView`, there is no competing handler to race or
  /// double-handle. A horizontal wheel/trackpad gesture (`dx` dominant) is
  /// left alone entirely — that one *is* already claimed by the
  /// `PageView`'s own native, drag-like continuous scrolling, which reads
  /// the same as a deliberate swipe and is fine to leave continuous.
  void _handleWheelPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    if (dx.abs() >= dy.abs()) return;
    final now = DateTime.now();
    if (_lastWheelSnapAt != null &&
        now.difference(_lastWheelSnapAt!) < const Duration(milliseconds: 260)) {
      return;
    }
    _lastWheelSnapAt = now;
    _animateToAdjacentIndex(dy > 0 ? 1 : -1);
  }

  Widget _wrapForWeb(Widget pageView) {
    return Focus(
      focusNode: _webFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ScrollConfiguration(
        behavior: _MushafWebScrollBehavior(),
        child: Listener(
          onPointerSignal: _handleWheelPointerSignal,
          child: pageView,
        ),
      ),
    );
  }

  /// Web-only page framing: a visibly heavier border than a typical Material
  /// outline (this page is a printed-document surface, not app chrome), and
  /// inner padding between that border and the page content itself, filled
  /// with the Mushaf's own current appearance background — never a fixed
  /// theme/Material color — so the framed area reads as part of the page,
  /// not as app-level surface poking through around it.
  static const _webBorderWidth = 5.0;
  static const _webPagePadding = EdgeInsets.zero;
  static const _webGutterWidth = 50.0;
  static const _webOuterPadding = EdgeInsets.zero;
  static const _webSpreadOuterPadding = EdgeInsets.only(bottom: 10);
  // Small page number printed over the web frame's bottom border: centred
  // horizontally, riding in a paper-coloured chip that cleanly covers the
  // border rule where it sits -- scaled with the page so it stays
  // proportional whether the spread is on a small tablet or a large desktop
  // window. The number is overlaid, never reserved from the page box.
  static const _webPageNumberMinFontSize = 10.0;
  static const _webPageNumberMaxFontSize = 14.0;
  // Strip (positioning box) height as a multiple of the font size: the
  // number's own line plus breathing room so the centred chip covers the
  // border band nicely on both sides.
  static const _webPageNumberStripFactor = 1.8;

  Widget _bordered(
    BuildContext context,
    Widget child,
    Color background, {
    double? aspectRatio,
    String? label,
    Color? labelColor,
  }) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    // Frame chrome that must be counted when fitting the page box into the
    // space this frame is handed: the border on both axes plus any inner
    // padding (currently zero). Wrapping the page in an `AspectRatio`
    // *inside* the Container alone was not enough here: `AspectRatio` sizes
    // to the largest aspect-correct box the loose constraints allow -- the
    // height-bound one -- so when a spread half was narrower than the page's
    // natural width, the page took its width from the tall axis and carried
    // the 2px border beyond the half, overflowing the scroll viewport and
    // clipping the page's outer edges (with the hidden sliver only
    // reachable by swiping). Fitting the page box against (maxWidth/maxHeight
    // minus the chrome) first makes the frame hug the page *and* guarantees
    // it never exceeds the space actually available, at any window size.
    final borderChrome = _webBorderWidth * 2;
    final horizontalChrome = borderChrome + _webPagePadding.horizontal;
    final verticalChrome = borderChrome + _webPagePadding.vertical;
    // Keying the frame's size to the page's own true aspect ratio (via
    // [mushafEnginePageAspectRatioProvider]) is what makes the border hug
    // the printed page rather than framing the whole viewport box -- a
    // fixed-aspect-ratio page rendered with the engine's uniform
    // fit-to-box `renderFit` otherwise leaves the paper-colored space at
    // the viewport's left/right (or top/bottom) letterboxing *between*
    // the page and the border, no matter how little padding is set. Until
    // the ratio resolves (async engine load), the frame still spans the
    // viewport, then snaps tightly around the page.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = (constraints.maxWidth - horizontalChrome).clamp(
          0.0,
          double.infinity,
        );
        final maxH = (constraints.maxHeight - verticalChrome).clamp(
          0.0,
          double.infinity,
        );
        double pageWidth;
        double pageHeight;
        if (aspectRatio == null) {
          pageWidth = maxW;
          pageHeight = maxH;
        } else {
          pageWidth = maxW;
          pageHeight = pageWidth / aspectRatio;
          if (pageHeight > maxH) {
            pageHeight = maxH;
            pageWidth = pageHeight * aspectRatio;
          }
        }
        // A page number, when present, is printed over the frame's own
        // surface at the very bottom: horizontally centered and riding the
        // frame's outer bottom edge, so it reads as a small caption that
        // "cuts" the rule and sits just below it. It is *not* laid out as a
        // reserved strip -- the page box keeps the full height the verses
        // always had, so every pixel of the number's framing is given back
        // to the text. The strip height is only used to center the caption.
        final labelFontSize = label == null
            ? 0.0
            : (pageHeight * 0.018).clamp(
                _webPageNumberMinFontSize,
                _webPageNumberMaxFontSize,
              );
        final labelBoxHeight = label == null
            ? 0.0
            : labelFontSize * _webPageNumberStripFactor;
        return Container(
          width: pageWidth + borderChrome + _webPagePadding.horizontal,
          height: pageHeight + verticalChrome,
          padding: _webPagePadding,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: outline, width: _webBorderWidth),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.none,
          child: label == null
              ? SizedBox(
                  key: const ValueKey('mushaf-page-box'),
                  width: pageWidth,
                  height: pageHeight,
                  child: child,
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      key: const ValueKey('mushaf-page-box'),
                      width: pageWidth,
                      height: pageHeight,
                      child: child,
                    ),
                    // The caption box sits just below the border rule: its vertical
                    // center lands a hair (`2`) under the frame's outer
                    // bottom edge, so the number chip covers the border
                    // stroke cleanly while reading as hanging slightly under
                    // the rule rather than resting on it.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -2 - labelBoxHeight / 2,
                      child: SizedBox(
                        key: const ValueKey('mushaf-page-number-box'),
                        height: labelBoxHeight,
                        child: Center(
                          // The number rides in a small chip filled with the
                          // frame's own paper color, centred on the border
                          // rule: the chip *covers* the border stroke where
                          // it sits (looks like the rule is cleanly cut), and
                          // its colour keeps it reading as part of the page
                          // rather than a floating label.
                          child: Container(
                            key: const ValueKey('mushaf-page-number-chip'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: labelFontSize,
                                height: 1.0,
                                color: labelColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  // Helper for the web frame: reads the loaded engine page's real aspect
  // ratio for a page number, or null when the ratio isn't available yet (the
  // content widget hasn't finished loading that page) -- callers then
  // degrade to the un-keyed frame rather than crashing.
  double? _mushafAspectRatio(int pageNumber, bool isWeb) {
    if (!isWeb) return null;
    return ref.watch(
      mushafPageAspectRatiosProvider.select((ratios) => ratios[pageNumber]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = TahfeezBreakpoint.of(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    // Ayah mode's continuous layout: one scroll, no pages to swipe.
    final continuous =
        ref.watch(readerModeProvider) == ReaderMode.ayah &&
        ref.watch(ayahViewPreferencesProvider.select((v) => v.layout)) ==
            AyahLayout.continuous;
    final useTwoPageSpread =
        !continuous &&
        breakpoint.isAtLeastTablet &&
        isLandscape &&
        size.width > 700;
    if (continuous) {
      // Back to pages later: a pager opened where the scroll left off.
      if (_twoPageSpread != null) _controller.dispose();
      _twoPageSpread = null;
      _requestedFullBleed = false;
      _scheduleFullBleedApply();
      return AyahModeContinuous(
        key: const ValueKey('continuous'),
        mushafId: widget.mushafId,
        pageCount: widget.pageCount,
        initialPageNumber: _currentPageNumber,
        onPageChanged: _onPageChanged,
      );
    }
    _ensureController(useTwoPageSpread);
    // Page-turn requests from the shell's bottom bar (hide mode's buttons at
    // either end of a page) — only for the pager on screen.
    ref.listen(mushafPageTurnRequestsProvider, (_, request) {
      if (request != null && (ModalRoute.of(context)?.isCurrent ?? true)) {
        if (request.page case final page?) {
          _goToPage(page);
        } else {
          _animateToAdjacentIndex(request.direction);
        }
      }
    });
    _requestedFullBleed = useTwoPageSpread;
    _scheduleFullBleedApply();
    final isWeb = ref.watch(platformCapabilitiesProvider).isWeb;
    // Web-only, and intentionally *read* (not just watched-and-ignored):
    // a browser zoom (Ctrl/Cmd +/- ; also the browser's zoom-on-wheel) is a
    // devicePixelRatio change that leaves MediaQuery.size untouched, so it
    // would otherwise not rebuild this page's engine views at all and the
    // canvas' last `renderFit` CSS size would sit stale -- cutting pages at
    // 100% yet fitting them at 125%, exactly the reported symptom. Reading
    // it here makes the whole pager (and every keyed page frame it builds,
    // and through them the web bridge's `renderFit` re-pin) rebuild on
    // every metrics change, so a zoom always re-derives the fit from the
    // *current* ratio instead of a previous one.
    final appearanceColors = ref
        .watch(mushafAppearanceControllerProvider)
        .colors;

    // The page's own content keeps the app's text direction; only the
    // pager's page order is fixed (see [_rightToLeft]).
    final appDirection = Directionality.of(context);

    if (!useTwoPageSpread) {
      _itemCount = widget.pageCount;
      final pageView = PageView.builder(
        key: const ValueKey('single'),
        controller: _controller,
        reverse: true,
        // Pre-builds (and keeps built) pages either side of the current
        // one, instead of only building on-screen content — so the
        // expensive real-font-shaping layout pass (`MushafPageView` /
        // `mushafPageLayoutProvider`) for a page a swipe is about to land
        // on already ran *before* the swipe finishes, rather than blocking
        // the frame right as it becomes visible. Paired with
        // `mushafPageDataProvider`/`mushafPageLayoutProvider`'s
        // `keepAlive: true` so that work isn't thrown away the moment a
        // page scrolls back out of the cache extent. Widened to a 2-page
        // radius (`allowImplicitScrolling`'s own default is 1 viewport) to
        // match `QpcPageFontManager.preloadAround`'s own radius, and so a
        // fast multi-page swipe doesn't outrun a 1-page buffer.
        allowImplicitScrolling: true,
        scrollCacheExtent: const ScrollCacheExtent.viewport(2),
        itemCount: widget.pageCount,
        onPageChanged: (index) {
          _lastSettledIndex = index;
          _onPageChanged(index + 1);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final page = MushafPageView(
            mushafId: widget.mushafId,
            pageNumber: pageNumber,
            onWordTap: (hitRect) => _showWordInfo(context, hitRect),
            onWordLongPress: (hitRect) =>
                _showAyahInfo(context, hitRect, pageNumber),
            isCurrentPage: pageNumber == _currentPageNumber,
          );
          // No width cap here: the Mushaf page is a fixed-aspect-ratio
          // printed-page facsimile (`AspectRatio` inside
          // `QuranEngineMushafPageContent`), not reflowable text, so an
          // arbitrary max width only ever shrinks it below what the
          // available height already bounds it to -- it never protects
          // against anything. A phone's own width rarely exceeds ~430
          // logical px, so a 480 cap never visibly bound there, but on any
          // wider viewport (tablets, and virtually every Web browser
          // window) it forced the page into a narrow, needlessly margined
          // column instead of letting it use the space actually available.
          final framed = Center(
            child: isWeb
                ? _bordered(
                    context,
                    page,
                    appearanceColors.background,
                    aspectRatio: _mushafAspectRatio(pageNumber, isWeb),
                  )
                : page,
          );
          return Directionality(
            textDirection: appDirection,
            child: isWeb
                ? Padding(padding: _webOuterPadding, child: framed)
                : framed,
          );
        },
      );
      final content = isWeb
          ? _wrapForWeb(_rightToLeft(pageView))
          : _rightToLeft(pageView);
      return content;
    }

    final spreadCount = (widget.pageCount / 2).ceil();
    _itemCount = spreadCount;
    final pageView = PageView.builder(
      key: const ValueKey('spread'),
      controller: _controller,
      reverse: true,
      allowImplicitScrolling: true,
      scrollCacheExtent: const ScrollCacheExtent.viewport(2),
      itemCount: spreadCount,
      onPageChanged: (index) {
        _lastSettledIndex = index;
        _onPageChanged(index * 2 + 1);
      },
      itemBuilder: (context, spreadIndex) {
        final rightPageNumber = spreadIndex * 2 + 1;
        final leftPageNumber = spreadIndex * 2 + 2;
        final rightPage = rightPageNumber <= widget.pageCount
            ? MushafPageView(
                mushafId: widget.mushafId,
                pageNumber: rightPageNumber,
                onWordTap: (hitRect) => _showWordInfo(context, hitRect),
                onWordLongPress: (hitRect) =>
                    _showAyahInfo(context, hitRect, rightPageNumber),
                // Both pages of a spread are simultaneously visible,
                // but only one may be the prewarm-driving "current"
                // page (see `MushafPageView.isCurrentPage`'s doc
                // comment) — the right/lower-numbered page, matching
                // `_onPageChanged`'s own `index * 2 + 1` convention.
                // The left page is covered anyway: it's always
                // exactly `currentPage + 1`, inside the right page's
                // own prewarm window.
                isCurrentPage: rightPageNumber == _currentPageNumber,
              )
            : const SizedBox.shrink();
        final leftPage = leftPageNumber <= widget.pageCount
            ? MushafPageView(
                mushafId: widget.mushafId,
                pageNumber: leftPageNumber,
                onWordTap: (hitRect) => _showWordInfo(context, hitRect),
                onWordLongPress: (hitRect) =>
                    _showAyahInfo(context, hitRect, leftPageNumber),
              )
            : const SizedBox.shrink();
        // A physical Mushaf opens right-to-left: the lower-numbered page sits
        // on the right. `Row` puts its first child on the left under LTR, so
        // the row is laid out RTL explicitly -- otherwise, in an LTR locale,
        // page 1 (Al-Fatiha) lands on the left. The Align widgets below are
        // direction-aware, so they keep pushing each page toward the spine.
        final row = Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Expanded(
                child: isWeb
                    // Direction-aware Align (not Center, and not an absolute
                    // `centerRight`) is what lets `_bordered`'s container size
                    // to the aspect-keyed page (loose constraints) while
                    // pushing each page toward the spread's center/spine in
                    // *both* text directions: under RTL (Arabic locale) an
                    // absolute right/left alignment would push the two pages
                    // outward to the screen edges instead, clipping their
                    // outer sides. The first Row child's spine side is its
                    // end; the second child's is its start.
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _bordered(
                          context,
                          rightPage,
                          appearanceColors.background,
                          aspectRatio: _mushafAspectRatio(
                            rightPageNumber,
                            isWeb,
                          ),
                          // Each frame is labelled with its own page's number (page 1 on
                          // the right, page 2 on the left).
                          label: rightPageNumber <= widget.pageCount
                              ? '$rightPageNumber'
                              : null,
                          labelColor: appearanceColors.text,
                        ),
                      )
                    : rightPage,
              ),
              if (isWeb)
                SizedBox(
                  width: _webGutterWidth,
                  // The gutter between a two-page spread's pages is part of
                  // the printed-page surface, not app chrome — it must track
                  // the Mushaf's own current appearance background exactly
                  // like each page's own paper color, never a fixed
                  // Material/theme color that would visibly mismatch on
                  // every appearance other than whichever one was hardcoded.
                  child: ColoredBox(color: appearanceColors.background),
                ),
              Expanded(
                child: isWeb
                    ? Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _bordered(
                          context,
                          leftPage,
                          appearanceColors.background,
                          aspectRatio: leftPageNumber <= widget.pageCount
                              ? _mushafAspectRatio(leftPageNumber, isWeb)
                              : null,
                          label: leftPageNumber <= widget.pageCount
                              ? '$leftPageNumber'
                              : null,
                          labelColor: appearanceColors.text,
                        ),
                      )
                    : leftPage,
              ),
            ],
          ),
        );
        return Directionality(
          textDirection: appDirection,
          child: isWeb
              ? Padding(padding: _webSpreadOuterPadding, child: row)
              : row,
        );
      },
    );
    final content = isWeb
        ? _wrapForWeb(_rightToLeft(pageView))
        : _rightToLeft(pageView);
    return content;
  }

  /// The pager in a left-to-right frame, so `reverse: true` always reads
  /// right to left like a physical Mushaf (the next page comes in from the
  /// left). A horizontal [PageView] follows the ambient text direction, and
  /// under an RTL locale (Arabic) `reverse` would flip it back to left to
  /// right — the Mushaf's page order must not depend on the UI language.
  Widget _rightToLeft(Widget pageView) =>
      Directionality(textDirection: TextDirection.ltr, child: pageView);

  /// A long-pressed word's ayah, in its sheet; completes when it closes.
  Future<void> _showAyahInfo(
    BuildContext context,
    MushafTokenHitRect hitRect,
    int pageNumber,
  ) async {
    final ayahId = hitRect.canonicalAyahId;
    if (hitRect.tokenType != MushafTokenType.quranWord || ayahId == null) {
      return;
    }
    await showAyahDetailSheet(context, ayahId: ayahId);
  }

  void _showWordInfo(BuildContext context, MushafTokenHitRect hitRect) {
    // Only a real Quran word has canonical identity to look up — an
    // ayahMarker/otherMarker/unknown token renders normally but is not a
    // recited Quran word, per this project's explicit "markers must not
    // participate in word-by-word" rule.
    if (hitRect.tokenType != MushafTokenType.quranWord) return;
    final ayahId = hitRect.canonicalAyahId;
    final wordIndex = hitRect.canonicalWordIndex;
    if (ayahId == null || wordIndex == null) return;

    showWordDetailSheet(
      context,
      wordRef: (ayahId: ayahId, wordIndex: wordIndex),
    );
  }
}
