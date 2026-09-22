import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final int pageNumber;
  final MushafAppearanceColors colors;
  final ValueChanged<MushafTokenHitRect>? onWordTap;

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

  @override
  void didUpdateWidget(covariant QuranEngineMushafPageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      setState(() {
        _page = null;
        _loadError = null;
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
      final previous = _page;
      if (previous != null) backend.disposePage(previous);
      setState(() {
        _backend = backend;
        _page = page;
      });
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
    final backend = _backend;
    final page = _page;
    if (backend != null && page != null) backend.disposePage(page);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            'This page could not be rendered.',
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
    return page.buildView(
      ink: widget.colors.text,
      paper: widget.colors.background,
      onWordHit: widget.onWordTap,
      onDecorationHit: widget.onWordTap,
    );
  }
}
