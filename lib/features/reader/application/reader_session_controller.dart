import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/domain/models/navigation_models.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/domain/repositories/quran_repository.dart';
import '../../../quran/quran_providers.dart';
import '../domain/reader_layout_item.dart';
import 'reader_preferences_controller.dart';

part 'reader_session_controller.g.dart';

/// The script every reading session renders words in.
///
/// A placeholder default, exactly like
/// `lib/features/quran/application/quran_index_providers.dart`'s
/// `defaultQuranScriptCode` — no script-selection preference exists yet
/// (Settings/Localization is Milestone 14).
const defaultReaderScriptCode = 'uthmani';

/// A provider (rather than [ReaderSession] reading [defaultReaderScriptCode]
/// directly) so tests can override which script a reading session loads —
/// necessary because [QuranRepository.getVerseRangeWithWords] returns zero
/// verses outright for a script code that matches no installed
/// `QuranScript` row (not "verses with empty words"), so a fixture using a
/// different script code than the production default would otherwise make
/// every reader test see an empty chapter regardless of what data actually
/// exists.
@riverpod
String readerScriptCode(Ref ref) => defaultReaderScriptCode;

/// The immutable content plus the reader's own transient UI state for one
/// reading session — selection, the verse to scroll to once the first
/// frame after a (re)load is built, and whether more content can still be
/// appended.
class ReaderSessionState {
  const ReaderSessionState({
    required this.items,
    required this.canLoadMore,
    this.scrollToAyahId,
    this.selectedAyahIds = const {},
  });

  final List<ReaderLayoutItem> items;
  final bool canLoadMore;

  /// The ayah id to scroll to once this state's `items` are first laid out
  /// — set on the initial load (from the requested [QuranLocation]) and
  /// cleared after the reader screen consumes it, so it never re-fires on
  /// an unrelated rebuild.
  final int? scrollToAyahId;

  final Set<int> selectedAyahIds;

  ReaderSessionState copyWith({
    List<ReaderLayoutItem>? items,
    bool? canLoadMore,
    int? scrollToAyahId,
    bool clearScrollTarget = false,
    Set<int>? selectedAyahIds,
  }) {
    return ReaderSessionState(
      items: items ?? this.items,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      scrollToAyahId: clearScrollTarget
          ? null
          : (scrollToAyahId ?? this.scrollToAyahId),
      selectedAyahIds: selectedAyahIds ?? this.selectedAyahIds,
    );
  }
}

/// Builds and extends the flat [ReaderLayoutItem] list for one reading
/// session, keyed by the [QuranLocation] it was opened with (a `family`
/// provider — a fresh session per distinct location).
///
/// Every reading mode this milestone requires (full Surah, verse range,
/// individual Ayah, Juz, Hizb) is a different *starting selection* over the
/// same batched-loading machinery, and "continuous scrolling" is a
/// property of what happens when a session's initial content is
/// exhausted — `loadMore()` — rather than a separate mode, per this
/// milestone's [ContinuousScrollingPreferenceController] doc comment.
///
/// Every load goes through [QuranRepository.getVerseRangeWithWords], which
/// batches a whole verse range into a small, fixed number of queries
/// (`docs/ARCHITECTURE.md` §4a) — this controller never queries per verse
/// or per word.
@riverpod
class ReaderSession extends _$ReaderSession {
  int _nextSurahNo = 1;
  late String _scriptCode;

  @override
  Future<ReaderSessionState> build(QuranLocation location) async {
    final repository = ref.watch(quranRepositoryProvider);
    _scriptCode = ref.watch(readerScriptCodeProvider);

    final items = <ReaderLayoutItem>[];
    int? scrollTarget;

    switch (location) {
      case QuranLocationSurah(:final surahNo):
        scrollTarget = await _appendChapter(
          repository,
          items,
          surahNo: surahNo,
          isSessionStart: true,
        );
        _nextSurahNo = surahNo + 1;

      case QuranLocationAyah(:final chapterNo, :final verseNo):
        await _appendChapter(
          repository,
          items,
          surahNo: chapterNo,
          isSessionStart: true,
        );
        scrollTarget = chapterNo * 1000 + verseNo;
        _nextSurahNo = chapterNo + 1;

      case QuranLocationAyahRange(
        :final chapterNo,
        :final fromVerseNo,
        :final toVerseNo,
      ):
        final surah = await repository.getSurah(chapterNo);
        if (surah != null) {
          items.add(ReaderLayoutItem.chapterInfo(surah: surah));
          await _appendVerseRange(
            repository,
            items,
            chapterNo: chapterNo,
            fromVerseNo: fromVerseNo,
            toVerseNo: toVerseNo,
          );
          scrollTarget = chapterNo * 1000 + fromVerseNo;
        }
        _nextSurahNo = chapterNo + 1;

      case QuranLocationJuz(:final juzNo):
        final juz = await repository.getJuz(juzNo);
        if (juz != null) {
          scrollTarget = await _appendRanges(repository, items, juz.ranges);
          _nextSurahNo = juz.ranges.isEmpty ? 1 : juz.ranges.last.surahNo + 1;
        }

      case QuranLocationHizb(:final hizbNo):
        final hizb = await repository.getHizb(hizbNo);
        if (hizb != null) {
          scrollTarget = await _appendRanges(repository, items, hizb.ranges);
          _nextSurahNo = hizb.ranges.isEmpty ? 1 : hizb.ranges.last.surahNo + 1;
        }

      case QuranLocationPage():
        // Mushaf paging is Milestone 7's job; the routing layer never
        // sends a page location to this controller (see
        // `core/routing/quran_location_routing.dart`).
        break;
    }

    return ReaderSessionState(
      items: items,
      canLoadMore: _nextSurahNo <= repository.chapterCount,
      scrollToAyahId: scrollTarget,
    );
  }

