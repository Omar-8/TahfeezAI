import 'package:flutter/material.dart';

import '../../../../quran/presentation/surah_name_calligraphy.dart';
import '../../../../core/ui/bar_space.dart';
import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../application/quran_index_providers.dart';

/// The Juz navigator tab: all 30 Juz, each starting at the chapter/verse its
/// first range begins at (`docs/reference/04_READER_SPEC.md` §4's Juz
/// navigator, Tahfeez-styled).
class JuzIndexTab extends ConsumerWidget {
  const JuzIndexTab({super.key, required this.onSelect});

  final ValueChanged<QuranLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzList = ref.watch(indexedJuzListProvider);

    return juzList.when(
      data: (units) {
        if (units.isEmpty) {
          return TahfeezEmptyView(
            icon: Icons.menu_book_outlined,
            message: AppLocalizations.of(context)
                .homeQuranDatasetUnavailableBody,
          );
        }
        return ListView.builder(
          padding: withBarSpace(
            context,
            const EdgeInsets.all(TahfeezSpacing.md),
          ),
          itemCount: units.length,
          itemBuilder: (context, index) {
            final unit = units[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
              child: TahfeezQuranSectionCard(
                number: unit.unitNo,
                title: AppLocalizations.of(context)
                    .homeContinueReadingJuz(unit.unitNo),
                subtitle: AppLocalizations.of(context)
                    .quranStartsAt(unit.start.surahNo, unit.start.startAyahNo),
                // The surah it starts in, as the Mushaf writes its name.
                art: SurahNameCalligraphy(
                  surahNo: unit.start.surahNo,
                  height: 24,
                  maxWidth: 90,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onTap: () => onSelect(QuranLocation.juz(unit.unitNo)),
              ),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => TahfeezEmptyView(
        icon: Icons.menu_book_outlined,
        message: AppLocalizations.of(context).homeQuranDatasetUnavailableBody,
      ),
    );
  }
}
