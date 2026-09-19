import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/application/translation_selection_controller.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../quran/domain/models/translation_models.dart';
import '../../../quran/translation_providers.dart';
import 'mushaf_page_providers.dart';

part 'mushaf_page_translations.g.dart';

/// Every active translation's text for every ayah on one Mushaf page,
/// keyed by ayahId then slug — the batched data source for
/// `MushafTranslationSheet` (Milestone 9's "use a separate sheet so the
/// printed page remains visually clean" requirement).
///
/// Ayah identity for the page comes for free from the page's own token data
/// ([MushafPageBundle.tokensByLineNumber]'s `quranWord` tokens'
/// `canonicalAyahId`s — markers carry no canonical ayah and are excluded) —
/// no extra repository call needed just to know which verses are on the
/// page.
/// Translation text is then loaded in a small, fixed number of queries:
/// one per (chapter segment on the page) × (active translation), via
/// [TranslationRepository.getVerseRangeText] — never one query per verse.
@riverpod
Future<Map<int, Map<String, TranslationVerseText>>> mushafPageTranslations(
  Ref ref,
  int mushafId,
  int pageNumber,
) async {
  final activeSlugs = ref.watch(translationSelectionControllerProvider);
  if (activeSlugs.isEmpty) return const {};

  final page = await ref.watch(
    mushafPageDataProvider(mushafId, pageNumber).future,
  );
  if (page == null) return const {};

  final ayahIds = <int>{
    for (final tokens in page.tokensByLineNumber.values)
      for (final token in tokens)
        if (token.tokenType == MushafTokenType.quranWord)
          token.canonicalAyahId!,
  };
  if (ayahIds.isEmpty) return const {};

  // Group by chapter so each chapter segment on the page is one
  // `getVerseRangeText` call per active translation, not one per verse.
  final versesByChapter = <int, List<int>>{};
  for (final ayahId in ayahIds) {
    final chapterNo = ayahId ~/ 1000;
    final verseNo = ayahId % 1000;
    versesByChapter.putIfAbsent(chapterNo, () => []).add(verseNo);
  }

  final repository = ref.watch(translationRepositoryProvider);
  final result = <int, Map<String, TranslationVerseText>>{};
  for (final entry in versesByChapter.entries) {
    final chapterNo = entry.key;
    final verseNos = entry.value..sort();
    final range = (
      chapterNo: chapterNo,
      fromVerseNo: verseNos.first,
      toVerseNo: verseNos.last,
    );
    for (final slug in activeSlugs) {
      final texts = await repository.getVerseRangeText(range, slug: slug);
      for (final text in texts) {
        final ayahId = chapterNo * 1000 + text.verseNo;
        if (!ayahIds.contains(ayahId)) continue;
        result.putIfAbsent(ayahId, () => {})[slug] = text;
      }
    }
  }
  return result;
}

/// Metadata for every currently active, installed translation — the same
/// small lookup `ReaderSessionState.translationBooks` performs, reused here
/// so the Mushaf sheet can show each block's author attribution too.
@riverpod
Future<Map<String, TranslationBook>> activeTranslationBooks(Ref ref) async {
  final activeSlugs = ref.watch(translationSelectionControllerProvider);
  final repository = ref.watch(translationRepositoryProvider);
  final books = <String, TranslationBook>{};
  for (final slug in activeSlugs) {
    final book = await repository.getInstalledTranslation(slug);
    if (book != null) books[slug] = book;
  }
  return books;
}
