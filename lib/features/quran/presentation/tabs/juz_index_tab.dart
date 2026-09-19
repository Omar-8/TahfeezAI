import 'package:flutter/material.dart';
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
          return const TahfeezEmptyView(
            icon: Icons.menu_book_outlined,
            message: 'This will appear automatically once a Quran dataset is added to the app.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          itemCount: units.length,
          itemBuilder: (context, index) {
            final unit = units[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
              child: TahfeezQuranSectionCard(
                number: unit.unitNo,
                title: 'Juz ${unit.unitNo}',
                subtitle:
                    'Starts at Surah ${unit.start.surahNo}, Ayah ${unit.start.startAyahNo}',
                onTap: () => onSelect(QuranLocation.juz(unit.unitNo)),
              ),
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => const TahfeezEmptyView(
        icon: Icons.menu_book_outlined,
        message: 'This will appear automatically once a Quran dataset is added to the app.',
      ),
    );
  }
}
