import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../quran/application/ayah_reading_extras.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../../quran/application/tafsir_verse_text.dart';
import '../../../quran/domain/models/ayah_models.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/presentation/translation_block.dart';
import '../../../quran/quran_providers.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../../listen/application/listen_options.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../recitation/application/hifz_controller.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/mushaf_focus_ayah.dart';
import '../application/mushaf_hide_mode.dart';
import '../application/mushaf_page_translations.dart';
import '../application/mushaf_page_turn.dart';
import '../application/mushaf_page_verses.dart';
import '../application/mushaf_quran_engine_providers.dart';
import '../application/mushaf_word_overlay.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';
import '../../bookmarks/application/bookmarks_controller.dart';
import '../application/mushaf_passages.dart';
import 'mushaf_ayah_sheet.dart';

/// Ayah mode's page: the Mushaf page's ayahs one after another — each
/// one's Arabic word by word, then (as [AyahViewPreferences] says) its
/// word meanings, transliteration, translations and tafsir.
///
/// It serves the bar's modes exactly as the printed page does: it reports
/// the same words (the engine page's own, in the same order) to hide mode
/// and the recitation, and shows their masks and marks by the same rules
/// (`QuranEngineMushafPageContent`) — so reciting, looping, listening,
/// Follow along and revealing work the same on either.
class AyahModePage extends ConsumerStatefulWidget {
  const AyahModePage({
    super.key,
    required this.mushafId,
    required this.pageNumber,
    required this.pageCount,
    required this.colors,
    this.isCurrentPage = false,
  });

  final int mushafId;
  final int pageNumber;
  final int pageCount;
  final MushafAppearanceColors colors;
  final bool isCurrentPage;

  @override
  ConsumerState<AyahModePage> createState() => _AyahModePageState();
}

class _AyahModePageState extends ConsumerState<AyahModePage> {
  /// The page's words in reading order (the engine's), and each ayah's
  /// end as a count of them.
  List<WordRef>? _words;
  List<int> _ayahEnds = const [];
  Object? _error;

  final _scroll = ScrollController();
  final _ayahKeys = <int, GlobalKey>{};

  /// Each page word's key (by its page index), to scroll a word into view.
  final _wordKeys = <int, GlobalKey>{};

