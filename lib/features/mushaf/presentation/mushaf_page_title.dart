import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/theme/components/tahfeez_bottom_sheet.dart'
    show isWideWebWindow;
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../core/ui/motion.dart';
import '../../../quran/application/quran_chapter_localization.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../application/mushaf_hide_mode.dart' show firstVisiblePage;
import '../application/mushaf_page_providers.dart';
import '../application/reading_surah.dart';
import 'reader_jump_sheet.dart';

/// A Mushaf app bar's title: the current page's Surah name, page number,
/// and Juz number — live, computed from whatever page is actually on
/// screen (never the location the reader was originally opened with, which
/// can differ once the user has paged around).
class MushafPageTitle extends ConsumerStatefulWidget {
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
  ConsumerState<MushafPageTitle> createState() => _MushafPageTitleState();
}

class _MushafPageTitleState extends ConsumerState<MushafPageTitle> {
  /// What was last shown, kept while a turned-to page's data or its
  /// surah's name is still loading — so the title does not flash a
  /// different layout ("Page N" alone, "Surah N") for a frame or two.
  String? _lastName;
  int? _lastJuz;
  int? _lastSurah;

  int get mushafId => widget.mushafId;
  int get pageNumber => widget.pageNumber;

  @override
  Widget build(BuildContext context) {
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
      final name = _lastName;
      // Nothing known yet: no title until the surah's name is (not "Page
      // N", then "Surah N", then the name, a frame or two apart).
      if (name == null) return _shown(null);
      return _shown(
        _title(
          context,
          name,
          [
            _pages(context),
            if (_lastJuz != null)
              AppLocalizations.of(context).homeContinueReadingJuz(_lastJuz!),
          ],
          baseColor,
          _lastSurah,
        ),
      );
    }

    // The surah being read, while on its page (opened at, or scrolled into
    // in Ayah mode); else the one the page starts with.
    final reading = ref.watch(readingSurahProvider);
    final surahNo =
        widget.surahNoOverride ??
        (reading != null && reading.page == pageNumber
            ? reading.surah
            : _firstSurahNo(bundle));
    final languageCode =
        ref.watch(localeControllerProvider)?.languageCode ?? 'en';
    final localization = surahNo == null
        ? null
        : ref.watch(
            chapterLocalizationProvider(surahNo, languageCode: languageCode),
          );
    final localizedName = localization?.value?.name;
    if (_lastName == null &&
        localization != null &&
        localization.isLoading &&
        !localization.hasValue) {
      return _shown(null);
    }

    // The surah's name still loading: the last one shown, if any.
    final name =
        localizedName ??
        _lastName ??
        (surahNo != null
            ? AppLocalizations.of(context).homeContinueReadingSurah(surahNo)
            : AppLocalizations.of(context).readerMushaf);

    if (localizedName != null) _lastName = localizedName;
    _lastJuz = bundle.juzNo;
    _lastSurah = surahNo;
    final subtitleParts = <String>[
      _pages(context),
      if (bundle.juzNo != null)
        AppLocalizations.of(context).homeContinueReadingJuz(bundle.juzNo!),
    ];

    return _shown(_title(context, name, subtitleParts, baseColor, surahNo));
  }

  /// The title fading in once, when first known (the same afterwards, as
  /// pages turn: no fade).
  Widget _shown(Widget? title) => AnimatedSwitcher(
    duration: motion(context, TahfeezMotionDuration.medium),
    switchInCurve: TahfeezMotionCurves.standard,
    layoutBuilder: (current, previous) => Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [...previous, ?current],
    ),
    child: title == null
        ? const SizedBox.shrink(key: ValueKey('mushaf-title-waiting'))
        : KeyedSubtree(key: const ValueKey('mushaf-title-shown'), child: title),
  );

  /// "Page N" — in a wide browser window's two-page spread, both pages,
  /// in the order they are laid out ("Page 598 – 597").
  String _pages(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spread =
        isWideWebWindow(context) && ref.watch(fullBleedContentProvider);
    final first = firstVisiblePage(pageNumber, spread: spread);
    final pageCount = ref.watch(mushafByIdProvider(mushafId)).value?.pageCount;
    if (!spread || (pageCount != null && first + 1 > pageCount)) {
      return l10n.homeContinueReadingPage(pageNumber);
    }
    final second = first + 1;
    return l10n.readerSpreadPages(
      Directionality.of(context) == TextDirection.rtl
          ? '$first – $second'
          : '$second – $first',
    );
  }

  // Two lines (Surah name, then page/Juz), not one long joined string:
  // a single line competing with the mode switch and Appearance icon for
  // width truncated well before showing all three pieces of context.
  // Stacking vertically uses the app bar's normally-unused vertical
  // slack instead of fighting for horizontal room.
  // Pressed: where to go — a surah and an ayah, or a page — from here.
  // (Looks the same: only a ripple shows it.)
  Widget _title(
    BuildContext context,
    String name,
    List<String> subtitleParts,
    Color? baseColor,
    int? surahNo,
  ) {
    return InkWell(
      key: const ValueKey('mushaf-title'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => showReaderJumpSheet(
        context,
        mushafId: mushafId,
        pageNumber: pageNumber,
        pageCount:
            ref.read(mushafByIdProvider(mushafId)).value?.pageCount ?? 604,
        surahNo: surahNo,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ).copyWith(color: baseColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      ),
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
