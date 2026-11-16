import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/tajweed_colours.dart';
import '../../../quran/application/ayah_reading_extras.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../../bookmarks/application/bookmarks_controller.dart';
import '../../listen/application/listen_options.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../listen/presentation/listen_sheet.dart';
import '../application/mushaf_page_translations.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';
import 'ayah_share_sheet.dart';
import 'ayah_view_options.dart';
import 'ayah_view_parts.dart';
import 'similar_ayahs_section.dart';
import '../../quran/presentation/ayah_topics_section.dart';
import '../../../quran/application/meaning_packs.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../application/mushaf_pages_on_screen.dart';
import '../../../quran/domain/quran_ayah_numbers.dart' show surahAyahCounts;

/// The "long-press a word" destination, in the Mushaf and in Ayah mode:
/// the word's whole ayah, shown as Ayah mode shows it — its words (with
/// their meanings), transliteration, translations and tafsir, in its
/// Quran font and text size — with the same view settings, shared with
/// Ayah mode (the tune button). The ayah stays highlighted on the page
/// while this is open (`QuranEngineMushafPageContent.onWordLongPress`).
///
/// The Arabic is the ayah's canonical words ([ayahCanonicalWordsProvider]),
/// never the page's own glyph data.
Future<void> showAyahDetailSheet(BuildContext context, {required int ayahId}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).ayahDetails,
      builder: (context) => _AyahDetailSheet(first: ayahId),
    );

/// The ayah after [ayahId] (the next surah's first after a surah's last),
/// `null` after the Quran's last.
int? nextAyahId(int ayahId) {
  final surah = ayahId ~/ 1000, verse = ayahId % 1000;
  if (verse < surahAyahCounts[surah - 1]) return ayahId + 1;
  return surah < 114 ? (surah + 1) * 1000 + 1 : null;
}

/// The ayah before [ayahId] (the previous surah's last before a surah's
/// first), `null` before the Quran's first.
int? previousAyahId(int ayahId) {
  final surah = ayahId ~/ 1000, verse = ayahId % 1000;
  if (verse > 1) return ayahId - 1;
  return surah > 1 ? (surah - 1) * 1000 + surahAyahCounts[surah - 2] : null;
}

/// The sheet, from [first] to the ayahs around it (owner, 2026-11-16, as
/// the word sheet goes through mistakes): swiped as the Mushaf's pages
/// turn — to the right the next ayah, to the left the previous — or by
/// the buttons at its foot; the Mushaf behind turned to each one's page.
class _AyahDetailSheet extends ConsumerStatefulWidget {
  const _AyahDetailSheet({required this.first});

  final int first;

  @override
  ConsumerState<_AyahDetailSheet> createState() => _AyahDetailSheetState();
}

class _AyahDetailSheetState extends ConsumerState<_AyahDetailSheet> {
  late int _ayah = widget.first;

  /// The last move was on to the next ayah (it slides in from the left).
  var _forward = true;

