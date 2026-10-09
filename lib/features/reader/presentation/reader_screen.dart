import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/coming_soon.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/mushaf_appearance_controller.dart';
import '../../mushaf/application/mushaf_focus_ayah.dart';
import '../../mushaf/application/mushaf_page_providers.dart';
import '../../mushaf/domain/mushaf_appearance.dart';
import '../../mushaf/presentation/mushaf_pager.dart';
import '../../mushaf/presentation/mushaf_page_title.dart';
import '../../mushaf/presentation/mushaf_reader_options_sheet.dart';
import '../../recitation/presentation/recitation_controls.dart';
import '../application/reader_preferences_controller.dart';
import '../application/reader_session_controller.dart';
import '../application/verse_mode_feature.dart';
import '../domain/reader_layout_item.dart';
import '../domain/reader_mode.dart';
import 'widgets/bismillah_divider.dart';
import 'widgets/chapter_info_card.dart';
import 'widgets/reader_mode_switch.dart';
import 'widgets/reader_options_sheet.dart';
import 'widgets/section_marker_label.dart';
import 'widgets/verse_block.dart';
import 'widgets/verse_share_sheet.dart';

/// Tahfeez's verse-by-verse Quran reader — this milestone's "production
/// -quality semantic reader," reached from any [QuranLocation] the Quran
/// index (Milestone 5) or a future caller (search, bookmarks, deep links)
/// resolves. See `lib/features/reader/application/reader_session_controller.dart`
/// for how every reading mode (full Surah, verse range, individual Ayah,
/// Juz, Hizb, continuous scrolling) is served by one batched-loading
/// engine.
///
/// The reader is deliberately quieter than Home
/// (`docs/DESIGN_DIRECTION.md`'s "chrome recedes while reading" principle):
/// a plain, non-collapsing `AppBar` rather than a scroll-linked collapsing
/// header (real collapsing-chrome animation is deferred — see
/// `docs/ARCHITECTURE.md`'s "what this milestone deliberately did not do"),
/// and no decorative surfaces around the Arabic text itself.
///
/// Owns **both** [ReaderMode.verseByVerse] and [ReaderMode.mushaf]: the
/// [ReaderModeSwitch] in the app bar toggles which body renders, in place —
/// no route push, no separate screen — while preserving reading position in
/// both directions (verse-by-verse's topmost visible ayah resolves to a
/// Mushaf page on the way in; that page's first real Quran word resolves
/// back to an ayah to scroll to on the way out). [ReaderMode.mushaf] is the
/// default for a fresh install (`ReaderModePreferenceController`), so this
/// resolution also runs on a screen's very first build whenever no stored
/// preference overrides it. [QuranLocationPage] (jumping straight to a
/// Mushaf page with no ayah anchor, from the Quran index's Page tab) is
/// deliberately not handled here — it has no verse-by-verse equivalent to
/// toggle to, and keeps its own standalone `MushafReaderScreen` route.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.location});

  final QuranLocation location;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  bool _recordedInitialLocation = false;

  // The verse-by-verse session's location — starts as `widget.location`,
  // but can change: switching back from Mushaf mode after swiping to a
  // page belonging to a *different* Surah than the one this screen opened
  // with has nowhere else to land verse-by-verse content for that Surah,
  // since the session is keyed by location. Re-anchoring here (to the
  // exact ayah the swiped-to page starts on) is what lets Mushaf mode
  // range freely across the whole Mushaf while verse-by-verse mode still
  // always follows it back correctly, not just within the original
  // Surah/Juz/Hizb/range.
  late QuranLocation _location = widget.location;

  // The Mushaf page currently resolved for this location, and the Mushaf
  // it belongs to. Resolved lazily (once) whenever the reader is in, or
  // switches to, Mushaf mode — never eagerly in verse-by-verse mode, so a
  // reader that's never touched Mushaf mode never pays for the extra
  // lookups.
  int? _mushafId;
  int? _mushafPageNumber;
  bool _resolvingMushafPage = false;

  // Set when no Mushaf page can be resolved (no Mushaf dataset installed, or
  // a location with no start ayah), so the reader says so instead of
  // spinning forever.
  bool _mushafUnavailable = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _scrollController.addListener(_maybeUpdateLiveMushafTitle);
    _focus = ref.read(mushafFocusAyahProvider.notifier);
    // Opened at an ayah (Home's Daily Ayah, a search result): that ayah is
    // highlighted on its Mushaf page while this screen is open.
    if (widget.location case QuranLocationAyah(
      :final chapterNo,
      :final verseNo,
    )) {
      Future.microtask(() {
        if (mounted) _focus.focus(this, chapterNo * 1000 + verseNo);
      });
    }
  }

  // Captured up front (initState): `ref` is unusable by the time dispose
  // runs.
  late final MushafFocusAyah _focus;

  @override
  void dispose() {
    final focus = _focus;
    Future.microtask(() => focus.clear(this));
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.removeListener(_maybeUpdateLiveMushafTitle);
    _scrollController.dispose();
    super.dispose();
  }

  // The last ayah this checked, so a scroll notification that hasn't
  // actually crossed into a different ayah's territory doesn't kick off a
  // fresh page/Surah/Juz resolution for no reason.
  int? _lastLiveTitleAyahId;

  /// Keeps the verse-by-verse app bar's live Surah/page/Juz title
  /// (`MushafPageTitle`, the same widget Mushaf mode's app bar uses)
  /// tracking whatever ayah is actually scrolled to the top, in continuous
  /// scrolling as much as a single jump — never just the ayah the reader
  /// was originally opened with. Piggybacks on the same
  /// [_currentlyVisibleAyahId] logic [_switchMode] already uses to resolve
  /// the right Mushaf page on an explicit mode switch, just running
  /// continuously instead of once.
  void _maybeUpdateLiveMushafTitle() {
    if (_resolvingMushafPage) return;
    final ayahId = _currentlyVisibleAyahId();
    if (ayahId == null || ayahId == _lastLiveTitleAyahId) return;
    _lastLiveTitleAyahId = ayahId;
    _resolveMushafPageForAyah(ayahId);
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // `maxScrollExtent <= 0` means there's nothing to scroll yet (a short
    // Surah/session whose content doesn't even fill the viewport) --
    // without this guard, `maxScrollExtent - 800` goes deeply negative for
    // such a session, making the "near the bottom" check below vacuously
    // true on every scroll notification and triggering `loadMore()`
    // continuously instead of only once real scrollable content exists and
    // the user has actually neared its end.
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 800) return;

    final continuousScrolling = ref.read(
      continuousScrollingPreferenceControllerProvider,
    );
    if (!continuousScrolling) return;

    ref.read(readerSessionProvider(_location).notifier).loadMore();
  }

  GlobalKey _keyFor(int ayahId) =>
      _verseKeys.putIfAbsent(ayahId, () => GlobalKey());

  /// The ayah currently scrolled to the top of the verse-by-verse view —
  /// found by comparing every rendered verse's on-screen position, not by
  /// trusting [ReaderSessionState.scrollToAyahId] (which is only set once,
  /// for the *initial* auto-scroll, and is cleared the moment that
  /// completes — using it here would always resolve back to wherever
  /// [_location] originally started, ignoring anywhere the user has
  /// since scrolled). `null` before layout has happened at least once.
  int? _currentlyVisibleAyahId() {
    if (!_scrollController.hasClients) return null;
    int? bestAyahId;
    double bestDistance = double.infinity;
    for (final entry in _verseKeys.entries) {
      final renderObject = entry.value.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      if (top < -renderObject.size.height) continue; // scrolled fully past
      final distance = top.abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAyahId = entry.key;
      }
    }
    return bestAyahId;
  }

  /// Resolves [_mushafId]/[_mushafPageNumber]/[_mushafSurahNo]/
  /// [_mushafJuzNo] for [ayahId] — the same intent as the reference's
  /// `handleModeTransition`, independently implemented.
  Future<void> _resolveMushafPageForAyah(int ayahId) async {
    _resolvingMushafPage = true;
    final repository = ref.read(quranRepositoryProvider);
    final scriptCode = ref.read(quranScriptCodeProvider);
    final mushaf = await repository.getMushaf(scriptCode: scriptCode);
    if (mushaf == null) {
      _resolvingMushafPage = false;
      if (mounted) setState(() => _mushafUnavailable = true);
      return;
    }
    final pageNumber =
        await repository.getPageForAyah(mushafId: mushaf.id, ayahId: ayahId) ??
        1;
    _resolvingMushafPage = false;
    if (!mounted) return;
    setState(() {
      _mushafId = mushaf.id;
      _mushafPageNumber = pageNumber;
      // Keeps `_lastLiveTitleAyahId` (and therefore the verse-by-verse app
      // bar's Surah name, via `surahNoOverride` below) in sync regardless
      // of which caller resolved this page -- not just the scroll-driven
      // `_maybeUpdateLiveMushafTitle` path, but also the "resolve once on
      // first build" path (`_ensureMushafPageResolvedOnce`), which never
      // touched this field before and so left the very first frame's title
      // with no override, only the entry location's own Surah.
      _lastLiveTitleAyahId = ayahId;
    });
  }

  /// The passive path: resolves a Mushaf page only if none is resolved
  /// yet, from the reading session's topmost ayah — for a screen that
  /// opens directly into Mushaf mode (the default for a fresh install; see
  /// `ReaderModePreferenceController`) rather than via an explicit tap.
  /// Never re-resolves once a page is set: an explicit switch
  /// ([_switchMode]) always calls [_resolveMushafPageForAyah] directly
  /// instead, specifically so it re-resolves fresh every time rather than
  /// reusing a stale page from an earlier visit to this mode.
  Future<void> _ensureMushafPageResolvedOnce() async {
    if (_mushafPageNumber != null ||
        _resolvingMushafPage ||
        _mushafUnavailable) {
      return;
    }
    if (!ref.read(verseByVerseModeEnabledProvider)) {
      // Mushaf-only: the start ayah comes straight from the location. The
      // verse-by-verse session below loads a whole chapter's words and
      // translations, which this mode never displays.
      final startAyahId = await _startAyahIdFor(_location);
      if (startAyahId == null) {
        if (mounted) setState(() => _mushafUnavailable = true);
        return;
      }
      await _resolveMushafPageForAyah(startAyahId);
      if (mounted && !_recordedInitialLocation && _mushafPageNumber != null) {
        _recordedInitialLocation = true;
        ref
            .read(recentQuranLocationControllerProvider.notifier)
            .record(_location);
      }
      return;
    }
    final session = await ref.read(readerSessionProvider(_location).future);
    final ayahId =
        session.scrollToAyahId ??
        session.items.whereType<ReaderVerseItem>().firstOrNull?.ayah.ayah.id;
    if (ayahId == null) return;
    await _resolveMushafPageForAyah(ayahId);
  }

  /// The first ayah of [location], without loading any reading session.
  Future<int?> _startAyahIdFor(QuranLocation location) async {
    final repository = ref.read(quranRepositoryProvider);
    switch (location) {
      case QuranLocationSurah(:final surahNo):
        return surahNo * 1000 + 1;
      case QuranLocationAyah(:final chapterNo, :final verseNo):
        return chapterNo * 1000 + verseNo;
      case QuranLocationAyahRange(:final chapterNo, :final fromVerseNo):
        return chapterNo * 1000 + fromVerseNo;
      case QuranLocationJuz(:final juzNo):
        final first = (await repository.getJuz(juzNo))?.ranges.firstOrNull;
        return first == null ? null : first.surahNo * 1000 + first.startAyahNo;
      case QuranLocationHizb(:final hizbNo):
        final first = (await repository.getHizb(hizbNo))?.ranges.firstOrNull;
        return first == null ? null : first.surahNo * 1000 + first.startAyahNo;
      case QuranLocationPage():
        return null;
    }
  }

  /// The reverse direction: resolves the ayah to scroll to in verse-by-verse
  /// mode from whatever Mushaf page is currently showing, by finding that
  /// page's first real Quran word — never a marker/ornament token, which
  /// carries no canonical ayah of its own.
  Future<int?> _firstAyahOnCurrentMushafPage() async {
    if (_mushafId == null || _mushafPageNumber == null) return null;
    final bundle = await ref.read(
      mushafPageDataProvider(_mushafId!, _mushafPageNumber!).future,
    );
    if (bundle == null) return null;

    final lines = [...bundle.lines]
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    for (final line in lines) {
      final tokens = bundle.tokensByLineNumber[line.lineNumber] ?? const [];
      for (final token in tokens) {
        if (token.tokenType == MushafTokenType.quranWord &&
            token.canonicalAyahId != null) {
          return token.canonicalAyahId;
        }
      }
    }
    return null;
  }

  /// Called as the user swipes within Mushaf mode — keeps [_mushafPageNumber]
  /// (and therefore the app bar's live Surah/Juz title, and whatever page
  /// switching back to verse-by-verse resolves from) tracking the page
  /// actually on screen, not just whatever page Mushaf mode was entered on.
  void _onMushafPageChanged(int pageNumber) {
    setState(() => _mushafPageNumber = pageNumber);
  }

  /// Resolves everything the target mode needs to show the right position
  /// **before** actually flipping [ReaderModePreferenceController]'s mode —
  /// never the other way around. Flipping the mode first (this method's
  /// earlier, buggier shape) makes `build()`'s mode-branch switch over
  /// immediately, on a frame where [_mushafId]/[_mushafPageNumber] (or
  /// [_location]) still held whatever a *previous* visit to that mode left
  /// behind — at best a visible flash of the wrong page/Surah before the
  /// real resolution completed and overwrote it, at worst (if that overwrite
  /// were ever skipped) a real, sticky "lost my page" bug. Resolving fully
  /// first and flipping the mode last means the very first frame in the new
  /// mode is already correct.
  Future<void> _switchMode(ReaderMode target) async {
    if (target == ReaderMode.mushaf) {
      // Always resolves fresh from the verse-by-verse view's current
      // scroll position — never reuses whatever page a *previous* visit to
      // Mushaf mode left behind, which looked like "always jumps back to
      // the same page" regardless of where the user had since scrolled.
      final currentAyahId =
          _currentlyVisibleAyahId() ??
          ref
              .read(readerSessionProvider(_location))
              .value
              ?.items
              .whereType<ReaderVerseItem>()
              .firstOrNull
              ?.ayah
              .ayah
              .id;
      if (currentAyahId != null) {
        await _resolveMushafPageForAyah(currentAyahId);
      }
      await ref
          .read(readerModePreferenceControllerProvider.notifier)
          .setMode(ReaderMode.mushaf);
      if (_mushafPageNumber == null && mounted) showComingSoon(context);
      return;
    }
    if (target == ReaderMode.verseByVerse) {
      final targetAyahId = await _firstAyahOnCurrentMushafPage();
      if (targetAyahId != null) {
        final targetChapterNo = targetAyahId ~/ 1000;
        final loadedChapters =
            ref
                .read(readerSessionProvider(_location))
                .value
                ?.items
                .whereType<ReaderVerseItem>()
                .map((item) => item.ayah.ayah.chapterNo)
                .toSet() ??
            const <int>{};
        if (loadedChapters.contains(targetChapterNo)) {
          ref
              .read(readerSessionProvider(_location).notifier)
              .scrollTo(targetAyahId);
        } else if (mounted) {
          // Mushaf mode can range across the whole Mushaf, but a
          // Surah/single-Ayah/range session can never load a *different*
          // Surah — re-anchor the whole verse-by-verse session to the
          // swiped-to Surah, exactly like opening the reader fresh at that
          // ayah would (its own session naturally scrolls to this exact
          // ayah on load, so no separate `scrollTo` call is needed here).
          setState(() {
            _location = QuranLocation.ayah(
              targetChapterNo,
              targetAyahId % 1000,
            );
            _recordedInitialLocation = false;
          });
        }
      }
      await ref
          .read(readerModePreferenceControllerProvider.notifier)
          .setMode(ReaderMode.verseByVerse);
    }
  }

  void _maybeScrollTo(int? ayahId) {
    if (ayahId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scrollToAyah(ayahId);
      ref.read(readerSessionProvider(_location).notifier).consumeScrollTarget();
    });
  }

  /// Scrolls to [ayahId]'s verse, even when it has never been built —
  /// `Scrollable.ensureVisible` alone only works on a widget that already
  /// has a mounted `BuildContext`, which a `ListView.builder` never gives
  /// an item far from the current scroll position (this reader's own lazy
  /// list only builds items near the viewport, never the whole Surah up
  /// front). Switching from Mushaf mode to verse-by-verse on, say, page 5
  /// of a long Surah is exactly this case: the target ayah can be dozens
  /// of items past whatever's currently built, so silently doing nothing
  /// left the reader sitting at the Surah's own first ayah instead —
  /// confirmed live, not assumed. Estimates the target's scroll offset
  /// from its position in the full item list (proportional to the
  /// `ListView`'s own already-extrapolated total extent) and jumps there
  /// so the lazy list actually builds around it, refining across a few
  /// frames as that extrapolation gets more accurate; only once the target
  /// is genuinely built does it hand off to `Scrollable.ensureVisible` for
  /// the final precise placement.
  Future<void> _scrollToAyah(int ayahId) async {
    if (!_scrollController.hasClients) return;

    Future<bool> tryEnsureVisible() async {
      final context = _keyFor(ayahId).currentContext;
      if (context == null) return false;
      await Scrollable.ensureVisible(
        context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 1),
      );
      return true;
    }

    if (await tryEnsureVisible()) return;

    final items = ref.read(readerSessionProvider(_location)).value?.items;
    if (items == null || items.isEmpty) return;
    final targetIndex = items.indexWhere(
      (item) => item is ReaderVerseItem && item.ayah.ayah.id == ayahId,
    );
    if (targetIndex < 0) return;
    final targetFraction = targetIndex / items.length;

    for (var attempt = 0; attempt < 8; attempt++) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final estimate = (position.maxScrollExtent * targetFraction).clamp(
        0.0,
        position.maxScrollExtent,
      );
      _scrollController.jumpTo(estimate);
      await WidgetsBinding.instance.endOfFrame;
      if (await tryEnsureVisible()) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(verseByVerseModeEnabledProvider)) {
      // Mushaf-only: never build the verse-by-verse session.
      _ensureMushafPageResolvedOnce();
      return _MushafModeScaffold(
        mushafId: _mushafId,
        pageNumber: _mushafPageNumber,
        unavailable: _mushafUnavailable,
        onSwitchMode: _switchMode,
        onPageChanged: _onMushafPageChanged,
      );
    }
    final sessionAsync = ref.watch(readerSessionProvider(_location));
    final readerMode = ref.watch(readerModePreferenceControllerProvider);
    final arabicVisible = ref.watch(
      arabicTextVisiblePreferenceControllerProvider,
    );
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;

    ref.listen(readerSessionProvider(_location), (previous, next) {
      final data = next.value;
      if (data != null && data.items.isNotEmpty && !_recordedInitialLocation) {
        _recordedInitialLocation = true;
        ref
            .read(recentQuranLocationControllerProvider.notifier)
            .record(_location);
      }
      _maybeScrollTo(data?.scrollToAyahId);
    });

    final session = sessionAsync.value;

    if (readerMode == ReaderMode.mushaf) {
      // Fire-and-forget: harmless to call every build (a no-op once a page
      // is already resolved) — this is what makes Mushaf-as-default work
      // on a screen's very first build, not just after an explicit tap.
      _ensureMushafPageResolvedOnce();
      return _MushafModeScaffold(
        mushafId: _mushafId,
        pageNumber: _mushafPageNumber,
        unavailable: _mushafUnavailable,
        onSwitchMode: _switchMode,
        onPageChanged: _onMushafPageChanged,
      );
    }

    // Same "fire-and-forget, no-op once resolved" call the Mushaf-mode
    // branch above makes -- so verse-by-verse mode's own live title
    // (below) already has a real Mushaf page to show on the very first
    // frame, not only after the user scrolls at least once.
    _ensureMushafPageResolvedOnce();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        titleSpacing: 0,
        // The same live Surah/page/Juz title Mushaf mode's app bar shows,
        // once resolved -- kept in sync while scrolling by
        // `_maybeUpdateLiveMushafTitle`, not just on an explicit mode
        // switch. Falls back to the static entry-location title before
        // that first resolution completes (or if no Mushaf dataset is
        // installed at all).
        title: _mushafId == null || _mushafPageNumber == null
            ? Text(_titleFor(_location, AppLocalizations.of(context)))
            : MushafPageTitle(
                mushafId: _mushafId!,
                pageNumber: _mushafPageNumber!,
                // Names the title by the actually-visible ayah's own Surah,
                // not the resolved Mushaf page's opening Surah -- see
                // `surahNoOverride`'s own doc comment for why those two can
                // legitimately disagree in verse-by-verse mode.
                surahNoOverride: _lastLiveTitleAyahId == null
                    ? null
                    : _lastLiveTitleAyahId! ~/ 1000,
              ),
        actions: [
          ReaderModeSwitch(mode: readerMode, onSwitchToMode: _switchMode),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).readerOptions,
            onPressed: () => showReaderOptionsSheet(context),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (state) => _ReaderBody(
          state: state,
          arabicVisible: arabicVisible,
          keyFor: _keyFor,
          scrollController: _scrollController,
          onToggleSelection: (ayahId) => ref
              .read(readerSessionProvider(_location).notifier)
              .toggleSelection(ayahId),
        ),
        loading: () => const TahfeezLoadingView(),
        error: (_, _) => TahfeezEmptyView(
          icon: Icons.menu_book_outlined,
          message: AppLocalizations.of(context).homeQuranDatasetUnavailableBody,
        ),
      ),
      bottomNavigationBar: session != null && session.selectedAyahIds.isNotEmpty
          ? _SelectionBar(
              count: session.selectedAyahIds.length,
              onClear: () => ref
                  .read(readerSessionProvider(_location).notifier)
                  .clearSelection(),
              onShare: () {
                final text = _composeShareText(session);
                showVerseShareSheet(context, text);
              },
            )
          : null,
    );
  }

  String _composeShareText(ReaderSessionState state) {
    final selected =
        state.items
            .whereType<ReaderVerseItem>()
            .map((item) => item.ayah)
            .where((ayah) => state.selectedAyahIds.contains(ayah.ayah.id))
            .toList()
          ..sort((a, b) => a.ayah.id.compareTo(b.ayah.id));

    return selected
        .map((ayah) {
          final reference = '${ayah.ayah.chapterNo}:${ayah.ayah.verseNo}';
          final text = ayah.words.map((w) => w.text).join(' ');
          return '$reference\n$text';
        })
        .join('\n\n');
  }
}

