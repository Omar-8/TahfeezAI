import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/home_providers.dart';
import '../coming_soon.dart';

/// Home's "Recommended / Daily Ayah" section
/// (`docs/reference/11_HOME_SPEC.md` §3). Shows a deterministic, date-seeded
/// chapter/verse reference once a Quran dataset is installed, and an honest
/// "not installed yet" state otherwise — see
/// `lib/features/home/application/home_providers.dart`'s doc comments for
/// why the live app has no dataset installed at this milestone.
class HomeDailyAyahSection extends ConsumerWidget {
  const HomeDailyAyahSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dailyAyah = ref.watch(dailyAyahProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.homeSectionDailyAyah,
          icon: Icons.auto_awesome_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        dailyAyah.when(
          data: (reference) {
            if (reference == null) {
              return TahfeezCard(
                child: TahfeezEmptyView(
                  icon: Icons.menu_book_outlined,
                  message: l10n.homeQuranDatasetUnavailableBody,
                ),
              );
            }
            final label = reference.chapterName != null
                ? l10n.homeDailyAyahReferenceNamed(
                    reference.chapterName!,
                    reference.verseNo,
                  )
                : l10n.homeDailyAyahReference(
                    reference.surahNo,
                    reference.verseNo,
                  );
            return TahfeezCard(
              onTap: () => showComingSoon(context),
              child: Row(
                spacing: TahfeezSpacing.smPlus,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const TahfeezCard(child: TahfeezLoadingView()),
          error: (_, _) => TahfeezCard(
            child: TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message: l10n.homeQuranDatasetUnavailableBody,
            ),
          ),
        ),
      ],
    );
  }
}
