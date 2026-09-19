import 'package:flutter/material.dart';

import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../quran/domain/models/search_models.dart';
import '../../../../quran/domain/search_normalizer.dart';
import 'search_match_highlight.dart';

/// Renders one [SearchResults]' worth of results as labeled sections —
/// Quick Links, Surah matches, Quran (Arabic) matches, Translation matches
/// — hiding any section with no hits, per this milestone's distinct-
/// section-per-domain UI requirement. Every row navigates via
/// [searchHitLocation] + [goToQuranLocation], satisfying "every result
/// should resolve to `QuranLocation`."
class SearchResultSections extends StatelessWidget {
  const SearchResultSections({
    super.key,
    required this.results,
    required this.query,
    required this.onResultTap,
  });

  final SearchResults results;
  final String query;
  final ValueChanged<SearchHit> onResultTap;

  @override
  Widget build(BuildContext context) {
    final translationTokens = const SearchNormalizer().tokenize(
      query,
      arabicScript: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TahfeezSpacing.md,
      children: [
        if (results.quickLinks.isNotEmpty)
          _Section(
            title: 'Quick links',
            icon: Icons.bolt_outlined,
            children: [
              for (final hit in results.quickLinks)
                if (hit is QuickLinkSearchHit)
                  TahfeezListRow(
                    title: hit.label,
                    leading: const Icon(Icons.arrow_forward),
                    onTap: () => onResultTap(hit),
                  ),
            ],
          ),
        if (results.surahHits.isNotEmpty)
          _Section(
            title: 'Surahs',
            icon: Icons.menu_book_outlined,
            children: [
              for (final hit in results.surahHits)
                if (hit is SurahSearchHit)
                  TahfeezListRow(
                    title: hit.matchedName,
                    subtitle: 'Surah ${hit.surahNo}',
                    onTap: () => onResultTap(hit),
                  ),
            ],
          ),
        if (results.arabicHits.isNotEmpty)
          _Section(
            title: 'Quran text',
            icon: Icons.auto_stories_outlined,
            children: [
              for (final hit in results.arabicHits)
                if (hit is ArabicTextSearchHit)
                  _ArabicResultRow(hit: hit, onTap: () => onResultTap(hit)),
            ],
          ),
        if (results.translationHits.isNotEmpty)
          _Section(
            title: 'Translations',
            icon: Icons.translate_outlined,
            children: [
              for (final hit in results.translationHits)
                if (hit is TranslationTextSearchHit)
                  _TranslationResultRow(
                    hit: hit,
                    tokens: translationTokens,
                    onTap: () => onResultTap(hit),
                  ),
            ],
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(title: title, icon: icon),
        const SizedBox(height: TahfeezSpacing.xs),
        ...children,
      ],
    );
  }
}

class _ArabicResultRow extends StatelessWidget {
  const _ArabicResultRow({required this.hit, required this.onTap});

  final ArabicTextSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TahfeezSpacing.md,
          vertical: TahfeezSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.xs,
          children: [
            Text(
              '${hit.chapterNo}:${hit.verseNo}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                hit.matchedText,
                textAlign: TextAlign.right,
                style: quranTextStyle(context, fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationResultRow extends StatelessWidget {
  const _TranslationResultRow({
    required this.hit,
    required this.tokens,
    required this.onTap,
  });

  final TranslationTextSearchHit hit;
  final List<String> tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TahfeezSpacing.md,
          vertical: TahfeezSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.xs,
          children: [
            Text(
              '${hit.chapterNo}:${hit.verseNo} · ${hit.translationDisplayName}',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            Text.rich(
              TextSpan(
                children: highlightMatches(
                  hit.matchedText,
                  tokens,
                  bodyStyle,
                  bodyStyle?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ) ??
                      TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
