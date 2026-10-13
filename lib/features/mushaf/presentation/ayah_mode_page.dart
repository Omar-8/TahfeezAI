import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../quran/application/ayah_reading_extras.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
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
import '../../../quran/presentation/meaning_resource_names.dart';

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
    this.scrollController,
  });

  final int mushafId;
  final int pageNumber;
  final int pageCount;
  final MushafAppearanceColors colors;
  final bool isCurrentPage;

  /// The continuous layout's list, this page laid in it
  /// (`AyahModeContinuous`); without it the page scrolls on its own.
  final ScrollController? scrollController;

  @override
  ConsumerState<AyahModePage> createState() => AyahModePageState();
}

class AyahModePageState extends ConsumerState<AyahModePage> {
  /// The page's words in reading order (the engine's), and each ayah's
  /// end as a count of them.
  List<WordRef>? _words;
  List<int> _ayahEnds = const [];
  Object? _error;

  // Not restored from page storage (shared by the pager's pages): a page
  // opens at its top, or where a mode brings it.
  final _ownScroll = ScrollController(keepScrollOffset: false);
  ScrollController get _scroll => widget.scrollController ?? _ownScroll;
  bool get _embedded => widget.scrollController != null;

  /// The page's top (in the continuous layout).
  final _topKey = GlobalKey();
  final _ayahKeys = <int, GlobalKey>{};

  /// Each page word's key (by its page index), to scroll a word into view.
  final _wordKeys = <int, GlobalKey>{};

