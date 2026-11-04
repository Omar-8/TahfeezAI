import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/domain/quran_ayah_numbers.dart';
import '../../listen/application/follow_along_controller.dart';
import '../../listen/application/listen_options.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../listen/presentation/follow_along_sheet.dart';
import '../../listen/presentation/listen_sheet.dart'
    show offerListenTranslationTip, showListenSheet;
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/reading_surah.dart';
import '../application/hifz_controller.dart';
import '../application/loop_options.dart';
import '../application/mushaf_recitation_target.dart';
import '../application/quran_match_controller.dart'
    show quranWordCorpusProvider;
import '../application/recitation_session_controller.dart';
import 'recitation_controls.dart' show showRecitationIntro;
import 'recitation_loop_sheet.dart' show showRecitationLoopSheet;

// The bar's Loop, Listen and Follow along started at a tap, as Recite is:
// with their settings as last used (their defaults the first time), from
// where the reader is. Their menus (the bar's ⋮, a long press) change the
// settings first.

/// When a running mode was last started again with new settings: its
/// results are not shown for the run cut short (see [restartedJustNow]).
DateTime? _restartedAt;

/// A running mode about to be started again from its menu.
void markModeRestart() => _restartedAt = DateTime.now();

/// Within a moment of [markModeRestart]: the results then arriving are the
/// cut-short run's, not shown.
bool get restartedJustNow {
  final at = _restartedAt;
  return at != null &&
      DateTime.now().difference(at) < const Duration(seconds: 4);
}

/// Where a quick start begins: with the ayahs hidden, the ayah of the next
/// word to uncover on screen; otherwise (or all uncovered) the first ayah
/// on screen. `null` before the page is known.
VerseRef? quickStartFrom(WidgetRef ref) {
  final location = ref.read(mushafRecitationTargetProvider)?.location;
  if (location is! QuranLocationPage) return null;
  final spread = ref.read(fullBleedContentProvider);
  final first = firstVisiblePage(location.pageNumber, spread: spread);
  final spans = ref.read(mushafPageVersesProvider);
  final hide = ref.read(mushafHideModeProvider);
  if (hide.enabled) {
    final corpus = ref.read(quranWordCorpusProvider).value;
    final ranges = ref.read(mushafPageWordRangesProvider);
    for (final page in [first, if (spread) first + 1]) {
      if (hide.fullyRevealed(page)) continue;
      final range = ranges[page];
      final start = range == null ? null : corpus?.positionOf(range.first);
      if (corpus == null || start == null) return spans[page]?.first;
      final at = start + hide.revealedOn(page);
      if (at >= corpus.length) break;
      final ayahId = corpus.words[at].ref.ayahId;
      return (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000);
    }
  }
  // The surah being read (opened, or scrolled into) when it begins on
  // screen: from its first ayah (Ya-Sin, on a page opening with Faatir's
  // end), not the page's.
  final reading = ref.read(readingSurahProvider);
  for (final page in [first, if (spread) first + 1]) {
    final span = spans[page];
    if (reading == null || reading.page != page || span == null) continue;
    if (reading.surah > span.first.chapterNo &&
        reading.surah <= span.last.chapterNo) {
      return (chapterNo: reading.surah, verseNo: 1);
    }
  }
  return spans[first]?.first;
}

/// The last ayah on screen (the spread's second page's, in a spread).
VerseRef? lastAyahOnScreen(WidgetRef ref) {
  final location = ref.read(mushafRecitationTargetProvider)?.location;
  if (location is! QuranLocationPage) return null;
  final spread = ref.read(fullBleedContentProvider);
  final first = firstVisiblePage(location.pageNumber, spread: spread);
  final spans = ref.read(mushafPageVersesProvider);
  return (spread ? spans[first + 1] : null)?.last ?? spans[first]?.last;
}

int _id(VerseRef v) => v.chapterNo * 1000 + v.verseNo;

/// From where the reader is to the end of what is on screen.
({VerseRef from, VerseRef to})? _onScreen(WidgetRef ref) {
  final from = quickStartFrom(ref), to = lastAyahOnScreen(ref);
  if (from == null || to == null) return null;
  return (from: from, to: _id(to) < _id(from) ? from : to);
}

/// Loop, at a tap: its last settings, from where the reader is to the end
/// of what is on screen.
Future<void> quickLoop(BuildContext context, WidgetRef ref) async {
  final location = ref.read(mushafRecitationTargetProvider)?.location;
  if (location == null) return;
  final range = _onScreen(ref);
  // The page's ayahs not known yet: its menu instead.
  if (range == null) return showRecitationLoopSheet(context);
  if (!await showRecitationIntro(context, RecitationIntroMode.loop) ||
      !context.mounted) {
    return;
  }
  ref
      .read(hifzControllerProvider.notifier)
      .setLoop(
        range,
        ref
            .read(loopOptionsProvider)
            .copyWith(strict: ref.read(hifzSettingsProvider).strict),
      );
  await ref
      .read(recitationSessionControllerProvider.notifier)
      .start(startLocation: location);
}

/// Listen, at a tap: its last settings and reciter, from where the reader
/// is to the end of its surah (the pages following).
Future<void> quickListen(BuildContext context, WidgetRef ref) async {
  final from = quickStartFrom(ref);
  if (from == null) return showListenSheet(context);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await offerListenTranslationTip(context, ref);
  if (!context.mounted) return;
  final played = await ref
      .read(quranAudioPlayerProvider.notifier)
      .playRange(
        _id(from),
        from.chapterNo * 1000 + surahAyahCounts[from.chapterNo - 1],
        options: ref.read(listenOptionsProvider),
      );
  if (!played) showListenOffline(messenger, l10n.listenOffline);
}

/// Follow along, at a tap: its last settings and reciter, from where the
/// reader is to the end of what is on screen.
Future<void> quickFollow(BuildContext context, WidgetRef ref) async {
  final range = _onScreen(ref);
  if (range == null) return showFollowAlongSheet(context);
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!await showRecitationIntro(context, RecitationIntroMode.follow) ||
      !context.mounted) {
    return;
  }
  final started = await ref
      .read(followAlongControllerProvider.notifier)
      .start(
        range.from,
        range.to,
        ref
            .read(followAlongOptionsProvider)
            .copyWith(strict: ref.read(hifzSettingsProvider).strict),
      );
  if (!started) showListenOffline(messenger, l10n.listenOffline);
}
