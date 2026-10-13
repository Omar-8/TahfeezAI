import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/routing/quran_location_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../application/home_providers.dart';

/// Home's "Featured Reading": a horizontal rail of curated chapters, each
/// opening the chapter. Al-Kahf leads on Fridays and Al-Mulk in the evening,
/// marked as such. An unavailable-resource state while no Quran dataset is
/// installed.
class HomeFeaturedReadingSection extends ConsumerWidget {
  const HomeFeaturedReadingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chapters = ref.watch(featuredReadingChaptersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionFeaturedReading,
          icon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        chapters.when(
          data: (list) {
            if (list.isEmpty) {
              return TahfeezCard(
                child: TahfeezEmptyView(
                  icon: Icons.menu_book_outlined,
                  message: l10n.homeFeaturedReadingUnavailable,
                ),
              );
            }
            // As tall as a card's content (a number badge, the name and a
            // line under it), growing with the text size.
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            return SizedBox(
              height: 44 + 40 * textScale,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TahfeezSpacing.sm),
                itemBuilder: (context, index) {
                  final chapter = list[index];
                  final count = l10n.homeFeaturedAyahCount(
                    chapter.surah.ayahCount,
                  );
                  final occasion = switch (chapter.occasion) {
                    FeaturedOccasion.friday => l10n.homeFeaturedFriday,
                    FeaturedOccasion.night => l10n.homeFeaturedNight,
                    null => null,
                  };
                  // Wider with larger text, never wider than most of the
                  // screen; its lines shortened to fit (one line each).
                  return SizedBox(
                    width: (240 * textScale.clamp(1.0, 1.4)).clamp(
                      0,
                      MediaQuery.sizeOf(context).width * 0.85,
                    ),
                    child: TahfeezQuranSectionCard(
                      singleLine: true,
                      number: chapter.surah.surahNo,
                      title:
                          chapter.name ??
                          l10n.homeContinueReadingSurah(chapter.surah.surahNo),
                      subtitle: occasion == null ? count : '$occasion · $count',
                      onTap: () => goToQuranLocation(
                        context,
                        QuranLocation.surah(chapter.surah.surahNo),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) => TahfeezCard(
            child: TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: l10n.homeFeaturedReadingUnavailable,
            ),
          ),
        ),
      ],
    );
  }
}
