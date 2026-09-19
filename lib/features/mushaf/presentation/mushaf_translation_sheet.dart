import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/routing/tafsir_routing.dart';
import '../../../quran/domain/models/translation_models.dart';
import '../../../quran/presentation/translation_block.dart';
import '../application/mushaf_page_translations.dart';

/// Translation content for the current Mushaf page, in a separate sheet so
/// the printed page itself stays visually clean — this milestone's explicit
/// "Mushaf: use a separate bottom/side sheet or panel" requirement.
/// Reuses the same [TranslationBlock] the verse-by-verse reader stacks
/// inline, just presented per-page in an overlay instead.
void showMushafTranslationSheet(
  BuildContext context, {
  required int mushafId,
  required int pageNumber,
}) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Translation & tafsir',
    builder: (context) =>
        _MushafTranslationSheetBody(mushafId: mushafId, pageNumber: pageNumber),
  );
}

class _MushafTranslationSheetBody extends ConsumerWidget {
  const _MushafTranslationSheetBody({
    required this.mushafId,
    required this.pageNumber,
  });

  final int mushafId;
  final int pageNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationsAsync = ref.watch(
      mushafPageTranslationsProvider(mushafId, pageNumber),
    );
    final booksAsync = ref.watch(activeTranslationBooksProvider);

    return translationsAsync.when(
      data: (translationsByAyahId) {
        if (translationsByAyahId.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: TahfeezEmptyView(
              icon: Icons.translate_outlined,
              message: 'No active translations to show for this page. Select translations from the Reader options.',
            ),
          );
        }

        final books = booksAsync.value ?? const <String, TranslationBook>{};
        final sortedAyahIds = translationsByAyahId.keys.toList()..sort();

        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: sortedAyahIds.length,
          separatorBuilder: (_, _) => const Divider(height: TahfeezSpacing.lg),
          itemBuilder: (context, index) {
            final ayahId = sortedAyahIds[index];
            final chapterNo = ayahId ~/ 1000;
            final verseNo = ayahId % 1000;
            final byAyah = translationsByAyahId[ayahId]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TahfeezSpacing.sm,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$chapterNo:$verseNo',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => openTafsirReader(
                        context,
                        chapterNo: chapterNo,
                        verseNo: verseNo,
                      ),
                      child: const Text('Tafsir'),
                    ),
                  ],
                ),
                for (final entry in byAyah.entries)
                  TranslationBlock(
                    verseText: entry.value,
                    authorName: books[entry.key]?.author ?? entry.key,
                  ),
              ],
            );
          },
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => const TahfeezErrorView(
        message: 'Could not load translations for this page.',
      ),
    );
  }
}
