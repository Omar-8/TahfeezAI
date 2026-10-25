import 'package:flutter/material.dart';

import '../../../quran/presentation/surah_name_calligraphy.dart';
import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/quran_chapter_localization.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../application/mushaf_page_providers.dart';
import '../application/reading_surah.dart';

/// A Mushaf app bar's title: the current page's Surah name, page number,
/// and Juz number — live, computed from whatever page is actually on
/// screen (never the location the reader was originally opened with, which
/// can differ once the user has paged around).
class MushafPageTitle extends ConsumerWidget {
  const MushafPageTitle({
    super.key,
    required this.mushafId,
    required this.pageNumber,
    this.surahNoOverride,
  });

  final int mushafId;
  final int pageNumber;

  /// Verse-by-verse mode's own escape hatch: that mode's natural position
  /// granularity is a single ayah, finer than a Mushaf page, so [pageNumber]
  /// (used for the "Page N · Juz M" line) and the *Surah name* shown above
  /// it can legitimately disagree — a page whose first word belongs to
  /// Surah N-1 but whose resolved ayah has already scrolled into Surah N
  /// would otherwise show "Surah N-1" right above a body already showing
  /// Surah N's own [ChapterInfoCard], a confusing mismatch a reader has no
  /// reason to expect. When set (verse-by-verse
  /// mode always sets it, from the actual on-screen ayah), it names the
  /// Surah shown here directly instead of [_firstSurahNo]'s page-opening
  /// heuristic, which stays exactly right for Mushaf mode's own page-at-a
  /// -time granularity (where a page always *starts* with the Surah it
  /// should be titled by, by definition) and so leaves this parameter unset.
  final int? surahNoOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref
        .watch(mushafPageDataProvider(mushafId, pageNumber))
        .value;
    // The AppBar applies its own `foregroundColor` (`MushafAppearanceColors
    // .text` here — never `Theme.of(context)`, per this page's "app theme
    // never leaks into Mushaf content" rule) to this title slot's
    // `DefaultTextStyle`, so reading it back is how this widget matches
    // that color without needing its own separate color prop.
    final baseColor = DefaultTextStyle.of(context).style.color;

    if (bundle == null) {
      return Text(
        AppLocalizations.of(context).homeContinueReadingPage(pageNumber),
        overflow: TextOverflow.ellipsis,
      );
    }

    // The surah being read, while on its page (opened at, or scrolled into
    // in Ayah mode); else the one the page starts with.
    final reading = ref.watch(readingSurahProvider);
    final surahNo =
        surahNoOverride ??
        (reading != null && reading.page == pageNumber
            ? reading.surah
            : _firstSurahNo(bundle));
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final localizedName = surahNo == null
        ? null
        : ref
              .watch(
                chapterLocalizationProvider(
                  surahNo,
                  languageCode: languageCode,
                ),
              )
              .value
              ?.name;

    final name =
        localizedName ??
        (surahNo != null
            ? AppLocalizations.of(context).homeContinueReadingSurah(surahNo)
            : AppLocalizations.of(context).readerMushaf);
    final arabic = languageCode == 'ar';

    final subtitleParts = <String>[
      AppLocalizations.of(context).homeContinueReadingPage(pageNumber),
      if (bundle.juzNo != null)
        AppLocalizations.of(context).homeContinueReadingJuz(bundle.juzNo!),
    ];

    // Two lines (Surah name, then page/Juz), not one long joined string:
    // a single line competing with the mode switch and Appearance icon for
    // width truncated well before showing all three pieces of context.
    // Stacking vertically uses the app bar's normally-unused vertical
    // slack instead of fighting for horizontal room.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The name, and beside it the Mushaf's calligraphy of it — in
        // Arabic the calligraphy alone (the plain name its label).
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            if (!(arabic && surahNo != null))
              Flexible(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: baseColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            // Shrinking too where the bar is short of room.
            if (surahNo != null)
              Flexible(
                child: SurahNameCalligraphy(
                  surahNo: surahNo,
                  height: arabic ? 24 : 20,
                  maxWidth: 80,
                  color: baseColor,
                  semanticLabel: arabic ? name : null,
                ),
              ),
          ],
        ),
        Text(
          subtitleParts.join(' · '),
          style: TextStyle(
            fontSize: 12,
            color: baseColor?.withValues(alpha: 0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// The chapter a page opens on — its first real Quran word's ayah,
  /// walked in page order (never a marker/ornament token, which carries no
  /// canonical ayah of its own). A page spanning a Surah transition is
  /// titled by whichever Surah it *starts* with, matching how a reader
  /// picks up a physical Mushaf page.
  int? _firstSurahNo(MushafPageBundle bundle) {
    final lines = [...bundle.lines]
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    for (final line in lines) {
      final tokens = bundle.tokensByLineNumber[line.lineNumber] ?? const [];
      for (final token in tokens) {
        if (token.tokenType == MushafTokenType.quranWord &&
            token.canonicalAyahId != null) {
          return token.canonicalAyahId! ~/ 1000;
        }
      }
    }
    return null;
  }
}
