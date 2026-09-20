import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/mushaf_models.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../application/mushaf_render_backend_controller.dart';
import '../application/qpc_page_font_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/mushaf_render_backend.dart';
import '../domain/qpc_page_font_manager.dart';
import 'mushaf_layout_providers.dart';
import 'mushaf_page_painter.dart';
import 'mushaf_page_render_model.dart';
import 'mushaf_prewarm_controller.dart';
import 'quran_engine_mushaf_page_content.dart';

/// Renders one printed Mushaf page — a single [RepaintBoundary]-wrapped
/// [CustomPaint] ([MushafPagePainter]) drawing an already-fully-shaped
/// [MushafPageRenderModel]
/// (`mushaf_layout_providers.dart`'s `mushafPageRenderModelProvider`), not
/// a separate widget/render object per line or per word — the concrete
/// form of this project's "shape at line level, one CustomPainter per
/// page" performance requirement. Word taps are resolved by testing the
/// tap position against [MushafTokenHitRect]s carried in that same render
/// model, recovered from each line's one real shaped paragraph via
/// `TextPainter.getBoxesForSelection` — never computed by hand.
///
/// Colors come only from [MushafAppearanceController]'s active
/// [MushafAppearanceColors] — never from `Theme.of(context)` — per this
/// milestone's explicit "do not let application card styling leak into the
/// Mushaf page" requirement.
class MushafPageView extends ConsumerWidget {
  const MushafPageView({
    super.key,
    required this.mushafId,
    required this.pageNumber,
    this.onWordTap,
    this.isCurrentPage = false,
  });

  final int mushafId;
  final int pageNumber;
  final ValueChanged<MushafTokenHitRect>? onWordTap;

  /// Whether this instance represents the page the pager considers
  /// authoritatively "current" right now — set by [MushafPager], which is
  /// the only thing that knows this: `PageView.builder`'s
  /// `allowImplicitScrolling`/`scrollCacheExtent` (`mushaf_pager.dart`)
  /// pre-build neighboring pages' widgets too, so *this widget existing*
  /// is not by itself proof of being the visible page. Only the current
  /// page triggers [MushafPagePrewarmController.prewarmAround] — every
  /// pre-built neighbor calling it with *its own* page number as "current"
  /// would thrash the controller's single-target tracking between
  /// competing pages every frame, never settling (a real bug this field
  /// exists to prevent, caught by a `pumpAndSettle` timeout in testing).
  final bool isCurrentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;

    // The single place this widget forks on which engine actually draws
    // the page — everything else (`MushafPager`'s tap handling, the
    // Reader's chrome) is identical regardless of backend, since both
    // report hits as the same `MushafTokenHitRect`.
    final backend = ref.watch(mushafRenderBackendControllerProvider);
    if (backend == MushafRenderBackend.quranEngine) {
      return Container(
        color: colors.background,
        child: QuranEngineMushafPageContent(
          pageNumber: pageNumber,
          colors: colors,
          onWordTap: onWordTap,
        ),
      );
    }

    final bundleAsync = ref.watch(mushafPageDataProvider(mushafId, pageNumber));

    return Container(
      color: colors.background,
      child: bundleAsync.when(
        data: (bundle) {
          if (bundle == null) {
            return _MushafPagePlaceholder(colors: colors);
          }
          if (bundle.mushaf.renderingType !=
              MushafRenderingType.pageSpecificGlyphFont) {
            // No page-specific font concept for this rendering type — no
            // font gating needed.
            return _MushafPageContent(
              mushafId: mushafId,
              pageNumber: pageNumber,
              totalPages: bundle.mushaf.pageCount,
              colors: colors,
              onWordTap: onWordTap,
              fontFamily: null,
              isCurrentPage: isCurrentPage,
            );
          }

          // A page-specific-glyph Mushaf must never render its Quran text
          // with any font other than that exact page's own — wait for it
          // rather than showing a fallback/previous-page font, per
          // docs/QURAN_DATA_PROVENANCE.md §8.
          final fontAsync = ref.watch(
            mushafPageFontProvider(mushafId, pageNumber),
          );
          return fontAsync.when(
            data: (handle) {
              if (handle == null) {
                return _MushafFontPendingPlaceholder(colors: colors);
              }
              return _MushafPageContent(
                mushafId: mushafId,
                pageNumber: pageNumber,
                totalPages: bundle.mushaf.pageCount,
                colors: colors,
                onWordTap: onWordTap,
                fontFamily: handle.fontFamily,
                isCurrentPage: isCurrentPage,
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.secondaryText),
            ),
            error: (error, _) =>
                error is QpcWebFontDeliveryNotConfiguredException
                ? _MushafWebFontNotConfiguredPlaceholder(colors: colors)
                : _MushafFontErrorPlaceholder(colors: colors),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.secondaryText),
        ),
        error: (_, _) => _MushafPagePlaceholder(colors: colors),
      ),
    );
  }
}

class _MushafPagePlaceholder extends StatelessWidget {
  const _MushafPagePlaceholder({required this.colors});

  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This page will appear automatically once a Quran dataset is added to the app.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.secondaryText),
      ),
    );
  }
}

