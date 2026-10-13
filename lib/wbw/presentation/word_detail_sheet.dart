import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../../core/theme/quran_text_style.dart';
import '../../features/listen/application/quran_audio_player.dart';
import '../../features/mushaf/application/mushaf_appearance_controller.dart';
import '../../features/mushaf/domain/mushaf_appearance.dart';
import '../../features/recitation/presentation/recitation_word_feedback.dart';
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
    title: AppLocalizations.of(context).wordDetails,
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

    // Scrolls when taller than the room it has (small screen, large text).
    return SingleChildScrollView(
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
            AppLocalizations.of(context)
                .wordRef('$chapterNo:$verseNo', wordRef.wordIndex + 1),
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
          // What the last recitation found wrong in this word, if anything.
          RecitationWordFeedback(
            wordRef: wordRef,
            wordText: arabicTextAsync.value,
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
                tooltip: AppLocalizations.of(context).wordPlayAudio,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final offline = AppLocalizations.of(context).listenOffline;
                  final played = await ref
                      .read(quranAudioPlayerProvider.notifier)
                      .playWord(wordRef.ayahId, wordRef.wordIndex);
                  if (!played) showListenOffline(messenger, offline);
                },
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
      message: AppLocalizations.of(context).wordInstall,
      action: TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          showWbwPacksSheet(context);
        },
        child: Text(AppLocalizations.of(context).wordBrowsePacks),
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
            AppLocalizations.of(context).wordNoData,
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
