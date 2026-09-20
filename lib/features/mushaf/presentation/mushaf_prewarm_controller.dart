import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/domain/models/mushaf_models.dart';
import '../application/mushaf_page_providers.dart';
import '../application/qpc_page_font_providers.dart';
import 'mushaf_layout_providers.dart';
import 'mushaf_page_render_model.dart';

part 'mushaf_prewarm_controller.g.dart';

/// How many pages either side of the current one stay warmed — the exact
/// window [MushafPagePrewarmController.prewarmAround] fills, and the bound
/// [MushafPagePrewarmController]'s own eviction enforces on
/// [mushafPageRenderModelProvider]'s cache. Kept as one named constant so
/// the prewarm radius and the cache-retention radius can never drift apart.
const mushafRenderModelWindowRadius = 2;

/// Resolves the exact `fontFamily` [mushafPageRenderModelProvider] needs for
/// [pageNumber] — `null` for a rendering type with no page-specific font
/// concept, otherwise the page's confirmed-loaded font family. Shared by
/// [mushafPageRenderModelPrewarmProvider] (which awaits it) and
/// [MushafPagePrewarmController]'s eviction (which only ever reads already
/// -resolved, cached values — never triggers a fresh load itself).
Future<String?> _resolveFontFamily(
  Ref ref,
  MushafPageBundle bundle,
  int mushafId,
  int pageNumber,
) async {
  if (bundle.mushaf.renderingType !=
      MushafRenderingType.pageSpecificGlyphFont) {
    return null;
  }
  final handle = await ref.watch(
    mushafPageFontProvider(mushafId, pageNumber).future,
  );
  if (!ref.mounted) return null;
  return handle?.fontFamily;
}

/// The same resolution as [_resolveFontFamily], but synchronous and
/// read-only — used only once a page is already known-warmed (its bundle
/// and font are already cached), to recover the exact family name an
/// existing [mushafPageRenderModelProvider] cache entry was built with, so
/// it can be correctly `invalidate`d. Never triggers a font load itself: a
/// cache miss here just means "nothing to evict."
String? _cachedFontFamilyOrNull(Ref ref, int mushafId, int pageNumber) {
  final bundle = ref.read(mushafPageDataProvider(mushafId, pageNumber)).value;
  if (bundle == null) return null;
  if (bundle.mushaf.renderingType !=
      MushafRenderingType.pageSpecificGlyphFont) {
    return null;
  }
  return ref
      .read(mushafPageFontProvider(mushafId, pageNumber))
      .value
      ?.fontFamily;
}

/// Ensures one page's [MushafPageRenderModel] is fully built and cached in
/// [mushafPageRenderModelProvider] — awaiting that page's real data *and*
/// its real font first, so the shaping this triggers always uses the
/// correct font, never a fallback — without the caller needing to already
/// be watching or building that page's widget. This is what lets an
/// entire neighboring page's shaping cost happen ahead of a swipe landing
/// on it, rather than on that swipe's own frame.
///
/// Deliberately a plain (auto-dispose) provider, not `keepAlive`: the
/// value this actually needs to persist is
/// [mushafPageRenderModelProvider]'s own `keepAlive` cache entry, which
/// this call populates as a side effect — this wrapper has no useful
/// lifetime of its own beyond "warm the real cache once." Riverpod's own
/// family-provider semantics mean two callers requesting the same
/// `(mushafId, pageNumber, availableWidth, availableHeight)` concurrently
/// share this exact one in-flight `Future`, never triggering the warm-up
/// work twice.
@riverpod
Future<MushafPageRenderModel?> mushafPageRenderModelPrewarm(
  Ref ref, {
  required int mushafId,
  required int pageNumber,
  required double availableWidth,
  required double availableHeight,
}) async {
  final bundle = await ref.watch(
    mushafPageDataProvider(mushafId, pageNumber).future,
  );
  // `ref.mounted` must be re-checked after every `await`: this provider is
  // deliberately auto-dispose and fire-and-forget (see doc comment below),
  // so the widget tree/provider scope that started it can legitimately be
  // torn down (navigation away, a test finishing) *while this is still
  // running* — a completely normal occurrence, not an error, and `ref`
  // becomes unusable the instant that happens. Returning quietly here is
  // correct: whatever work already landed in a real `keepAlive` cache
  // (`mushafPageDataProvider`/`mushafPageFontProvider`/
  // `mushafPageRenderModelProvider`) stays there regardless; this
  // provider itself has nothing worth finishing once nobody could ever
  // read its result.
  if (!ref.mounted) return null;
  if (bundle == null) return null;

  final fontFamily = await _resolveFontFamily(
    ref,
    bundle,
    mushafId,
    pageNumber,
  );
  if (!ref.mounted) return null;
  if (bundle.mushaf.renderingType ==
          MushafRenderingType.pageSpecificGlyphFont &&
      fontFamily == null) {
    // The font manifest isn't bundled at all (SHIP_BLOCKED_LICENSE) --
    // nothing to shape correctly yet; matches `MushafPageView`'s own
    // refusal to render Quran glyph text without a confirmed font.
    return null;
  }

  return ref.read(
    mushafPageRenderModelProvider(
      mushafId: mushafId,
      pageNumber: pageNumber,
      availableWidth: availableWidth,
      availableHeight: availableHeight,
      fontFamily: fontFamily,
    ),
  );
}

