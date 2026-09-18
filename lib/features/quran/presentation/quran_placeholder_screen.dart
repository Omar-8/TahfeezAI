import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/quran_providers.dart';

/// The Quran tab's content for this milestone. Chapter/Juz/Hizb/page
/// navigation is the Quran Index & Navigation milestone's job (Milestone
/// 5) — this screen only proves the shell's second destination is real and
/// discoverable, per this milestone's "Quran should remain highly
/// discoverable/prominent" requirement, without building ahead of that
/// milestone's scope.
class QuranPlaceholderScreen extends ConsumerWidget {
  const QuranPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chapterCount = ref.watch(quranRepositoryProvider).chapterCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.md,
          children: [
            Text(
              l10n.quranPlaceholderTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TahfeezEmptyView(
              icon: Icons.menu_book_outlined,
              message:
                  '${l10n.quranPlaceholderBody}\n'
                  '${l10n.quranPlaceholderChapterCount(chapterCount)}',
            ),
          ],
        ),
      ),
    );
  }
}
