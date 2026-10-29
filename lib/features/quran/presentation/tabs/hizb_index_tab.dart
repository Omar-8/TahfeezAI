import 'package:flutter/material.dart';

import '../../../../quran/presentation/surah_name_calligraphy.dart';
import '../../../../core/ui/bar_space.dart';
import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../quran/domain/models/quran_location.dart';
import '../../application/quran_index_providers.dart';
import '../../../../quran/presentation/quran_unavailable_view.dart';

/// The Hizb navigator tab: all 60 Hizb (two per Juz), analogous to
/// [JuzIndexTab].
class HizbIndexTab extends ConsumerWidget {
  const HizbIndexTab({super.key, required this.onSelect});

  final ValueChanged<QuranLocation> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hizbList = ref.watch(indexedHizbListProvider);

    return hizbList.when(
      data: (units) {
        if (units.isEmpty) {
          return const QuranUnavailableView();
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
                    .homeContinueReadingHizb(unit.unitNo),
                subtitle: AppLocalizations.of(context)
                    .quranStartsAt(unit.start.surahNo, unit.start.startAyahNo),
                // The surah it starts in, as the Mushaf writes its name.
                art: SurahNameCalligraphy(
                  surahNo: unit.start.surahNo,
                  height: 24,
                  maxWidth: 90,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onTap: () => onSelect(QuranLocation.hizb(unit.unitNo)),
              ),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => const QuranUnavailableView(),
    );
  }
}
