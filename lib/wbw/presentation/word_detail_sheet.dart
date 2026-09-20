import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../../core/theme/quran_text_style.dart';
import '../../core/ui/coming_soon.dart';
import '../../features/mushaf/application/mushaf_appearance_controller.dart';
import '../../features/mushaf/domain/mushaf_appearance.dart';
import '../../quran/application/canonical_ayah_word_text.dart';
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
///
/// Deliberately resolves its own displayed Arabic text from
/// [canonicalAyahWordTextProvider] rather than accepting a caller-supplied
/// string: a caller in the Mushaf renderer only ever has that word's
/// [MushafToken.displayText] in hand, which is QCF page-specific-glyph text
/// (private-use-area codepoints meaningful only with that exact page's own
/// font) — rendering it here with this sheet's generic Arabic-capable font
/// would silently show a different, wrong-looking word. See
/// `canonical_ayah_word_text.dart`'s doc comment.
void showWordDetailSheet(BuildContext context, {required WordRef wordRef}) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Word details',
    builder: (context) => _WordDetailSheetBody(wordRef: wordRef),
  );
}

class _WordDetailSheetBody extends ConsumerWidget {
  const _WordDetailSheetBody({required this.wordRef});

  final WordRef wordRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chapterNo = wordRef.ayahId ~/ 1000;
    final verseNo = wordRef.ayahId % 1000;
    final activePack = ref.watch(activeWbwPackProvider);
    final wordAudioEnabled = ref.watch(
      wbwWordAudioEnabledPreferenceControllerProvider,
    );
    final arabicTextAsync = ref.watch(
      canonicalAyahWordTextProvider(
        ayahId: wordRef.ayahId,
        wordIndex: wordRef.wordIndex,
      ),
    );
    final quranTextColor = ref
        .watch(mushafAppearanceControllerProvider)
        .colors
        .text;

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
              arabicTextAsync.value ?? '',
              textAlign: TextAlign.right,
              // No custom `fontFamily` -- see `VerseBlock`'s doc comment.
              style: quranTextStyle(color: quranTextColor),
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