  /// Brings the page's word [index] into view (revealing and hiding).
  void _scrollToWord(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _wordKeys[index]?.currentContext;
      if (context == null || !context.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.4,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AyahModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrentPage && !oldWidget.isCurrentPage) {
      _bringActiveIntoView();
    }
    if (oldWidget.pageNumber != widget.pageNumber) {
      setState(() => _words = null);
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final backend = await ref.read(mushafQuranEngineBackendProvider.future);
      final page = await backend.loadPage(widget.pageNumber);
      if (!mounted) {
        backend.disposePage(page);
        return;
      }
      final words = page.wordRefs;
      final ends = page.ayahWordBoundaries;
      final span = page.verseSpan;
      // Reported as the printed page reports them (hide mode, the
      // recitation's starting point, Listen's reveals).
      ref
          .read(mushafHideModeProvider.notifier)
          .reportPageWords(
            widget.pageNumber,
            wordCount: page.wordCount,
            ayahBoundaries: ends,
          );
      if (words.isNotEmpty) {
        ref.read(mushafPageWordRangesProvider.notifier).report(
          widget.pageNumber,
          (first: words.first, last: words.last),
        );
      }
      if (span != null) {
        ref
            .read(mushafPageVersesProvider.notifier)
            .report(widget.pageNumber, span);
      }
      backend.disposePage(page);
      setState(() {
        _words = words;
        _ayahEnds = ends;
      });
      _bringTargetIntoView();
      _bringActiveIntoView();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// The page's ayahs: each one's id and its words' page indices.
  List<(int, List<int>)> _ayahs() {
    final words = _words!;
    final out = <(int, List<int>)>[];
    var start = 0;
    for (final end in _ayahEnds) {
      if (end <= start || end > words.length) continue;
      out.add((words[start].ayahId, [for (var i = start; i < end; i++) i]));
      start = end;
    }
    if (start < words.length) {
      // Words after the last reported end (none expected): their own ayahs.
      var i = start;
      while (i < words.length) {
        final id = words[i].ayahId;
        final indices = <int>[];
        while (i < words.length && words[i].ayahId == id) {
          indices.add(i++);
        }
        out.add((id, indices));
      }
    }
    return out;
  }

  /// Scrolls to [ayahId]'s block, if it is on this page.
  void _scrollTo(int ayahId, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _ayahKeys[ayahId]?.currentContext;
      if (context == null || !context.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          alignment: 0.1,
          duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  /// Opened (or turned to) mid-recitation or mid-listening: straight to
  /// the ayah whose turn it is, if it is on this page.
  void _bringActiveIntoView() {
    if (!widget.isCurrentPage) return;
    final active =
        ref.read(quranAudioPlayerProvider)?.ayahId ??
        (ref.read(hifzControllerProvider).running
            ? ref.read(hifzControllerProvider).expected?.ayahId
            : null) ??
        ref.read(mushafFocusAyahProvider)?.ayahId;
    if (active != null && (_words?.any((w) => w.ayahId == active) ?? false)) {
      _scrollTo(active, animate: false);
    }
  }

  /// Within a long ayah: the word due next kept on screen, scrolling no
  /// more than needed.
  void _keepWordVisible(WordRef word) {
    final index = _words?.indexOf(word) ?? -1;
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _wordKeys[index]?.currentContext;
      if (context == null || !context.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  void _bringTargetIntoView() {
    final target = ref.read(ayahModeTargetProvider);
    final words = _words;
    if (target == null || words == null) return;
    if (!words.any((w) => w.ayahId == target)) return;
    _scrollTo(target, animate: false);
    ref.read(ayahModeTargetProvider.notifier).done();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final words = _words;
    if (_error != null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).ayahModeUnavailable,
          style: TextStyle(color: colors.secondaryText),
        ),
      );
    }
    if (words == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // The recitation's place, and the reciter's ayah, kept in view on the
    // page being read.
    // Whichever mode runs, the ayah whose turn it is kept in view on the
    // page being read: the reciter's (Listen, Follow along's reciter), the
    // reciter's next word (Recite, Loop, Follow along's user turn), or the
    // ayah in focus — whether highlighted or not.
    if (widget.isCurrentPage) {
      ref.listen(mushafFocusAyahProvider.select((f) => f?.ayahId), (_, id) {
        if (id != null) _scrollTo(id);
      });
      ref.listen(quranAudioPlayerProvider.select((n) => n?.ayahId), (
        previous,
        id,
      ) {
        if (id != null && id != previous) _scrollTo(id);
      });
      ref.listen(
        hifzControllerProvider.select((h) => h.running ? h.expected : null),
        (previous, next) {
          if (next == null) return;
          if (previous == null || previous.ayahId != next.ayahId) {
            _scrollTo(next.ayahId);
          } else {
            _keepWordVisible(next);
          }
        },
      );
    }
    ref.listen(ayahModeTargetProvider, (_, _) => _bringTargetIntoView());
    // Revealing or hiding word by word (the bar's buttons): the boundary
    // kept in view — the last word shown.
    ref.listen(
      mushafHideModeProvider.select(
        (h) => h.enabled ? h.revealedOn(widget.pageNumber) : null,
      ),
      (previous, revealed) {
        if (revealed == null || previous == null || revealed == previous) {
          return;
        }
        _scrollToWord((revealed - 1).clamp(0, words.length - 1));
      },
    );

    final overlay = ref.watch(mushafWordOverlayProvider);
    final hide = ref.watch(mushafHideModeProvider);
    final uncovered = hide.revealedOn(widget.pageNumber);
    bool hidden(int i) => overlay != null
        ? (overlay.followHideMode
              ? hide.enabled && i >= uncovered
              : overlay.isHidden(words[i]))
        : hide.enabled && i >= uncovered;
    MushafWordMark? mark(int i) => overlay?.marks[words[i]];

    final ayahs = _ayahs();
    return Container(
      color: colors.background,
      // The whole page built at once (a page holds at most a few dozen
      // ayahs): every ayah and word is there to scroll to — revealing,
      // hiding and following the recitation need them.
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          TahfeezSpacing.md,
          TahfeezSpacing.sm,
          TahfeezSpacing.md,
          TahfeezSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var k = 0; k <= ayahs.length; k++)
              _item(
                context,
                k,
                ayahs,
                hidden: hidden,
                mark: mark,
                words: words,
              ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int k,
    List<(int, List<int>)> ayahs, {
    required bool Function(int) hidden,
    required MushafWordMark? Function(int) mark,
    required List<WordRef> words,
  }) {
    final colors = widget.colors;
    if (k == ayahs.length) {
      return _PageButtons(
        pageNumber: widget.pageNumber,
        pageCount: widget.pageCount,
        colors: colors,
      );
    }
    final (ayahId, indices) = ayahs[k];
    return KeyedSubtree(
      key: _ayahKeys.putIfAbsent(ayahId, GlobalKey.new),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ayahId % 1000 == 1)
            _SurahHeader(surahNo: ayahId ~/ 1000, colors: colors),
          _AyahBlock(
            mushafId: widget.mushafId,
            pageNumber: widget.pageNumber,
            ayahId: ayahId,
            words: [for (final i in indices) words[i]],
            wordKeys: [
              for (final i in indices) _wordKeys.putIfAbsent(i, GlobalKey.new),
            ],
            hidden: [for (final i in indices) hidden(i)],
            marks: [for (final i in indices) mark(i)],
            colors: colors,
          ),
          if (k < ayahs.length - 1)
            Divider(
              height: TahfeezSpacing.xl,
              color: colors.secondaryText.withValues(alpha: 0.2),
            ),
        ],
      ),
    );
  }
}

/// A surah's start: its name, and the Bismillah (the canonical 1:1) before
/// every surah but Al-Fatiha (where it is the first ayah) and At-Tawbah.
class _SurahHeader extends ConsumerWidget {
  const _SurahHeader({required this.surahNo, required this.colors});

  final int surahNo;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surahs = ref.watch(indexedSurahsProvider).value;
    final surah = surahs?.where((s) => s.surah.surahNo == surahNo).firstOrNull;
    final name = surah?.localizedName ?? surah?.arabicName ?? '$surahNo';
    final bismillah = surahNo == 1 || surahNo == 9
        ? null
        : ref.watch(_ayahWordsProvider(1001)).value;
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey('ayah-mode-surah-$surahNo'),
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.md),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: colors.secondaryText.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Text(
              '$surahNo · $name',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: colors.text),
            ),
          ),
          if (bismillah != null && bismillah.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
              child: Text(
                [for (final w in bismillah) w.text].join(' '),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: quranTextStyle(
                  color: colors.text,
                  fontFamily: 'Scheherazade New',
                  fontSize: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An ayah's canonical words.
final _ayahWordsProvider = FutureProvider.autoDispose
    .family<List<AyahWord>, int>((ref, ayahId) {
      return ref
          .watch(quranRepositoryProvider)
          .getWordsForAyah(
            ayahId,
            scriptCode: ref.watch(quranScriptCodeProvider),
          );
    });

/// One ayah: its reference and actions, its Arabic word by word (masked
/// and marked as the recitation says), then what the view shows under it.
class _AyahBlock extends ConsumerWidget {
  const _AyahBlock({
    required this.mushafId,
    required this.pageNumber,
    required this.ayahId,
    required this.words,
    required this.wordKeys,
    required this.hidden,
    required this.marks,
    required this.colors,
  });

  final int mushafId, pageNumber, ayahId;

  /// Each word's key on the page (to scroll it into view).
  final List<GlobalKey> wordKeys;

  /// The page's words of this ayah (the engine's), and each one's mask and
  /// mark.
  final List<WordRef> words;
  final List<bool> hidden;
  final List<MushafWordMark?> marks;
  final MushafAppearanceColors colors;

  /// As the printed page draws them: a band behind the next word, recited
  /// words inked by how they went.
  static const _markStyles = {
    MushafWordMark.current: (color: Color(0x552F80ED), ink: false),
    MushafWordMark.mistake: (color: Color(0x77E53935), ink: false),
    MushafWordMark.correct: (color: Color(0xFF43A047), ink: true),
    MushafWordMark.skipped: (color: Color(0xFFE0A800), ink: true),
    MushafWordMark.wrong: (color: Color(0xFFD32F2F), ink: true),
    MushafWordMark.tashkeel: (color: Color(0xFFEF6C00), ink: true),
    MushafWordMark.checking: (color: Color(0xFFFFAB91), ink: true),
    MushafWordMark.uncertain: (color: Color(0xFFFBC02D), ink: true),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(ayahViewPreferencesProvider);
    final canonical = ref.watch(_ayahWordsProvider(ayahId)).value;
    final meanings = view.showWordMeanings
        ? ref.watch(ayahWordMeaningsProvider(ayahId)).value ?? const {}
        : const <int, String>{};
    final focused =
        ref.watch(mushafFocusAyahProvider.select((f) => f?.ayahId)) == ayahId;
    final theme = Theme.of(context);
    final anyHidden = hidden.contains(true);
    ref.watch(bookmarksProvider);
    final bookmarked = ref.read(bookmarksProvider.notifier).hasAyah(ayahId);
    // The passage's tint (as on the printed page): under the blue of the
    // ayah in focus, and not while words of it are hidden.
    final tint = ref.watch(mushafPassagesProvider) && !anyHidden
        ? (ref.watch(passageColorsProvider).value ?? const {})[ayahId]
        : null;
    final verse = (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000);

    // Each page word's text: its canonical word, with any canonical words
    // the engine joins into it (15:7 «لَّوْمَا»).
    String textOf(int k) {
      if (canonical == null) return '';
      final from = words[k].wordIndex;
      final to = k + 1 < words.length
          ? words[k + 1].wordIndex
          : (canonical.isEmpty ? from + 1 : canonical.last.wordIndex + 1);
      return [
        for (final w in canonical)
          if (w.wordIndex >= from && w.wordIndex < to) w.text,
      ].join(' ');
    }

    return AnimatedContainer(
      key: ValueKey('ayah-mode-$ayahId'),
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(TahfeezSpacing.sm),
      decoration: BoxDecoration(
        color: focused
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : tint ?? Colors.transparent,
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TahfeezSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                ),
                child: Text(
                  '${verse.chapterNo}:${verse.verseNo}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('ayah-mode-play-$ayahId'),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.play_arrow_rounded, color: colors.text),
                tooltip: AppLocalizations.of(context).listenPlayAyah,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final message = AppLocalizations.of(context).listenOffline;
                  final played = await ref
                      .read(quranAudioPlayerProvider.notifier)
                      .playAyahs([
                        ayahId,
                      ], options: const ListenOptions(followPages: false));
                  if (!played) showListenOffline(messenger, message);
                },
              ),
              // Bookmarked from here too (the ayah sheet, a long press on a
              // word, has the rest).
              IconButton(
                key: ValueKey('ayah-mode-bookmark-$ayahId'),
                visualDensity: VisualDensity.compact,
                isSelected: bookmarked,
                icon: Icon(Icons.bookmark_border_rounded, color: colors.text),
                selectedIcon: Icon(
                  Icons.bookmark_rounded,
                  color: theme.colorScheme.primary,
                ),
                tooltip: bookmarked
                    ? AppLocalizations.of(context).bookmarkRemove
                    : AppLocalizations.of(context).bookmarkAyah,
                onPressed: () =>
                    ref.read(bookmarksProvider.notifier).toggleAyah(ayahId),
              ),
            ],
          ),
          // The Arabic, word by word, right to left.
          Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 6,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (var k = 0; k < words.length; k++)
                  KeyedSubtree(
                    key: wordKeys[k],
                    child: _Word(
                      key: ValueKey(
                        'ayah-word-${words[k].ayahId}:${words[k].wordIndex}',
                      ),
                      text: textOf(k),
                      meaning: meanings[words[k].wordIndex],
                      hidden: hidden[k],
                      style: _markStyles[marks[k]],
                      colors: colors,
                      onTap: hidden[k]
                          ? null
                          : () =>
                                showWordDetailSheet(context, wordRef: words[k]),
                      onLongPress: () => showAyahDetailSheet(
                        context,
                        mushafId: mushafId,
                        pageNumber: pageNumber,
                        ayahId: ayahId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // What could give the hidden words away waits until they show.
          if (view.showTransliteration && !anyHidden)
            _Transliteration(ayahId: ayahId, colors: colors),
          if (view.showTranslation)
            _Translations(ayahId: ayahId, colors: colors),
          if (view.showTafsir) _Tafsir(verse: verse, colors: colors),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    super.key,
    required this.text,
    required this.meaning,
    required this.hidden,
    required this.style,
    required this.colors,
    this.onTap,
    this.onLongPress,
  });

  final String text;
  final String? meaning;
  final bool hidden;
  final ({Color color, bool ink})? style;
  final MushafAppearanceColors colors;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final mark = style;
    final ink = mark != null && mark.ink ? mark.color : colors.text;
    final band = mark != null && !mark.ink ? mark.color : null;
    final word = Text(
      text,
      textDirection: TextDirection.rtl,
      style: quranTextStyle(
        // Hidden: its place kept (the line does not reflow), the word not
        // shown.
        color: hidden ? Colors.transparent : ink,
        fontFamily: 'Scheherazade New',
        fontSize: 28,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color:
                  band ??
                  (hidden
                      ? colors.secondaryText.withValues(alpha: 0.14)
                      : null),
              borderRadius: BorderRadius.circular(6),
            ),
            child: word,
          ),
          if (meaning != null && !hidden)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                meaning!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: colors.secondaryText),
              ),
            ),
        ],
      ),
    );
  }
}