/// Drives priority-ordered render-model prewarming for the pages around
/// whichever one is currently visible, and bounds
/// [mushafPageRenderModelProvider]'s cache to the same window it fills --
/// the presentation-side counterpart to [QpcPageFontManager.preloadAround]
/// (`docs/MUSHAF_RENDERING.md` §1/§4), but for the shaped render model
/// rather than the font bytes.
///
/// Priority order, matching the font manager's own radius exactly so both
/// caches stay in lock-step:
/// 1. the current page (awaited -- this is what a swipe just landed on,
///    or is about to);
/// 2. immediate neighbors, page ± 1 (awaited together, after priority 1);
/// 3. outer neighbors, page ± 2 (fire-and-forget -- never awaited by
///    [prewarmAround]'s own caller, and never allowed to delay priority
///    1/2 landing first).
///
/// Never blocks the currently visible page: [prewarmAround] itself should
/// always be called `unawaited` by its caller, and even internally, only
/// priority 1 and 2 are awaited in sequence -- priority 3 is fired and
/// left to complete on its own.
///
/// Staleness: a new [prewarmAround] call for a different `currentPage`
/// bumps an internal generation counter; a rapid multi-page swipe (A -> B
/// -> C before A's lower-priority tiers finish) stops *scheduling further
/// tiers* for A's now-stale target once C's call starts, without
/// corrupting any cache state -- every warm operation is keyed by its own
/// explicit page number (never a shared mutable "current" slot), so a
/// late-completing stale `Future` can only ever populate *its own* page's
/// correct cache entry, never associate its result with a different page.
///
/// `keepAlive: true`: this holds real state (`_warmedPages`, the
/// generation counter) that must survive between calls for its whole job
/// (staleness detection, window eviction) to work at all -- an
/// auto-dispose Notifier with no active listeners (nothing ever `watch`es
/// this; every caller only ever `read`s its `.notifier` to invoke a
/// method) would be disposed and lose that state almost immediately.
@Riverpod(keepAlive: true)
class MushafPagePrewarmController extends _$MushafPagePrewarmController {
  @override
  void build() {}

  int _generation = 0;
  int? _mushafId;
  double? _availableWidth;
  double? _availableHeight;
  final Set<int> _warmedPages = {};

  /// Every page number this controller currently believes is warmed in
  /// [mushafPageRenderModelProvider]'s cache, for the last
  /// `(mushafId, availableWidth, availableHeight)` it was called with --
  /// exposed for tests verifying the cache window, never used by
  /// production code as anything but internal bookkeeping.
  @visibleForTesting
  Set<int> get warmedPagesForTest => Set.unmodifiable(_warmedPages);

  /// The most recently scheduled priority-3 (outer-neighbor) work, if any
  /// is still in flight — `null` once idle. [prewarmAround] itself never
  /// awaits this (priority 3 is deliberately fire-and-forget, so the
  /// currently visible page is never blocked on it); this exists purely
  /// so a test can deterministically wait for a *specific* prewarm call's
  /// full effect (including eviction, which only runs after priority 3
  /// settles) instead of guessing with delays.
  Future<void>? _pendingOuterTier;

