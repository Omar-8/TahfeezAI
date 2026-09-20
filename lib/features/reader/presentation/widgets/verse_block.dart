import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/tafsir_routing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../core/ui/coming_soon.dart';
import '../../../../quran/domain/models/ayah_models.dart';
import '../../../../quran/domain/models/translation_models.dart';
import '../../../../quran/presentation/translation_block.dart';
import '../../../../wbw/presentation/word_detail_sheet.dart';
import '../../../mushaf/application/mushaf_appearance_controller.dart';
import '../../../mushaf/application/quranapp_special_font_providers.dart';
import '../../../mushaf/domain/mushaf_appearance.dart';
import '../../application/quran_display_providers.dart';
import 'verse_share_sheet.dart';

/// One verse — `docs/reference/04_READER_SPEC.md` §5's `VerseView`,
/// independently designed: an ayah-reference badge (tap to copy), the
/// per-verse action row, the Arabic text itself (when
/// [ArabicTextVisiblePreferenceController] allows), and, per Milestone 9,
/// one stacked [TranslationBlock] per active translation
/// (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §2).
///
/// Content comes only from [ayah] (an [AyahWithWords], loaded by
/// `ReaderSessionController` through the batched repository call) and
/// [translations]/[translationBooks] (batch-loaded the same way) — never a
/// literal string in this widget, per "do not hard-code Quran text into
/// widgets".
///
/// Play/Bookmark are wired, real widgets whose action is an honest "coming
/// soon" today (no verse-audio source, no `UserDataRepository`
/// implementation). Copy, Share, and Tafsir are genuinely functional.
class VerseBlock extends ConsumerWidget {
  const VerseBlock({
    super.key,
    required this.ayah,
    required this.arabicVisible,
    required this.isSelected,
    required this.hasActiveSelection,
    required this.onToggleSelection,
    this.translations = const {},
    this.translationBooks = const {},
  });

  final AyahWithWords ayah;
  final bool arabicVisible;
  final bool isSelected;
  final bool hasActiveSelection;
  final VoidCallback onToggleSelection;

  /// This verse's active translations, keyed by slug — a slice of
  /// `ReaderSessionState.translationsByAyahId` for [ayah]'s id.
  final Map<String, TranslationVerseText> translations;
  final Map<String, TranslationBook> translationBooks;

  String get _reference => '${ayah.ayah.chapterNo}:${ayah.ayah.verseNo}';

  String get _arabicText => ayah.words.map((w) => w.text).join(' ');

  void _copyReference(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _reference));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $_reference')));
  }

  void _openTafsir(BuildContext context) {
    openTafsirReader(
      context,
      chapterNo: ayah.ayah.chapterNo,
      verseNo: ayah.ayah.verseNo,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final quranTextColor = ref
        .watch(mushafAppearanceControllerProvider)
        .colors
        .text;
    final quranFontFamily = ref
        .watch(uthmanicHafsFontManifestProvider)
        .value
        ?.fontFamily;
    final displayWords = ref
        .watch(quranDisplayRepositoryProvider)
        .displayWordsForAyah(ayah.ayah.id);
    // Both the font and a validated, correctly-paired QPC Hafs word list
    // (same length as the canonical word list, so index `i` in each refers
    // to the same word) must be available, or this ayah falls back to
    // plain canonical text through the system font — never QPC Hafs text
    // through a missing font, and never canonical text forced through the
    // QPC Hafs font (the exact mismatch that produced the confirmed U+06DF
    // rendering defect; see `docs/QURAN_DATA_PROVENANCE.md` §16/§17).
    final useQpcHafs =
        quranFontFamily != null &&
        displayWords != null &&
        displayWords.length == ayah.words.length;

    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: hasActiveSelection ? onToggleSelection : null,
        onLongPress: onToggleSelection,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.sm,
            children: [
              if (arabicVisible)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Wrap(
                    textDirection: TextDirection.rtl,
                    // `WrapAlignment.start` -- not `.end` -- hugs the right
                    // margin: under `TextDirection.rtl`, `start` means "as
                    // close to the beginning of reading order as possible",
                    // which for Arabic is the right edge. `.end` was
                    // pushing verse text to the LEFT instead, backwards for
                    // Arabic script.
                    alignment: WrapAlignment.start,
                    spacing: TahfeezSpacing.sm,
                    runSpacing: TahfeezSpacing.xs,
                    children: [
                      for (var i = 0; i < ayah.words.length; i++)
                        InkWell(
                          // Always the canonical word identity -- word tap,
                          // word-by-word translation, and future audio
                          // highlighting must never key off QPC Hafs's own
                          // word numbering, which counts the trailing
                          // ayah-end marker as an extra "word" that
                          // canonical `AyahWord` doesn't have.
                          onTap: () => showWordDetailSheet(
                            context,
                            wordRef: (
                              ayahId: ayah.words[i].ayahId,
                              wordIndex: ayah.words[i].wordIndex,
                            ),
                          ),
                          child: Text(
                            // QPC Hafs display text when a validated entry
                            // and its font are both available; otherwise
                            // the pre-existing canonical-text/system-font
                            // rendering -- never QPC Hafs text through a
                            // missing font, and never canonical text forced
                            // through the QPC Hafs font (the exact mismatch
                            // that produced the confirmed U+06DF rendering
                            // defect; see `useQpcHafs`'s own doc comment).
                            useQpcHafs ? displayWords[i] : ayah.words[i].text,
                            style: quranTextStyle(
                              color: quranTextColor,
                              fontFamily: useQpcHafs ? quranFontFamily : null,
                              fontSize: quranVerseFontSize,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (final entry in translations.entries)
                TranslationBlock(
                  verseText: entry.value,
                  authorName: translationBooks[entry.key]?.author ?? entry.key,
                ),
              TahfeezVerseActionBar(
                trailing: InkWell(
                  onTap: () => _copyReference(context),
                  borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TahfeezSpacing.sm,
                      vertical: TahfeezSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                    ),
                    child: Text(
                      _reference,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
                actions: [
                  TahfeezVerseAction(
                    icon: Icons.play_circle_outline,
                    tooltip: 'Play',
                    onPressed: () => showComingSoon(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.bookmark_border,
                    tooltip: 'Bookmark',
                    onPressed: () => showComingSoon(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.menu_book_outlined,
                    tooltip: 'Tafsir',
                    onPressed: () => _openTafsir(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.ios_share_outlined,
                    tooltip: 'Share',
                    onPressed: () => showVerseShareSheet(
                      context,
                      '$_reference\n\n$_arabicText',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