class _Transliteration extends ConsumerWidget {
  const _Transliteration({required this.ayahId, required this.colors});

  final int ayahId;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(ayahTransliterationProvider(ayahId)).value;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      key: ValueKey('ayah-mode-transliteration-$ayahId'),
      textDirection: TextDirection.ltr,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: colors.secondaryText,
        height: 1.5,
      ),
    );
  }
}

class _Translations extends ConsumerWidget {
  const _Translations({required this.ayahId, required this.colors});

  final int ayahId;
  final MushafAppearanceColors colors;

  static const _rtl = {'ar', 'ur', 'fa', 'he', 'ps', 'sd', 'ug', 'ckb'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(ayahTranslationsProvider(ayahId)).value;
    if (texts == null || texts.isEmpty) return const SizedBox.shrink();
    final books = ref.watch(activeTranslationBooksProvider).value ?? const {};
    return DefaultTextStyle.merge(
      style: TextStyle(color: colors.text),
      child: Column(
        key: ValueKey('ayah-mode-translation-$ayahId'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.sm,
        children: [
          for (final entry in texts.entries)
            TranslationBlock(
              verseText: entry.value,
              authorName: books[entry.key]?.author ?? entry.key,
              inlineFootnotes: true,
              textDirection: _rtl.contains(books[entry.key]?.languageCode)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
        ],
      ),
    );
  }
}

class _Tafsir extends ConsumerWidget {
  const _Tafsir({required this.verse, required this.colors});

  final VerseRef verse;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafsirId = ref.watch(tafsirSelectionControllerProvider);
    if (tafsirId == null) return const SizedBox.shrink();
    final text = ref
        .watch(
          tafsirVerseTextProvider(
            chapterNo: verse.chapterNo,
            verseNo: verse.verseNo,
            tafsirId: tafsirId,
          ),
        )
        .value;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('ayah-mode-tafsir-${verse.chapterNo}:${verse.verseNo}'),
      padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
      decoration: BoxDecoration(
        color: colors.secondaryText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
      ),
      child: Text(
        text.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.text,
          height: 1.6,
        ),
      ),
    );
  }
}

/// The page's end: on to the previous or next page.
class _PageButtons extends ConsumerWidget {
  const _PageButtons({
    required this.pageNumber,
    required this.pageCount,
    required this.colors,
  });

  final int pageNumber, pageCount;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final turn = ref.read(mushafPageTurnRequestsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: TahfeezSpacing.lg),
      child: Row(
        children: [
          TextButton.icon(
            key: const ValueKey('ayah-mode-previous-page'),
            onPressed: pageNumber > 1
                ? () => turn.toPage(pageNumber - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            label: Text(l10n.commonPrevious),
          ),
          const Spacer(),
          Text(
            l10n.ayahModePage(pageNumber),
            style: TextStyle(color: colors.secondaryText),
          ),
          const Spacer(),
          TextButton.icon(
            key: const ValueKey('ayah-mode-next-page'),
            onPressed: pageNumber < pageCount
                ? () => turn.toPage(pageNumber + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            iconAlignment: IconAlignment.end,
            label: Text(l10n.commonNext),
          ),
        ],
      ),
    );
  }
}