/// Shown when Mushaf line/token data is real and ready, but no page-font
/// manifest is bundled in this build — the honest `SHIP_BLOCKED_LICENSE`
/// state (`docs/QURAN_DATA_PROVENANCE.md` §8), never a silent fallback to
/// an approximate font.
class _MushafFontPendingPlaceholder extends StatelessWidget {
  const _MushafFontPendingPlaceholder({required this.colors});

  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Authentic Mushaf rendering is pending font packaging clearance.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.secondaryText),
      ),
    );
  }
}

class _MushafFontErrorPlaceholder extends StatelessWidget {
  const _MushafFontErrorPlaceholder({required this.colors});

  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This page\'s Mushaf font could not be loaded.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.secondaryText),
      ),
    );
  }
}

/// Shown specifically on Web when [QpcWebFontDeliveryNotConfiguredException]
/// is thrown (`QPC_FONT_BASE_URL` unset) — distinct from
/// [_MushafFontErrorPlaceholder]'s generic "could not be loaded" message
/// (a real fetch failure) so this honest, expected-while-
/// `SHIP_BLOCKED_LICENSE` state is never confused with a bug to retry.
/// Never a silent fallback to a system font.
class _MushafWebFontNotConfiguredPlaceholder extends StatelessWidget {
  const _MushafWebFontNotConfiguredPlaceholder({required this.colors});

  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Mushaf page font resources are not configured for Web.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.secondaryText),
      ),
    );
  }
}

class _MushafPageContent extends ConsumerWidget {
  const _MushafPageContent({
    required this.mushafId,
    required this.pageNumber,
    required this.totalPages,
    required this.colors,
    required this.onWordTap,
    required this.fontFamily,
    required this.isCurrentPage,
  });

  final int mushafId;
  final int pageNumber;
  final int totalPages;
  final MushafAppearanceColors colors;
  final ValueChanged<MushafTokenHitRect>? onWordTap;
  final bool isCurrentPage;

  /// The exact font this page's Quran glyph text must be drawn with — set
  /// only once `QpcPageFontManager.ensureLoaded` has confirmed it, or
  /// `null` for a rendering type with no page-specific font concept.
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No page footer: the page/Juz/Surah context it used to show now lives
    // in the (live, per-page) app bar title instead
    // (`MushafPageTitle`/`lib/features/reader/presentation/reader_screen.dart`),
    // and the vertical space it used to take, plus the slack this padding
    // used to reserve above/below the 15 lines, is given back to the text
    // itself — see `buildMushafPageRenderModel`'s `availableHeight`.
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final renderModel = ref.watch(
            mushafPageRenderModelProvider(
              mushafId: mushafId,
              pageNumber: pageNumber,
              availableWidth: constraints.maxWidth,
              availableHeight: constraints.maxHeight,
              fontFamily: fontFamily,
            ),
          );

          // Deferred to after this frame (never called synchronously from
          // build): warms neighboring pages' render models — font load
          // *then* line shaping — ahead of a swipe landing on them, so
          // that work never happens on the destination page's own first
          // frame. Never awaited here: this page's own paint above never
          // waits on a neighbor.
          //
          // Gated on `isCurrentPage`: `PageView.builder`'s
          // `allowImplicitScrolling`/`scrollCacheExtent`
          // (`mushaf_pager.dart`) keep neighboring pages' widgets built
          // too, each running this same `LayoutBuilder`. If *every* one of
          // them called `prewarmAround` with *its own* page number as
          // "current", the controller's single-target tracking would
          // thrash between competing pages every frame and never settle —
          // a real bug caught by a `pumpAndSettle` timeout in testing.
          // Only the pager's own authoritative current page may drive
          // prewarming.
          if (isCurrentPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(
                ref
                    .read(mushafPagePrewarmControllerProvider.notifier)
                    .prewarmAround(
                      mushafId: mushafId,
                      currentPage: pageNumber,
                      totalPages: totalPages,
                      availableWidth: constraints.maxWidth,
                      availableHeight: constraints.maxHeight,
                    ),
              );
            });
          }

          if (renderModel == null) return const SizedBox.shrink();

          // One painter for the whole page — every line's text was already
          // shaped once when `renderModel` was built (never here, and
          // never per word) — wrapped in its own `RepaintBoundary` so
          // repainting this page (e.g. a page-turn animation frame) never
          // forces sibling pages/chrome to repaint, and marked `isComplex`/
          // `willChange: false`: a Mushaf page's shaped text is static
          // between render-model rebuilds, never animating on its own.
          return RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: onWordTap == null
                  ? null
                  : (details) {
                      final hitRect = _hitRectAt(
                        renderModel,
                        details.localPosition,
                      );
                      if (hitRect != null) onWordTap!(hitRect);
                    },
              child: CustomPaint(
                size: renderModel.size,
                isComplex: true,
                willChange: false,
                painter: MushafPagePainter(renderModel),
              ),
            ),
          );
        },
      ),
    );
  }

  MushafTokenHitRect? _hitRectAt(
    MushafPageRenderModel renderModel,
    Offset position,
  ) {
    for (final line in renderModel.lines) {
      if (line is! MushafQuranTextLineRenderModel) continue;
      for (final hitRect in line.tokenRects) {
        if (hitRect.rect.contains(position)) return hitRect;
      }
    }
    return null;
  }
}