  /// Appends the next chapter's content — the mechanism both the initial
  /// full-Surah/Ayah load and continuous-scroll extension share.
  Future<int?> _appendChapter(
    QuranRepository repository,
    List<ReaderLayoutItem> items, {
    required int surahNo,
    required bool isSessionStart,
  }) async {
    final surah = await repository.getSurah(surahNo);
    if (surah == null) return null;

    if (isSessionStart) {
      items.add(ReaderLayoutItem.chapterInfo(surah: surah));
    } else {
      items.add(ReaderLayoutItem.chapterTitle(surahNo: surahNo));
    }
    if (_needsBismillah(surahNo)) {
      items.add(const ReaderLayoutItem.bismillah());
    }
    await _appendVerseRange(
      repository,
      items,
      chapterNo: surahNo,
      fromVerseNo: 1,
      toVerseNo: surah.ayahCount,
    );
    return surahNo * 1000 + 1;
  }

  /// Appends every chapter segment a Juz/Hizb spans, in order, inserting a
  /// chapter marker (and Bismillah where appropriate) at each boundary.
  Future<int?> _appendRanges(
    QuranRepository repository,
    List<ReaderLayoutItem> items,
    List<NavigationRange> ranges,
  ) async {
    if (ranges.isEmpty) return null;
    int? scrollTarget;
    for (var i = 0; i < ranges.length; i++) {
      final range = ranges[i];
      final surah = await repository.getSurah(range.surahNo);
      if (surah == null) continue;

      items.add(
        i == 0
            ? ReaderLayoutItem.chapterInfo(surah: surah)
            : ReaderLayoutItem.chapterTitle(surahNo: range.surahNo),
      );
      if (range.startAyahNo == 1 && _needsBismillah(range.surahNo)) {
        items.add(const ReaderLayoutItem.bismillah());
      }
      await _appendVerseRange(
        repository,
        items,
        chapterNo: range.surahNo,
        fromVerseNo: range.startAyahNo,
        toVerseNo: range.endAyahNo,
      );
      scrollTarget ??= range.surahNo * 1000 + range.startAyahNo;
    }
    return scrollTarget;
  }

  /// The one place that actually calls the batched repository method and
  /// inserts Ruku [ReaderSectionMarkerItem]s at Ruku boundaries within the
  /// loaded range.
  Future<void> _appendVerseRange(
    QuranRepository repository,
    List<ReaderLayoutItem> items, {
    required int chapterNo,
    required int fromVerseNo,
    required int toVerseNo,
  }) async {
    final verses = await repository.getVerseRangeWithWords((
      chapterNo: chapterNo,
      fromVerseNo: fromVerseNo,
      toVerseNo: toVerseNo,
    ), scriptCode: _scriptCode);
    int? previousRukuNo;
    for (final verse in verses) {
      if (previousRukuNo != null && verse.ayah.rukuNo != previousRukuNo) {
        items.add(
          ReaderLayoutItem.sectionMarker(label: 'Ruku ${verse.ayah.rukuNo}'),
        );
      }
      previousRukuNo = verse.ayah.rukuNo;
      items.add(ReaderLayoutItem.verse(verse));
    }
  }

  bool _needsBismillah(int surahNo) => surahNo != 1 && surahNo != 9;

  bool _isLoadingMore = false;

  /// Appends the next chapter, for continuous scrolling. A no-op once
  /// [ReaderSessionState.canLoadMore] is `false`, and guarded against
  /// re-entrancy so a fast scroll-driven caller can't trigger the same
  /// chapter twice while the first call is still in flight.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.canLoadMore || _isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final repository = ref.read(quranRepositoryProvider);
      final items = <ReaderLayoutItem>[...current.items];
      await _appendChapter(
        repository,
        items,
        surahNo: _nextSurahNo,
        isSessionStart: false,
      );
      _nextSurahNo++;

      state = AsyncData(
        current.copyWith(
          items: items,
          canLoadMore: _nextSurahNo <= repository.chapterCount,
          clearScrollTarget: true,
        ),
      );
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Marks [scrollToAyahId] as consumed, so it does not re-trigger a scroll
  /// on a later, unrelated rebuild.
  void consumeScrollTarget() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearScrollTarget: true));
  }

  void toggleSelection(int ayahId) {
    final current = state.value;
    if (current == null) return;
    final selected = {...current.selectedAyahIds};
    if (!selected.remove(ayahId)) {
      selected.add(ayahId);
    }
    state = AsyncData(current.copyWith(selectedAyahIds: selected));
  }

  void clearSelection() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedAyahIds: const {}));
  }
}

/// The chapter's localization, for [ReaderChapterInfoItem]'s card — loaded
/// on demand per chapter shown (small, fixed number of chapters per
/// session) rather than batched, since the reader's chapter-info cards
/// need at most a handful of lookups even for a full Juz/Hizb session.
@riverpod
Future<SurahLocalization?> readerChapterLocalization(
  Ref ref,
  int surahNo, {
  required String languageCode,
}) {
  final repository = ref.watch(quranRepositoryProvider);
  return repository.getSurahLocalization(surahNo, languageCode: languageCode);
}
