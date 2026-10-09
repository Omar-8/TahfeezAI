import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/tafsir_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../quran/application/canonical_ayah_word_text.dart';
import '../../../quran/domain/models/translation_models.dart';
import '../../../quran/presentation/translation_block.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_translations.dart';
import '../domain/mushaf_appearance.dart';

/// The Mushaf's "long-press a word" destination: the word's whole ayah —
/// its reference, its canonical text, its active translations and a way
/// to its tafsir. The ayah stays highlighted on the page while this is
/// open (`QuranEngineMushafPageContent.onWordLongPress`).
///
/// The Arabic is the ayah's canonical words ([canonicalAyahTextProvider]),
/// never the page's own glyph data, in Scheherazade New — the Quran-text
/// font Home's Daily Ayah uses.
Future<void> showAyahDetailSheet(
  BuildContext context, {
  required int mushafId,
  required int pageNumber,
  required int ayahId,
}) => showTahfeezModalBottomSheet<void>(
  context: context,
  title: AppLocalizations.of(context).ayahDetails,
  builder: (context) => _AyahDetailSheetBody(
    mushafId: mushafId,
    pageNumber: pageNumber,
    ayahId: ayahId,
  ),
);

class _AyahDetailSheetBody extends ConsumerWidget {
  const _AyahDetailSheetBody({
    required this.mushafId,
    required this.pageNumber,
    required this.ayahId,
  });

  final int mushafId;
  final int pageNumber;
  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chapterNo = ayahId ~/ 1000;
    final verseNo = ayahId % 1000;
    final surahName = [
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        if (s.surah.surahNo == chapterNo) s.localizedName ?? s.arabicName,
    ].firstOrNull;
    final text = ref.watch(canonicalAyahTextProvider(ayahId: ayahId)).value;
    final translations = ref
        .watch(mushafPageTranslationsProvider(mushafId, pageNumber))
        .value?[ayahId];
    final books =
        ref.watch(activeTranslationBooksProvider).value ??
        const <String, TranslationBook>{};
    final quranTextColor = ref
        .watch(mushafAppearanceControllerProvider)
        .colors
        .text;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        TahfeezSpacing.sm,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  surahName == null
                      ? '$chapterNo:$verseNo'
                      : l10n.homeDailyAyahReferenceNamed(surahName, verseNo),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('ayah-sheet-tafsir'),
                onPressed: () => openTafsirReader(
                  context,
                  chapterNo: chapterNo,
                  verseNo: verseNo,
                ),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(l10n.readerTafsir),
              ),
            ],
          ),
          if (text != null)
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: quranTextStyle(
                  color: quranTextColor,
                  fontFamily: 'Scheherazade New',
                  fontSize: 26,
                ),
              ),
            ),
          if (translations != null)
            for (final entry in translations.entries)
              TranslationBlock(
                verseText: entry.value,
                authorName: books[entry.key]?.author ?? entry.key,
              ),
        ],
      ),
    );
  }
}
