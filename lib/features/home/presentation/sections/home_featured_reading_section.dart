import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/home_providers.dart';
import '../coming_soon.dart';

/// Home's "featured Quran reading" section
/// (`docs/reference/11_HOME_SPEC.md` §5): a horizontal rail of curated
/// chapters. Renders an unavailable-resource state instead of any chapter
/// card while no Quran dataset is installed (see
/// `home_providers.dart`'s doc comments).
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
            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TahfeezSpacing.sm),
                itemBuilder: (context, index) {
                  final chapter = list[index];
                  return SizedBox(
                    width: 240,
                    child: TahfeezQuranSectionCard(
                      number: chapter.surah.surahNo,
                      title: chapter.name ?? 'Surah ${chapter.surah.surahNo}',
                      subtitle: '${chapter.surah.ayahCount} ayahs',
                      onTap: () => showComingSoon(context),
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