  @visibleForTesting
  Future<void> debugSettleForTest() async => _pendingOuterTier;

  Future<void> prewarmAround({
    required int mushafId,
    required int currentPage,
    required int totalPages,
    required double availableWidth,
    required double availableHeight,
  }) async {
    final sameTarget =
        _mushafId == mushafId &&
        _availableWidth == availableWidth &&
        _availableHeight == availableHeight;
    if (!sameTarget) {
      // A different Mushaf or viewport invalidates our own window
      // tracking -- the render-model provider's own cache key already
      // changed too, so previously-tracked pages are simply unreachable
      // dead cache weight now, not something that needs chasing down.
      _warmedPages.clear();
      _mushafId = mushafId;
      _availableWidth = availableWidth;
      _availableHeight = availableHeight;
    }

    final generation = ++_generation;
    bool isStale() => generation != _generation;

    Future<void> warm(int page) async {
      if (page < 1 || page > totalPages) return;
      await ref.read(
        mushafPageRenderModelPrewarmProvider(
          mushafId: mushafId,
          pageNumber: page,
          availableWidth: availableWidth,
          availableHeight: availableHeight,
        ).future,
      );
      // The whole provider scope (e.g. navigating away, or a test tearing
      // down) can legitimately be disposed while this was in flight --
      // `_warmedPages`/further `ref` use is meaningless at that point.
      if (!ref.mounted) return;
      _warmedPages.add(page);
    }

    // Priority 1: the current page.
    await warm(currentPage);
    if (!ref.mounted || isStale()) return;

    // Priority 2: immediate neighbors.
    await Future.wait([warm(currentPage - 1), warm(currentPage + 1)]);
    if (!ref.mounted) return;
    _evictOutsideWindow(currentPage, totalPages);
    if (isStale()) return;

    // Priority 3: outer neighbors -- lowest priority, fire-and-forget.
    final outerTier =
        Future.wait([warm(currentPage - 2), warm(currentPage + 2)]).then((_) {
          if (ref.mounted && !isStale()) {
            _evictOutsideWindow(currentPage, totalPages);
          }
        });
    _pendingOuterTier = outerTier;
    unawaited(
      outerTier.whenComplete(() {
        if (identical(_pendingOuterTier, outerTier)) _pendingOuterTier = null;
      }),
    );
  }

  /// Keeps [mushafPageRenderModelProvider]'s cache bounded to
  /// `[currentPage - mushafRenderModelWindowRadius, currentPage +
  /// mushafRenderModelWindowRadius]` -- the same window [prewarmAround]
  /// fills, never more. `invalidate`s each evicted page's *exact* cached
  /// family instance (recovering the font family it was actually built
  /// with via [_cachedFontFamilyOrNull], never a guessed/default one --
  /// invalidating the wrong family instance would silently leave the real,
  /// heavy cache entry behind). Deliberately never touches
  /// [mushafPageDataProvider] (page data is a handful of small Dart
  /// objects, cheap to keep for the app's lifetime per that provider's own
  /// doc comment) or any font registration (fonts are never unloaded, per
  /// [QpcPageFontManager]'s documented platform limitation) -- only the
  /// heavy, per-viewport shaped render model is bounded.
  void _evictOutsideWindow(int currentPage, int totalPages) {
    final mushafId = _mushafId;
    final width = _availableWidth;
    final height = _availableHeight;
    if (mushafId == null || width == null || height == null) return;

    final keep = <int>{
      for (
        var p = currentPage - mushafRenderModelWindowRadius;
        p <= currentPage + mushafRenderModelWindowRadius;
        p++
      )
        if (p >= 1 && p <= totalPages) p,
    };
    final toEvict = _warmedPages.difference(keep).toList();
    for (final page in toEvict) {
      final fontFamily = _cachedFontFamilyOrNull(ref, mushafId, page);
      ref.invalidate(
        mushafPageRenderModelProvider(
          mushafId: mushafId,
          pageNumber: page,
          availableWidth: width,
          availableHeight: height,
          fontFamily: fontFamily,
        ),
      );
    }
    _warmedPages.removeAll(toEvict);
  }
}
