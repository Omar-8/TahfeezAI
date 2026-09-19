import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/quran_chapter_localization.dart';
import '../../../quran/domain/models/mushaf_models.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../application/qpc_page_font_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/mushaf_line_layout.dart';
import 'mushaf_layout_providers.dart';
import 'mushaf_line_renderer.dart';

/// Renders one printed Mushaf page: margins, a Juz/Hizb/page-number footer,
/// and every line — chapter-name headers, Bismillah markers, and justified
/// Quran-text lines via the active [MushafLineRenderer].
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
  });

  final int mushafId;
  final int pageNumber;
  final ValueChanged<MushafWordPlacement>? onWordTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;
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
              bundle: bundle,
              colors: colors,
              onWordTap: onWordTap,
              fontFamily: null,
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
                bundle: bundle,
                colors: colors,
                onWordTap: onWordTap,
                fontFamily: handle.fontFamily,
              );
            },
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.secondaryText),
            ),
            error: (_, _) => _MushafFontErrorPlaceholder(colors: colors),
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

class _MushafPageContent extends ConsumerWidget {
  const _MushafPageContent({
    required this.bundle,
    required this.colors,
    required this.onWordTap,
    required this.fontFamily,
  });

  final MushafPageBundle bundle;
  final MushafAppearanceColors colors;
  final ValueChanged<MushafWordPlacement>? onWordTap;

  /// The exact font this page's Quran glyph text must be drawn with — set
  /// only once `QpcPageFontManager.ensureLoaded` has confirmed it, or
  /// `null` for a rendering type with no page-specific font concept.
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(mushafPageLayoutEngineProvider);
    final renderer = ref.watch(mushafLineRendererProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = engine.layoutPage(
                  pageNumber: bundle.pageNumber,
                  lines: bundle.lines,
                  tokensByLineNumber: bundle.tokensByLineNumber,
                  availableWidth: constraints.maxWidth,
                  fontFamily: fontFamily,
                );
                final lineHeight = layout.lines.isEmpty
                    ? 0.0
                    : constraints.maxHeight / layout.lines.length;

                return Column(
                  children: [
                    for (final line in layout.lines)
                      SizedBox(
                        key: ValueKey(
                          'mushaf-page-${bundle.pageNumber}-line-${line.lineNumber}',
                        ),
                        width: constraints.maxWidth,
                        height: lineHeight,
                        child: _lineContent(
                          context,
                          ref,
                          line,
                          renderer,
                          constraints.maxWidth,
                          lineHeight,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          _PageFooter(bundle: bundle, colors: colors),
        ],
      ),
    );
  }

  Widget _lineContent(
    BuildContext context,
    WidgetRef ref,
    MushafLineLayout line,
    MushafLineRenderer renderer,
    double availableWidth,
    double lineHeight,
  ) {
    switch (line.lineType) {
      case MushafLineType.surahHeader:
        return _SurahHeaderLine(surahNo: line.surahNo, colors: colors);
      case MushafLineType.bismillah:
        return _BismillahLine(colors: colors);
      case MushafLineType.quranText:
        return renderer.buildLine(
          context,
          layout: line,
          availableWidth: availableWidth,
          lineHeight: lineHeight,
          textColor: colors.text,
          fontFamily: fontFamily,
          onWordTap: onWordTap,
        );
    }
  }
}

class _SurahHeaderLine extends ConsumerWidget {
  const _SurahHeaderLine({required this.surahNo, required this.colors});

  final int? surahNo;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (surahNo == null) return const SizedBox.shrink();
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final localization = ref.watch(
      chapterLocalizationProvider(surahNo!, languageCode: languageCode),
    );

    return Center(
      child: Text(
        localization.value?.name ?? 'Surah $surahNo',
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }
}

/// A decorative divider marking where a chapter's Bismillah belongs.
/// Deliberately textless — see `ReaderBismillahItem`'s doc comment
/// (`lib/features/reader/domain/reader_layout_item.dart`) for why: the
/// Bismillah is canonical Quran text with no dedicated source in this
/// milestone's schema.
class _BismillahLine extends StatelessWidget {
  const _BismillahLine({required this.colors});

  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.auto_awesome, size: 14, color: colors.secondaryText),
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({required this.bundle, required this.colors});

  final MushafPageBundle bundle;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    final parts = <String>['Page ${bundle.pageNumber}'];
    if (bundle.juzNo != null) parts.add('Juz ${bundle.juzNo}');
    if (bundle.hizbNos.isNotEmpty) {
      parts.add('Hizb ${bundle.hizbNos.join(', ')}');
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(color: colors.secondaryText, fontSize: 12),
    );
  }
}
