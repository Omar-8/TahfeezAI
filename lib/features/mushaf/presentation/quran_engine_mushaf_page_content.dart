import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mushaf_quran_engine_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'mushaf_page_render_model.dart';

/// The [MushafRenderBackend.quranEngine] counterpart to `MushafPageView`'s
/// own QPC V2 content — renders [pageNumber] through
/// [mushafQuranEngineBackendProvider] instead of the font-based line
/// shaping pipeline. Reports word/decoration taps as the exact same
/// [MushafTokenHitRect] shape the QPC path already reports, so
/// `MushafPager`'s tap handling needs no backend-specific branch.
///
/// Colors still come only from [MushafAppearanceColors] — never
/// `Theme.of(context)` — matching `MushafPageView`'s own rule.
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
      final previous = _page;
      if (previous != null) backend.disposePage(previous);
      setState(() {
        _backend = backend;
        _page = page;
      });
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
      final message = _loadError is QuranEngineReleaseModeBlockedException
          ? 'Quran Engine rendering is pending licensing clearance.'
          : 'This page could not be rendered.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
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

    return AspectRatio(
      aspectRatio: page.aspectRatio,
      child: page.buildView(
        ink: widget.colors.text,
        paper: widget.colors.background,
        onWordHit: widget.onWordTap,
        onDecorationHit: widget.onWordTap,
      ),
    );
  }
}
