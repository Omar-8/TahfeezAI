import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/script_direction.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/theme/components/tahfeez_state_views.dart';
import '../../core/theme/quran_text_style.dart';
import '../../features/listen/application/quran_audio_player.dart';
import '../../features/mushaf/application/mushaf_appearance_controller.dart';
import '../../features/mushaf/domain/mushaf_appearance.dart';
import '../../features/mushaf/application/mushaf_page_turn.dart';
import '../../features/mushaf/application/mushaf_page_verses.dart';
import '../../features/mushaf/application/mushaf_word_overlay.dart';
import '../../features/recitation/application/mushaf_recitation_target.dart';
import '../../features/recitation/presentation/recitation_loop_sheet.dart'
    show SegmentedProgressLine;
import '../../quran/domain/models/quran_location.dart';
import '../../quran/quran_providers.dart';
import '../../features/recitation/presentation/recitation_word_feedback.dart';
import '../../quran/application/canonical_ayah_word_text.dart';
import '../../quran/domain/models/quran_refs.dart';
import '../application/active_wbw_pack.dart';
import '../application/arabic_word_gloss.dart';
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
    builder: (context) => _WordDetailSheet(first: wordRef),
  );
}

/// The sheet, on [first] — a word the last recitation marked with a
/// mistake: from it to the others (previous / next, how far along: "2 / 8",
/// a line in as many segments), each on its page.
class _WordDetailSheet extends ConsumerStatefulWidget {
  const _WordDetailSheet({required this.first});

  final WordRef first;

  @override
  ConsumerState<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends ConsumerState<_WordDetailSheet> {
  late WordRef _word = widget.first;

  /// The last move was on to a next mistake (it slides in from the left).
  var _forward = true;

  /// Shows [word] — its page turned to first when it is not on screen.
  Future<void> _go(WordRef word) async {
    setState(() => _word = word);
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return;
    final shown = ref
        .read(mushafPageWordRangesProvider)
        .values
        .any(
          (r) =>
              compareWordRefs(r.first, word) <= 0 &&
              compareWordRefs(r.last, word) >= 0,
        );
    if (shown) return;
    final turns = ref.read(mushafPageTurnRequestsProvider.notifier);
    final page = await ref
        .read(quranRepositoryProvider)
        .getPageForAyah(mushafId: location.mushafId, ayahId: word.ayahId);
    if (page != null) turns.toPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final mistakes = markedMistakes(ref.watch(mushafWordOverlayProvider));
    final at = mistakes.indexOf(_word);
    final body = _WordDetailSheetBody(key: ValueKey(_word), wordRef: _word);
    if (at < 0) return body;
    // A mistake looked at: the bar's "Mistakes found" has done its work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(mistakesSeenProvider.notifier).seen(mistakes);
    });
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Which mistake this is: its count, and the line across the sheet
        // in as many segments, filling from the right as the Mushaf reads.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.md),
          child: Semantics(
            label: l10n.wordMistakeOf(at + 1, mistakes.length),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    '${at + 1} / ${mistakes.length}',
                    key: const ValueKey('word-mistake-count'),
                    style: theme.textTheme.labelLarge,
                  ),
                  SegmentedProgressLine(
                    value: (at + 1) / mistakes.length,
                    segments: mistakes.length,
                    rtl: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Swiped as the Mushaf's pages turn (owner, 2026-11-08): to the
        // right, the next mistake (it reads right to left); to the left,
        // the previous one.
        Flexible(
          child: GestureDetector(
            key: const ValueKey('word-mistake-swipe'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              final to = v > 0 ? at + 1 : at - 1;
              if (to >= 0 && to < mistakes.length) {
                _forward = v > 0;
                _go(mistakes[to]);
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                // The new word in from the side it was swiped towards.
                final incoming = child.key == ValueKey(_word);
                final dx = (_forward ? -1.0 : 1.0) * (incoming ? 1 : -1);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(dx * 0.25, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: body,
            ),
          ),
        ),
        // At the bottom, always in reach: the next mistake to the left (its
        // arrow pointing there), the previous one to the right — in every
        // language.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              spacing: TahfeezSpacing.sm,
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('word-next-mistake'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(
                      l10n.wordNextMistake,
                      textDirection: Directionality.of(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: at + 1 < mistakes.length
                        ? () {
                            _forward = true;
                            _go(mistakes[at + 1]);
                          }
                        : null,
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('word-previous-mistake'),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(
                      l10n.wordPreviousMistake,
                      textDirection: Directionality.of(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: at > 0
                        ? () {
                            _forward = false;
                            _go(mistakes[at - 1]);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WordDetailSheetBody extends ConsumerWidget {
  const _WordDetailSheetBody({super.key, required this.wordRef});

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
    final gloss = Localizations.localeOf(context).languageCode == 'ar'
        ? ref
              .watch(
                arabicWordGlossProvider((
                  ayahId: wordRef.ayahId,
                  wordIndex: wordRef.wordIndex,
                )),
              )
              .value
        : null;
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
          // The word, and on its line, far left, its audio.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('word-play'),
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
                Expanded(
                  child: Text(
                    arabicTextAsync.value ?? '',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    // No custom `fontFamily` -- see `VerseBlock`'s doc comment.
                    style: quranTextStyle(color: quranTextColor),
                  ),
                ),
              ],
            ),
          ),
          // What the last recitation found wrong in this word, if anything.
          RecitationWordFeedback(
            wordRef: wordRef,
            wordText: arabicTextAsync.value,
          ),
          // In Arabic: the word's meaning from al-Sirāj, where it explains
          // the word; else (or in another language) the word-by-word pack.
          if (gloss != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.xs,
              children: [
                Text(
                  AppLocalizations.of(context).wordMeaningSiraj,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: scheme.primary),
                ),
                Text(
                  gloss,
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.7),
                ),
              ],
            )
          else
            activePack.when(
              data: (pack) => pack == null
                  ? _noActivePackHint(context)
                  : _WbwWordContent(packId: pack.id, wordRef: wordRef),
              loading: () => const TahfeezLoadingView(),
              error: (_, _) => _noActivePackHint(context),
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
    // Another language's pack: the English one's transliteration, and its
    // meaning where this one has none.
    final english = packId == englishWbwPackId
        ? null
        : ref
              .watch(
                wbwWordLookupProvider(
                  packId: englishWbwPackId,
                  ayahId: wordRef.ayahId,
                  wordIndex: wordRef.wordIndex,
                ),
              )
              .value;

    return wordAsync.when(
      data: (own) {
        final word = own == null
            ? english
            : own.copyWith(
                translation: own.translation ?? english?.translation,
                transliteration:
                    own.transliteration ?? english?.transliteration,
              );
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
                textDirection: meaningDirection(word.translation!),
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