/// The Mushaf-mode body, its own [Scaffold] since a Mushaf page's chrome
/// (background/foreground colors from [MushafAppearanceController], the
/// Translation/Appearance actions) is deliberately distinct from the
/// verse-by-verse app bar/body — see [MushafPageView]'s doc comment on why
/// Mushaf colors never come from `Theme.of(context)`.
class _MushafModeScaffold extends ConsumerWidget {
  const _MushafModeScaffold({
    required this.mushafId,
    required this.pageNumber,
    this.unavailable = false,
    required this.onSwitchMode,
    required this.onPageChanged,
  });

  final int? mushafId;
  final int? pageNumber;
  final bool unavailable;
  final ValueChanged<ReaderMode> onSwitchMode;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;
    final mushafAsync = mushafId == null
        ? null
        : ref.watch(mushafByIdProvider(mushafId!));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        titleSpacing: 0,
        title: mushafId == null || pageNumber == null
            ? Text(
                AppLocalizations.of(context).readerMushaf,
                overflow: TextOverflow.ellipsis,
              )
            : MushafPageTitle(mushafId: mushafId!, pageNumber: pageNumber!),
        actions: [
          if (ref.watch(verseByVerseModeEnabledProvider))
            ReaderModeSwitch(
              mode: ReaderMode.mushaf,
              onSwitchToMode: onSwitchMode,
              // This segment's own "Translation mode" stub (a whole separate
              // reading mode, permanently disabled/coming-soon) is a
              // different thing from the real per-page translation sheet
              // below -- still hidden here regardless: Mushaf mode's app bar
              // is the tightest on space (title + mode switch + translation +
              // Appearance all need to fit), and a permanently-disabled stub
              // is the first thing worth dropping to give the live
              // Surah/page/Juz title room before it truncates.
              showTranslationSegment: false,
              compact: true,
            ),
          // Same icon/tooltip as verse-by-verse mode's own settings button
          // (`Icons.tune`/"Reader options") -- the button itself stays a
          // consistent, always-visible fixture across both modes; only the
          // sheet it opens differs. Mushaf mode's own small menu
          // (Appearance / Quran text boldness) -- shared with
          // `MushafReaderScreen`'s identical button, never the
          // verse-by-verse-only `reader_options_sheet.dart` sheet (which
          // this scaffold never renders while active, so anything gated
          // to Mushaf mode there would be unreachable dead code).
          // Recording: a red dot while a recitation session runs.
          const RecordingDot(),
          // Loop recitation, and Hifz mode's feedback settings, beside the
          // reader's own.
          const HifzLoopButton(),
          const HifzSettingsButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).readerOptions,
            onPressed: () => showMushafReaderOptionsSheet(context),
          ),
        ],
      ),
      // Reports the page on screen to the app shell's recitation bar.
      body: RecitationMushafAnchor(
        location: mushafId == null || pageNumber == null
            ? null
            : QuranLocation.page(mushafId!, pageNumber!),
        child: unavailable && (mushafId == null || pageNumber == null)
            ? _unavailable(context, colors.secondaryText)
            : mushafId == null || pageNumber == null
            ? Center(
                child:
                    mushafAsync?.when(
                      data: (_) => CircularProgressIndicator(
                        color: colors.secondaryText,
                      ),
                      loading: () => CircularProgressIndicator(
                        color: colors.secondaryText,
                      ),
                      error: (_, _) =>
                          _unavailable(context, colors.secondaryText),
                    ) ??
                    CircularProgressIndicator(color: colors.secondaryText),
              )
            : mushafAsync!.when(
                data: (mushaf) {
                  if (mushaf == null) {
                    return _unavailable(context, colors.secondaryText);
                  }
                  return MushafPager(
                    key: ValueKey('mushaf-pager-${mushaf.id}'),
                    mushafId: mushaf.id,
                    pageCount: mushaf.pageCount,
                    initialPageNumber: pageNumber!,
                    onPageChanged: onPageChanged,
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.secondaryText),
                ),
                error: (_, _) => _unavailable(context, colors.secondaryText),
              ),
      ),
    );
  }

  Widget _unavailable(BuildContext context, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context).homeQuranDatasetUnavailableBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

