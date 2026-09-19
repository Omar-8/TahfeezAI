import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../../core/theme/quran_text_style.dart';
import '../../core/ui/coming_soon.dart';
import '../../quran/domain/models/quran_refs.dart';
import '../application/active_wbw_pack.dart';
import '../application/wbw_preferences_controller.dart';
import '../application/wbw_word_lookup.dart';
import 'wbw_packs_sheet.dart';

/// Tahfeez's own word detail sheet — the "tap a word" destination this
/// milestone's reader-interaction requirement describes, shared by both
/// reading modes (verse-by-verse `VerseBlock` and Mushaf's
/// `MushafReaderScreen`) via the single [WordRef] identifier both already
/// resolve a tap to. Always shows the Arabic word and its location; shows
/// translation/transliteration only once a WBW pack is installed and
/// selected (`activeWbwPackProvider`), with an honest hint and shortcut to
/// [showWbwPacksSheet] otherwise — the same "real, tappable, honest
/// coming-soon" shape `VerseBlock`'s Play/Bookmark/Tafsir actions use for
/// features later milestones provide.
void showWordDetailSheet(
  BuildContext context, {
  required WordRef wordRef,
  required String arabicText,
}) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Word details',
    builder: (context) =>
        _WordDetailSheetBody(wordRef: wordRef, arabicText: arabicText),
  );
}

class _WordDetailSheetBody extends ConsumerWidget {
  const _WordDetailSheetBody({required this.wordRef, required this.arabicText});

  final WordRef wordRef;
  final String arabicText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chapterNo = wordRef.ayahId ~/ 1000;
    final verseNo = wordRef.ayahId % 1000;
    final activePack = ref.watch(activeWbwPackProvider);
    final wordAudioEnabled = ref.watch(
      wbwWordAudioEnabledPreferenceControllerProvider,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.md,
        vertical: TahfeezSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          Text(
            'Ayah $chapterNo:$verseNo · Word ${wordRef.wordIndex + 1}',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              arabicText,
              textAlign: TextAlign.right,
              style: quranTextStyle(context),
            ),
          ),
          activePack.when(
            data: (pack) => pack == null
                ? _noActivePackHint(context)
                : _WbwWordContent(packId: pack.id, wordRef: wordRef),
            loading: () => const TahfeezLoadingView(),
            error: (_, _) => _noActivePackHint(context),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.volume_up_outlined),
                tooltip: 'Play word audio',
                onPressed: wordAudioEnabled
                    ? () => showComingSoon(context)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noActivePackHint(BuildContext context) {
    return TahfeezEmptyView(
      icon: Icons.translate_outlined,
      message: 'Install a word-by-word language pack to see translations here.',
      action: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          showWbwPacksSheet(context);
        },
        child: const Text('Browse language packs'),
      ),
    );
  }
}

class _WbwWordContent extends ConsumerWidget {
  const _WbwWordContent({required this.packId, required this.wordRef});

  final String packId;
  final WordRef wordRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final showTranslation = ref.watch(
      wbwShowTranslationPreferenceControllerProvider,
    );
    final showTransliteration = ref.watch(
      wbwShowTransliterationPreferenceControllerProvider,
    );
    final wordAsync = ref.watch(
      wbwWordLookupProvider(
        packId: packId,
        ayahId: wordRef.ayahId,
        wordIndex: wordRef.wordIndex,
      ),
    );

    return wordAsync.when(
      data: (word) {
        if (word == null ||
            ((!showTranslation || word.translation == null) &&
                (!showTransliteration || word.transliteration == null))) {
          return Text(
            'No word-by-word data for this word yet.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.xs,
          children: [
            if (showTransliteration && word.transliteration != null)
              Text(
                word.transliteration!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (showTranslation && word.translation != null)
              Text(
                word.translation!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
          ],
        );
      },
      loading: () => const TahfeezLoadingView(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
