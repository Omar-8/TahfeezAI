import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/routing/quran_location_routing.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../../core/theme/quran_text_style.dart';
import '../application/quran_script_code.dart';
import '../domain/models/ayah_models.dart';
import '../domain/models/quran_location.dart';
import '../domain/models/quran_refs.dart';
import '../quran_providers.dart';

part 'quick_reference_sheet.g.dart';

/// A lightweight in-place preview for a translation's inline cross-reference
/// link (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §4's `QuickReference`
/// — independently designed, not a copy of its exact presentation): shows
/// just the referenced verse's Arabic text without leaving the current
/// reading session, plus a "Go to verse" shortcut for when the user really
/// does want to navigate away.
void showQuickReferenceSheet(BuildContext context, VerseRef verse) {
  showTahfeezModalBottomSheet(
    context: context,
    title: '${verse.chapterNo}:${verse.verseNo}',
    builder: (context) => _QuickReferenceBody(verse: verse),
  );
}

@riverpod
Future<List<AyahWord>> _quickReferenceWords(
  Ref ref, {
  required VerseRef verse,
  required String scriptCode,
}) async {
  final repository = ref.watch(quranRepositoryProvider);
  final ayah = await repository.getAyah(verse);
  if (ayah == null) return const [];
  return repository.getWordsForAyah(ayah.id, scriptCode: scriptCode);
}

class _QuickReferenceBody extends ConsumerWidget {
  const _QuickReferenceBody({required this.verse});

  final VerseRef verse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptCode = ref.watch(quranScriptCodeProvider);
    final wordsAsync = ref.watch(
      _quickReferenceWordsProvider(verse: verse, scriptCode: scriptCode),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          wordsAsync.when(
            data: (words) => words.isEmpty
                ? TahfeezEmptyView(
                    icon: Icons.menu_book_outlined,
                    message: AppLocalizations.of(context).verseNotOffline,
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      words.map((w) => w.text).join(' '),
                      textAlign: TextAlign.right,
                      // Plain theme color here, not the reader's own
                      // appearance/font: `lib/quran/presentation/` sits
                      // below `features/mushaf/` in the dependency
                      // direction (`docs/ARCHITECTURE.md` §1), and this is
                      // a lightweight, secondary preview popup rather than
                      // the main reading surface.
                      style: quranTextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
            loading: () => const TahfeezLoadingView(),
            error: (_, _) => TahfeezErrorView(
              message: AppLocalizations.of(context).verseLoadError,
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).pop();
              goToQuranLocation(
                context,
                QuranLocation.ayah(verse.chapterNo, verse.verseNo),
              );
            },
            child: Text(AppLocalizations.of(context).goToVerse),
          ),
        ],
      ),
    );
  }
}