String _titleFor(QuranLocation location, AppLocalizations l10n) {
  return switch (location) {
    QuranLocationSurah(:final surahNo) => l10n.homeContinueReadingSurah(
      surahNo,
    ),
    QuranLocationAyah(:final chapterNo, :final verseNo) => l10n.readerAyahRef(
      '$chapterNo:$verseNo',
    ),
    QuranLocationAyahRange(
      :final chapterNo,
      :final fromVerseNo,
      :final toVerseNo,
    ) =>
      l10n.readerAyahRef('$chapterNo:$fromVerseNo-$toVerseNo'),
    QuranLocationJuz(:final juzNo) => l10n.homeContinueReadingJuz(juzNo),
    QuranLocationHizb(:final hizbNo) => l10n.homeContinueReadingHizb(hizbNo),
    QuranLocationPage(:final pageNumber) => l10n.homeContinueReadingPage(
      pageNumber,
    ),
  };
}

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.state,
    required this.arabicVisible,
    required this.keyFor,
    required this.scrollController,
    required this.onToggleSelection,
  });

  final ReaderSessionState state;
  final bool arabicVisible;
  final GlobalKey Function(int ayahId) keyFor;
  final ScrollController scrollController;
  final ValueChanged<int> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return TahfeezEmptyView(
        icon: Icons.menu_book_outlined,
        message: AppLocalizations.of(context).homeQuranDatasetUnavailableBody,
      );
    }

    final hasActiveSelection = state.selectedAyahIds.isNotEmpty;

    return ListView.builder(
      controller: scrollController,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final key = ValueKey(readerLayoutItemKey(item, index));

        return switch (item) {
          ReaderChapterInfoItem(:final surah) => KeyedSubtree(
            key: key,
            child: ChapterInfoCard(surah: surah),
          ),
          ReaderBismillahItem() => KeyedSubtree(
            key: key,
            child: const BismillahDivider(),
          ),
          ReaderSectionMarkerItem(:final label) => KeyedSubtree(
            key: key,
            child: SectionMarkerLabel(label: label),
          ),
          ReaderVerseItem(:final ayah) => KeyedSubtree(
            key: keyFor(ayah.ayah.id),
            child: VerseBlock(
              ayah: ayah,
              arabicVisible: arabicVisible,
              isSelected: state.selectedAyahIds.contains(ayah.ayah.id),
              hasActiveSelection: hasActiveSelection,
              onToggleSelection: () => onToggleSelection(ayah.ayah.id),
              translations:
                  state.translationsByAyahId[ayah.ayah.id] ?? const {},
              translationBooks: state.translationBooks,
            ),
          ),
        };
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onShare,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(AppLocalizations.of(context).readerSelected(count)),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(AppLocalizations.of(context).quranClear),
              ),
              FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(AppLocalizations.of(context).readerShare),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
