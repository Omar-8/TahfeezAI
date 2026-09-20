import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';
import '../../../core/theme/app_breakpoints.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import 'mushaf_page_render_model.dart';
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
        ? ((widget.initialPageNumber - 1) ~/ 2).clamp(
            0,
            (widget.pageCount / 2).ceil() - 1,
          )
        : (widget.initialPageNumber - 1).clamp(0, widget.pageCount - 1);
    _controller = PageController(initialPage: initialIndex);
    _lastSettledIndex = initialIndex;
  }

  @override
  void dispose() {
    if (_twoPageSpread != null) _controller.dispose();
    _webFocusNode.dispose();
    super.dispose();
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

  Widget _bordered(BuildContext context, Widget child) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = TahfeezBreakpoint.of(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final useTwoPageSpread =
        breakpoint.isAtLeastTablet && isLandscape && size.width > 700;
    _ensureController(useTwoPageSpread);
    final isWeb = ref.watch(platformCapabilitiesProvider).isWeb;

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
            isCurrentPage: pageNumber == _currentPageNumber,
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: isWeb ? _bordered(context, page) : page,
            ),
          );
        },
      );
      return isWeb ? _wrapForWeb(pageView) : pageView;
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
              )
            : const SizedBox.shrink();
        return Row(
          children: [
            Expanded(child: isWeb ? _bordered(context, rightPage) : rightPage),
            if (isWeb) const SizedBox(width: 24),
            Expanded(child: isWeb ? _bordered(context, leftPage) : leftPage),
          ],
        );
      },
    );
    return isWeb ? _wrapForWeb(pageView) : pageView;
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
