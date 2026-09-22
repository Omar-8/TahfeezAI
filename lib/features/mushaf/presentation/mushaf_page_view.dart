import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mushaf_appearance_controller.dart';
import '../domain/mushaf_appearance.dart';
import 'mushaf_token_hit_rect.dart';
import 'quran_engine_mushaf_page_content.dart';

/// Renders one printed Mushaf page through Quran Engine
/// (`QuranEngineMushafPageContent`) — Tahfeez's Mushaf rendering backend
/// since the Quran Engine migration completed
/// (`docs/QURAN_ENGINE_MIGRATION.md`). The former QPC V2 line-shaping
/// renderer (`MushafPageLayoutEngine`/`MushafPagePainter`/
/// `MushafPageRenderModel`) has been removed.
///
/// Colors come only from [MushafAppearanceController]'s active
/// [MushafAppearanceColors] — never from `Theme.of(context)` — per this
/// project's "do not let application card styling leak into the Mushaf
/// page" rule.
///
/// [mushafId] is accepted for API stability with existing callers
/// (`MushafPager`) but is not otherwise used here: Quran Engine addresses
/// a page purely by [pageNumber], independent of which canonical
/// `Mushaf`/script row Tahfeez's own database happens to use.
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

  /// Kept for API stability with `MushafPager`'s existing call sites; no
  /// longer drives any prewarming decision here (Quran Engine's own
  /// `preloadAround` is triggered directly by
  /// `QuranEngineMushafPageContent` on every page load, not gated on
  /// "current" vs. pre-built-neighbor the way the former QPC V2 render
  /// -model prewarm controller needed).
  final bool isCurrentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;

    return Container(
      color: colors.background,
      child: QuranEngineMushafPageContent(
        pageNumber: pageNumber,
        colors: colors,
        onWordTap: onWordTap,
      ),
    );
  }
}
