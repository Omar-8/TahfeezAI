import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/translation_selection_controller.dart';
import '../../../quran/domain/models/navigation_models.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/translation_models.dart';
import '../../../quran/domain/repositories/quran_repository.dart';
import '../../../quran/domain/repositories/translation_repository.dart';
import '../../../quran/quran_providers.dart';
import '../../../quran/translation_providers.dart';
import '../domain/reader_layout_item.dart';
import 'reader_preferences_controller.dart';

part 'reader_session_controller.g.dart';

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
    this.translationsByAyahId = const {},
    this.translationBooks = const {},
  });

  final List<ReaderLayoutItem> items;
  final bool canLoadMore;

  /// The ayah id to scroll to once this state's `items` are first laid out
  /// — set on the initial load (from the requested [QuranLocation]) and
  /// cleared after the reader screen consumes it, so it never re-fires on
  /// an unrelated rebuild.
  final int? scrollToAyahId;

  final Set<int> selectedAyahIds;

  /// Every active translation's text for every loaded verse, keyed by
  /// ayahId then slug — batch-loaded per chapter segment alongside
  /// [items] (Milestone 9), never fetched per verse by a widget.
  final Map<int, Map<String, TranslationVerseText>> translationsByAyahId;

  /// Metadata (author, display name) for every currently active,
  /// installed translation — resolved once per session build/extension so
  /// `VerseBlock` never has to look up a book's author itself.
  final Map<String, TranslationBook> translationBooks;

  ReaderSessionState copyWith({
    List<ReaderLayoutItem>? items,
    bool? canLoadMore,
    int? scrollToAyahId,
    bool clearScrollTarget = false,
    Set<int>? selectedAyahIds,
    Map<int, Map<String, TranslationVerseText>>? translationsByAyahId,
    Map<String, TranslationBook>? translationBooks,
  }) {
    return ReaderSessionState(
      items: items ?? this.items,
      canLoadMore: canLoadMore ?? this.canLoadMore,
      scrollToAyahId: clearScrollTarget
          ? null
          : (scrollToAyahId ?? this.scrollToAyahId),
      selectedAyahIds: selectedAyahIds ?? this.selectedAyahIds,
      translationsByAyahId: translationsByAyahId ?? this.translationsByAyahId,
      translationBooks: translationBooks ?? this.translationBooks,
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
/// Every load goes through [QuranRepository.getVerseRangeWithWords] and
/// [TranslationRepository.getVerseRangeText], which batch a whole verse
/// range into a small, fixed number of queries (`docs/ARCHITECTURE.md`
/// §4a) — this controller never queries per verse or per word, for
/// canonical text or for translations.
@riverpod
class ReaderSession extends _$ReaderSession {
  int _nextSurahNo = 1;
  late String _scriptCode;
  late List<String> _activeTranslationSlugs;

  @override
  Future<ReaderSessionState> build(QuranLocation location) async {
    final repository = ref.watch(quranRepositoryProvider);
    final translationRepository = ref.watch(translationRepositoryProvider);
    _scriptCode = ref.watch(quranScriptCodeProvider);
    _activeTranslationSlugs = ref.watch(translationSelectionControllerProvider);

    final items = <ReaderLayoutItem>[];
    final translationsByAyahId = <int, Map<String, TranslationVerseText>>{};
    int? scrollTarget;

    switch (location) {
      case QuranLocationSurah(:final surahNo):
        scrollTarget = await _appendChapter(
          repository,
          translationRepository,
          items,
          translationsByAyahId,
          surahNo: surahNo,
          isSessionStart: true,
        );
        _nextSurahNo = surahNo + 1;

      case QuranLocationAyah(:final chapterNo, :final verseNo):
        await _appendChapter(
          repository,
          translationRepository,
          items,
          translationsByAyahId,
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
            translationRepository,
            items,
            translationsByAyahId,
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
          scrollTarget = await _appendRanges(
            repository,
            translationRepository,
            items,
            translationsByAyahId,
            juz.ranges,
          );
          _nextSurahNo = juz.ranges.isEmpty ? 1 : juz.ranges.last.surahNo + 1;
        }

      case QuranLocationHizb(:final hizbNo):
        final hizb = await repository.getHizb(hizbNo);
        if (hizb != null) {
          scrollTarget = await _appendRanges(
            repository,
            translationRepository,
            items,
            translationsByAyahId,
            hizb.ranges,
          );
          _nextSurahNo = hizb.ranges.isEmpty ? 1 : hizb.ranges.last.surahNo + 1;
        }

      case QuranLocationPage():
        // Mushaf paging is Milestone 7's job; the routing layer never
        // sends a page location to this controller (see
        // `core/routing/quran_location_routing.dart`).
        break;
    }

    final translationBooks = <String, TranslationBook>{};
    for (final slug in _activeTranslationSlugs) {
      final book = await translationRepository.getInstalledTranslation(slug);
      if (book != null) translationBooks[slug] = book;
    }

    return ReaderSessionState(
      items: items,
      canLoadMore: _nextSurahNo <= repository.chapterCount,
      scrollToAyahId: scrollTarget,
      translationsByAyahId: translationsByAyahId,
      translationBooks: translationBooks,
    );
  }

  /// Appends the next chapter's content — the mechanism both the initial
  /// full-Surah/Ayah load and continuous-scroll extension share.
  Future<int?> _appendChapter(
    QuranRepository repository,
    TranslationRepository translationRepository,
    List<ReaderLayoutItem> items,
    Map<int, Map<String, TranslationVerseText>> translationsByAyahId, {
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
      translationRepository,
      items,
      translationsByAyahId,
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
    TranslationRepository translationRepository,
    List<ReaderLayoutItem> items,
    Map<int, Map<String, TranslationVerseText>> translationsByAyahId,
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
        translationRepository,
        items,
        translationsByAyahId,
        chapterNo: range.surahNo,
        fromVerseNo: range.startAyahNo,
        toVerseNo: range.endAyahNo,
      );
      scrollTarget ??= range.surahNo * 1000 + range.startAyahNo;
    }
    return scrollTarget;
  }

  /// The one place that actually calls the batched repository methods and
  /// inserts Ruku [ReaderSectionMarkerItem]s at Ruku boundaries within the
  /// loaded range. Loads canonical words and every active translation's
  /// text for the same range in the same small number of queries each.
  Future<void> _appendVerseRange(
    QuranRepository repository,
    TranslationRepository translationRepository,
    List<ReaderLayoutItem> items,
    Map<int, Map<String, TranslationVerseText>> translationsByAyahId, {
    required int chapterNo,
    required int fromVerseNo,
    required int toVerseNo,
  }) async {
    final range = (
      chapterNo: chapterNo,
      fromVerseNo: fromVerseNo,
      toVerseNo: toVerseNo,
    );
    final verses = await repository.getVerseRangeWithWords(
      range,
      scriptCode: _scriptCode,
    );

    for (final slug in _activeTranslationSlugs) {
      final texts = await translationRepository.getVerseRangeText(
        range,
        slug: slug,
      );
      for (final text in texts) {
        final ayahId = chapterNo * 1000 + text.verseNo;
        translationsByAyahId.putIfAbsent(ayahId, () => {})[slug] = text;
      }
    }

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
      final translationRepository = ref.read(translationRepositoryProvider);
      final items = <ReaderLayoutItem>[...current.items];
      final translationsByAyahId = {
        for (final entry in current.translationsByAyahId.entries)
          entry.key: {...entry.value},
      };
      await _appendChapter(
        repository,
        translationRepository,
        items,
        translationsByAyahId,
        surahNo: _nextSurahNo,
        isSessionStart: false,
      );
      _nextSurahNo++;

      state = AsyncData(
        current.copyWith(
          items: items,
          canLoadMore: _nextSurahNo <= repository.chapterCount,
          clearScrollTarget: true,
          translationsByAyahId: translationsByAyahId,
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