  Future<void> _go(int ayahId, {required bool forward}) async {
    setState(() {
      _ayah = ayahId;
      _forward = forward;
    });
    // In the Mushaf: its page turned to, when not on screen.
    await showMushafPageOf(ref.read, (ayahId: ayahId, wordIndex: 0));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = nextAyahId(_ayah), previous = previousAyahId(_ayah);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: GestureDetector(
            key: const ValueKey('ayah-sheet-swipe'),
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 200) return;
              final to = v > 0 ? next : previous;
              if (to != null) _go(to, forward: v > 0);
            },
            child: AnimatedSwitcher(
              duration: TahfeezMotionDuration.medium,
              transitionBuilder: (child, animation) {
                final incoming = child.key == ValueKey(_ayah);
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
              // Sized by the ayah coming in (see the word sheet's).
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final p in previous) Positioned.fill(child: p),
                  ?current,
                ],
              ),
              child: _AyahDetailSheetBody(key: ValueKey(_ayah), ayahId: _ayah),
            ),
          ),
        ),
        // At the foot, in reach: the next ayah to the left (its arrow
        // pointing there, as the Mushaf reads), the previous to the right
        // — in every language.
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
                    key: const ValueKey('ayah-sheet-next'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(
                      l10n.ayahNext,
                      textDirection: Directionality.of(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: next == null
                        ? null
                        : () => _go(next, forward: true),
                  ),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('ayah-sheet-previous'),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: Text(
                      l10n.ayahPrevious,
                      textDirection: Directionality.of(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: previous == null
                        ? null
                        : () => _go(previous, forward: false),
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

class _AyahDetailSheetBody extends ConsumerWidget {
  const _AyahDetailSheetBody({super.key, required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = ref.watch(ayahViewPreferencesProvider);
    final chapterNo = ayahId ~/ 1000;
    final verseNo = ayahId % 1000;
    final surahName = [
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        if (s.surah.surahNo == chapterNo) s.localizedName ?? s.arabicName,
    ].firstOrNull;
    final words = ref.watch(ayahCanonicalWordsProvider(ayahId)).value;
    final tajweed = view.showTajweed
        ? ref.watch(tajweedIndexProvider).value
        : null;
    final meanings = view.showWordMeanings
        ? ref.watch(ayahWordMeaningsProvider(ayahId)).value ?? const {}
        : const <int, String>{};
    final books = ref.watch(activeTranslationBooksProvider).value;
    final tafsirId = ref.watch(shownTafsirIdProvider);
    // The sheet's own colours (it sits on the app's surface, not the page).
    final colors = MushafAppearanceColors(
      background: scheme.surface,
      text: scheme.onSurface,
      secondaryText: scheme.onSurfaceVariant,
      headerInk: scheme.onSurface,
    );
    // Ayah mode's text size, over the app's own.
    final media = MediaQuery.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        TahfeezSpacing.sm,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  surahName == null
                      ? '$chapterNo:$verseNo'
                      : l10n.homeDailyAyahReferenceNamed(surahName, verseNo),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('ayah-sheet-view-options'),
                icon: const Icon(Icons.tune_rounded),
                tooltip: l10n.ayahView,
                onPressed: () => showTahfeezModalBottomSheet<void>(
                  context: context,
                  title: l10n.ayahView,
                  builder: (context) => const SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: AyahViewOptions(showLayout: false),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('ayah-sheet-share'),
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.shareAyahTitle,
                onPressed: () => showAyahShareSheet(context, ayahId: ayahId),
              ),
              _BookmarkButtons(ayahId: ayahId),
            ],
          ),
          _ListenButtons(ayahId: ayahId),
          MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(1) *
                    ref.watch(tafsirTextScaleControllerProvider),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.md,
              children: [
                if (words != null)
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      key: const ValueKey('ayah-sheet-words'),
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 10,
                      children: [
                        for (final w in words)
                          AyahWordView(
                            key: ValueKey(
                              'ayah-sheet-word-$ayahId:${w.wordIndex}',
                            ),
                            text: w.text,
                            tajweed:
                                tajweed?.spansIn(ayahId, w.wordIndex, [
                                  w.text,
                                ]) ??
                                const [],
                            meaning: meanings[w.wordIndex],
                            hidden: false,
                            style: null,
                            colors: colors,
                            fontFamily: view.quranFont.family,
                            // Its meaning, transliteration and audio.
                            onTap: () => showWordDetailSheet(
                              context,
                              wordRef: (ayahId: ayahId, wordIndex: w.wordIndex),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (view.showSimilar) SimilarAyahsSection(ayahId: ayahId),
                if (view.showTopics) AyahTopicsSection(ayahId: ayahId),
                if (view.showTransliteration)
                  AyahTransliteration(ayahId: ayahId, colors: colors),
                if (view.showTranslation)
                  if (books != null && books.isEmpty)
                    _ChooseInSettings(l10n.ayahSheetNoTranslation)
                  else
                    AyahTranslations(ayahId: ayahId, colors: colors),
                if (view.showTafsir)
                  if (tafsirId == null)
                    _ChooseInSettings(l10n.ayahSheetNoTafsir)
                  else
                    AyahTafsir(
                      key: const ValueKey('ayah-sheet-tafsir-text'),
                      verse: (chapterNo: chapterNo, verseNo: verseNo),
                      colors: colors,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing chosen yet: where to choose it.
class _ChooseInSettings extends StatelessWidget {
  const _ChooseInSettings(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Plays this ayah, or from it to the end of its surah, by the chosen
/// reciter (streamed; offline says so).
class _ListenButtons extends ConsumerWidget {
  const _ListenButtons({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final player = ref.read(quranAudioPlayerProvider.notifier);
    Future<void> play(Future<bool> Function() start) async {
      final messenger = ScaffoldMessenger.of(context);
      if (!await start()) showListenOffline(messenger, l10n.listenOffline);
    }

    return Row(
      spacing: TahfeezSpacing.sm,
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            key: const ValueKey('ayah-sheet-play'),
            // Highlighted on the page while it plays (the sheet closed or
            // not).
            onPressed: () => play(
              () => player.playAyahs([
                ayahId,
              ], options: const ListenOptions(followPages: false)),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.listenPlayAyah),
          ),
        ),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('ayah-sheet-play-from'),
            // The Listen menu, from this ayah.
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              showListenSheet(
                navigator.context,
                from: (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000),
              );
            },
            icon: const Icon(Icons.playlist_play_rounded),
            label: Text(l10n.listenPlayFrom),
          ),
        ),
      ],
    );
  }
}

/// Bookmarks the ayah (again to remove it). Surahs are bookmarked from the
/// surah list.
class _BookmarkButtons extends ConsumerWidget {
  const _BookmarkButtons({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.watch(bookmarksProvider);
    final bookmarks = ref.read(bookmarksProvider.notifier);
    final saved = bookmarks.hasAyah(ayahId);
    return IconButton(
      key: const ValueKey('ayah-sheet-bookmark'),
      isSelected: saved,
      icon: const Icon(Icons.bookmark_border_rounded),
      selectedIcon: Icon(
        Icons.bookmark_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: saved ? l10n.bookmarkRemove : l10n.bookmarkAyah,
      onPressed: () => bookmarks.toggleAyah(ayahId),
    );
  }
}