  /// Brings the page's word [index] into view (revealing and hiding).
  ///
  /// The top of its ayah's card, as the modes show an ayah — unless that
  /// would leave the word below the screen (a card taller than it): then
  /// just enough to show the word.
  void _scrollToWord(int index) {
    _unpin();
    final ayahId = _words != null && index < _words!.length
        ? _words![index].ayahId
        : null;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(
        _ayahKeys[ayahId] ?? _wordKeys[index],
        keepInView: _wordKeys[index],
      ),
    );
  }

  /// Scrolls this page's own list (never the pager around it) so [key]'s
  /// widget sits at [alignment] of the screen — or, [onlyIfHidden], just
  /// into view, and not at all when it already is.
  ///
  /// With [keepInView], never so far that its widget ends below the screen.
  /// Returns where it scrolls to (`null`: nothing there to scroll to).
  double? _reveal(
    GlobalKey? key, {
    double alignment = 0.1,
    bool animate = true,
    bool onlyIfHidden = false,
    GlobalKey? keepInView,
  }) {
    final box = key?.currentContext?.findRenderObject();
    if (box == null || !box.attached || !_scroll.hasClients) return null;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final position = _scroll.position;
    double target;
    if (onlyIfHidden) {
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final bottom = viewport.getOffsetToReveal(box, 1).offset;
      if (position.pixels > top) {
        target = top;
      } else if (position.pixels < bottom) {
        target = bottom;
      } else {
        return position.pixels;
      }
    } else {
      // Its top [alignment] of the way down the room it leaves — and for
      // one taller than the screen (a long ayah with its meanings), its
      // top just below the screen's: aligning a tall one would lift its
      // top off the screen.
      final height = box is RenderBox && box.hasSize ? box.size.height : 0.0;
      final room = position.viewportDimension - height;
      target =
          viewport.getOffsetToReveal(box, 0).offset -
          (room > 0 ? room * alignment : TahfeezSpacing.sm);
    }
    final inner = keepInView?.currentContext?.findRenderObject();
    if (inner != null && inner.attached) {
      // Where the inner widget's bottom meets the screen's.
      final atBottom = viewport.getOffsetToReveal(inner, 1).offset;
      if (atBottom > target) target = atBottom;
    }
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 1) return target;
    if (animate) {
      unawaited(
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      );
    } else {
      _scroll.jumpTo(target);
    }
    return target;
  }

  /// An ayah opened at (Daily ayah, Continue reading, the ayah sheet's
  /// More): its card's top held in place while the page settles —
  /// translations, tafsir and meanings arriving after it grow the ayahs
  /// above — until nothing has moved it for a moment (or a few seconds
  /// at most), the reader scrolls, or a mode moves on to another ayah.
  int? _pinned;
  Duration? _pinnedSince, _pinMoved;
  double? _pinAt;

  static const _pinSettled = Duration(milliseconds: 1500);
  static const _pinLongest = Duration(seconds: 6);

  void _pin(int ayahId) {
    final holding = _pinned != null;
    _pinIsTarget = false;
    _pinned = ayahId;
    _pinnedSince = _pinMoved = null;
    _pinAt = null;
    if (!holding) _holdPin();
  }

  void _holdPin() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final id = _pinned;
      if (!mounted || id == null) return;
      final since = _pinnedSince ??= timeStamp;
      final at = _reveal(_ayahKeys[id], animate: false);
      if (at != null && (_pinAt == null || (at - _pinAt!).abs() >= 1)) {
        _pinAt = at;
        _pinMoved = timeStamp;
      }
      final settled = timeStamp - (_pinMoved ?? since) > _pinSettled;
      if (settled || timeStamp - since > _pinLongest) {
        _unpin();
        return;
      }
      WidgetsBinding.instance.scheduleFrame();
      _holdPin();
    });
  }

  /// The ayah held is the one asked for ([ayahModeTargetProvider]).
  var _pinIsTarget = false;

  void _unpin() {
    if (_pinIsTarget) {
      _pinIsTarget = false;
      ref.read(ayahModeTargetProvider.notifier).done();
    }
    _pinned = null;
    _pinnedSince = _pinMoved = null;
    _pinAt = null;
  }

  /// The reader took the list (the continuous layout).
  void releasePin() => _unpin();

  /// Turned to in the continuous layout: the ayah in turn brought into
  /// view if it is on this page, else the page's top.
  void bringIntoView() {
    final active = _activeAyah();
    if (active != null && (_words?.any((w) => w.ayahId == active) ?? false)) {
      _scrollTo(active);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(_topKey, alignment: 0),
      );
    }
  }

  /// Saves the ayah at the top of the screen (the continuous layout,
  /// after the reader scrolls).
  void recordPosition() => _recordPosition();

  /// The reader is dragging the list (not a scroll of ours).
  var _userScrolling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AyahModePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // (In the continuous layout a page becomes current by the reader's
    // scrolling: nothing to bring into view.)
    if (widget.isCurrentPage && !oldWidget.isCurrentPage && !_embedded) {
      _bringActiveIntoView();
      if (_pinned == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _recordPosition());
      }
    }
    if (oldWidget.pageNumber != widget.pageNumber) {
      setState(() => _words = null);
      _load();
    }
  }

  @override
  void dispose() {
    _ownScroll.dispose();
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
      // A page turned to, nothing to bring into view: its top is the place.
      if (_pinned == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _recordPosition());
      }
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
    // The ayah held already: it stays held. A mode moved on to another:
    // that one's scroll wins.
    if (_pinned == ayahId) return;
    _unpin();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(_ayahKeys[ayahId], animate: animate),
    );
  }

  /// Opened (or turned to) mid-recitation or mid-listening: straight to
  /// the ayah whose turn it is, if it is on this page.
  void _bringActiveIntoView() {
    if (!widget.isCurrentPage) return;
    final active = _activeAyah();
    if (active != null && (_words?.any((w) => w.ayahId == active) ?? false)) {
      _pin(active);
    }
  }

  /// The ayah whose turn it is: the reciter's, the recitation's, or the
  /// ayah in focus.
  int? _activeAyah() =>
      ref.read(quranAudioPlayerProvider)?.ayahId ??
      (ref.read(hifzControllerProvider).running
          ? ref.read(hifzControllerProvider).expected?.ayahId
          : null) ??
      ref.read(mushafFocusAyahProvider)?.ayahId;

  /// Within a long ayah: the word due next kept on screen, scrolling no
  /// more than needed.
  void _keepWordVisible(WordRef word) {
    final index = _words?.indexOf(word) ?? -1;
    if (index < 0) return;
    _unpin();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(_wordKeys[index], onlyIfHidden: true),
    );
  }

  void _bringTargetIntoView() {
    final target = ref.read(ayahModeTargetProvider);
    final words = _words;
    if (target == null || words == null || _pinned == target) return;
    if (!words.any((w) => w.ayahId == target)) return;
    _pin(target);
    // Asked until shown and settled (or the reader takes over): a page
    // replaced meanwhile — the saved layout read back as the app starts —
    // leaves it to the page that replaces it.
    _pinIsTarget = true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final words = _words;
    if (_error != null) {
      final message = Center(
        child: Text(
          AppLocalizations.of(context).ayahModeUnavailable,
          style: TextStyle(color: colors.secondaryText),
        ),
      );
      return _embedded ? SizedBox(height: 300, child: message) : message;
    }
    if (words == null) {
      const loading = Center(child: CircularProgressIndicator());
      return _embedded ? const SizedBox(height: 600, child: loading) : loading;
    }
    // The recitation's place, and the reciter's ayah, kept in view on the
    // page being read.
    // Whichever mode runs, the ayah whose turn it is kept in view on the
    // page being read: the reciter's (Listen, Follow along's reciter), the
    // reciter's next word (Recite, Loop, Follow along's user turn), or the
    // ayah in focus — whether highlighted or not.
    // (In the continuous layout, whichever page holds it.)
    if (widget.isCurrentPage || _embedded) {
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
    // Ayah mode's text size (its view settings), over the reader's own.
    final media = MediaQuery.of(context);
    final column = MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(
          media.textScaler.scale(1) *
              ref.watch(tafsirTextScaleControllerProvider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k <= ayahs.length; k++)
            _item(context, k, ayahs, hidden: hidden, mark: mark, words: words),
        ],
      ),
    );
    if (_embedded) {
      // One page of the continuous scroll: its number, then its ayahs.
      return Padding(
        key: _topKey,
        padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageDivider(pageNumber: widget.pageNumber, colors: colors),
            column,
          ],
        ),
      );
    }
    return Container(
      color: colors.background,
      // The whole page built at once (a page holds at most a few dozen
      // ayahs): every ayah and word is there to scroll to — revealing,
      // hiding and following the recitation need them.
      // Where the reader stops is where Continue reading goes back to.
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth != 0) return false;
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _userScrolling = true;
            _unpin();
          } else if (n is ScrollEndNotification && _userScrolling) {
            _userScrolling = false;
            _recordPosition();
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
            TahfeezSpacing.md,
            TahfeezSpacing.lg,
          ),
          child: column,
        ),
      ),
    );
  }

  /// The ayah at the top of the page on screen, saved as the place to
  /// continue reading from (Home).
  void _recordPosition() {
    if (!widget.isCurrentPage || !mounted) return;
    // The screen: the continuous list, or this page's own.
    final list = _embedded
        ? Scrollable.maybeOf(context)?.context.findRenderObject()
        : context.findRenderObject();
    if (list is! RenderBox || !list.attached) return;
    final top = list.localToGlobal(Offset.zero).dy;
    int? best;
    var bestY = double.negativeInfinity;
    int? first;
    var firstY = double.infinity;
    for (final e in _ayahKeys.entries) {
      final box = e.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy - top;
      if (y < firstY) {
        firstY = y;
        first = e.key;
      }
      // The last ayah starting in the screen's upper quarter, or above it.
      if (y <= list.size.height / 4 && y > bestY) {
        bestY = y;
        best = e.key;
      }
    }
    final ayahId = best ?? first;
    if (ayahId == null) return;
    final location = QuranLocation.ayah(ayahId ~/ 1000, ayahId % 1000);
    if (ref.read(recentQuranLocationControllerProvider) == location) return;
    unawaited(
      ref.read(recentQuranLocationControllerProvider.notifier).record(location),
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
      if (_embedded) return const SizedBox(height: TahfeezSpacing.lg);
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
                  fontFamily: ref
                      .watch(
                        ayahViewPreferencesProvider.select((v) => v.quranFont),
                      )
                      .family,
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
                      fontFamily: view.quranFont.family,
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
    required this.fontFamily,
    this.onTap,
    this.onLongPress,
  });

  final String fontFamily;
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
        fontFamily: fontFamily,
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
              authorName: switch (books[entry.key]) {
                final book? => translationName(
                  AppLocalizations.of(context),
                  book,
                ),
                null => entry.key,
              },
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
      // Read as a Mushaf's pages turn, in every language: the next page on
      // the left, the previous on the right, each arrow pointing its way.
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          TextButton(
            key: const ValueKey('ayah-mode-previous-page'),
            onPressed: pageNumber > 1
                ? () => turn.toPage(pageNumber - 1)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              spacing: TahfeezSpacing.xs,
              children: [
                Text(l10n.commonPrevious),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          Expanded(
            child: Text(
              l10n.ayahModePage(pageNumber),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.secondaryText),
            ),
          ),
          TextButton(
            key: const ValueKey('ayah-mode-next-page'),
            onPressed: pageNumber < pageCount
                ? () => turn.toPage(pageNumber + 1)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              spacing: TahfeezSpacing.xs,
              children: [const Icon(Icons.chevron_left), Text(l10n.commonNext)],
            ),
          ),
        ],
      ),
    );
  }
}

/// A page's start in the continuous layout: its number between rules.
class _PageDivider extends StatelessWidget {
  const _PageDivider({required this.pageNumber, required this.colors});

  final int pageNumber;
  final MushafAppearanceColors colors;

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(
      child: Divider(color: colors.secondaryText.withValues(alpha: 0.25)),
    );
    return Padding(
      key: ValueKey('ayah-mode-page-divider-$pageNumber'),
      padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.sm),
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.sm),
            child: Text(
              AppLocalizations.of(context).ayahModePage(pageNumber),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.secondaryText),
            ),
          ),
          rule,
        ],
      ),
    );
  }
}
