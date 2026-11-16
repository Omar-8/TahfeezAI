import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../listen/application/quran_audio_player.dart';
import '../../../quran/domain/quran_ayah_numbers.dart' show surahAyahCounts;
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import 'mushaf_recitation_target.dart';
import 'recitation_position.dart';
import 'recitation_session_controller.dart';

const _key = 'recitation.start.v1';

/// Where the next recitation starts on the page on screen: a word, and the
/// page it is on. Drawn as the current word's blue band before a session.
typedef RecitationStart = ({int page, WordRef word});

/// The word the next recitation starts from (owner, 2026-11-14):
///
/// - a word tapped on the page (its word sheet opens as before) — not
///   while a recitation runs or the reciter plays; tapped again, none;
/// - Recite starts at it, mid-ayah too (with the ayahs hidden, the words
///   before it stay hidden); Listen, Loop and Follow along at the start of
///   its ayah — their menus' own ranges win;
/// - a recitation ended on the page: the word after the last one recited;
/// - the reciter (Listen) playing: not drawn; stopped, the first word of
///   the ayah after the last one played, where it is on screen;
/// - the ayahs hidden (or words uncovered or covered by hand): none of
///   its own — the band on the next word to uncover;
/// - another page turned to: none — the band on the page's first word
///   (as on any page with none chosen);
/// - kept on the phone: the Mushaf (or the app) opened again on its page,
///   it is still there.
class RecitationStartController extends Notifier<RecitationStart?> {
  /// The next word to recite while a recitation runs (the band's word).
  WordRef? _nextWord;

  /// The ayah the reciter is on, while Listen (or Follow along's
  /// reciter) plays ayahs: the band not drawn meanwhile.
  int? _playingAyah;

  @override
  RecitationStart? build() {
    ref.listen(mushafRecitationTargetProvider.select((t) => t?.location), (
      _,
      location,
    ) {
      _onScreen(location);
      _drawCursor();
    });
    // The page's words known (a page turned to, loaded): its band.
    ref.listen(mushafPageWordRangesProvider, (_, _) => _drawCursor());
    // A page's words reported (the next to uncover, with the ayahs hidden
    // — from the page's own words, not the whole Quran's: loading those
    // slowed the app — owner, 2026-11-14).
    ref.listen(mushafPageWordsProvider, (_, _) => _drawCursor());
    // (The reciter's position, as the recitation shares it — not the
    // recitation's own state: it reads this start.)
    ref.listen(recitationPositionProvider, (_, next) {
      if (next != null &&
          ref.read(recitationSessionControllerProvider).isActive) {
        _nextWord = next;
      }
    });
    ref.listen(recitationSessionControllerProvider.select((s) => s.isActive), (
      was,
      active,
    ) {
      _drawCursor();
      if (active) return;
      if (was ?? false) _sessionEnded();
    });
    // (The player's ayah, as it shares it — not the player: building it
    // starts the audio.)
    ref.listen(reciterAyahProvider, (_, ayah) {
      final stopped = _playingAyah;
      _playingAyah = ayah;
      if (ayah == null && stopped != null) _listenEnded(stopped);
      _drawCursor();
    });
    ref.listen(mushafHideModeProvider, _onHideMode);
    // The band before a session: drawn by the overlay while none runs.
    listenSelf((_, _) => _drawCursor());
    unawaited(_restore());
    return null;
  }

  void _drawCursor() {
    Future.microtask(() {
      if (!ref.mounted) return;
      ref
          .read(mushafWordOverlayProvider.notifier)
          .setCursor(
            // (A recitation running: its own band, not this.)
            _playingAyah != null ||
                    ref.read(recitationSessionControllerProvider).isActive
                ? null
                : state?.word ?? _pageCursor(),
          );
    });
  }

  /// Listen stopped at [ayahId]: the ayah after it, from its first word —
  /// where it is on screen.
  void _listenEnded(int ayahId) {
    if (ref.read(recitationSessionControllerProvider).isActive) return;
    final surah = ayahId ~/ 1000, verse = ayahId % 1000;
    if (surah < 1 || surah > 114) return;
    final int next;
    if (verse < surahAyahCounts[surah - 1]) {
      next = ayahId + 1;
    } else if (surah < 114) {
      next = (surah + 1) * 1000 + 1;
    } else {
      return;
    }
    final word = (ayahId: next, wordIndex: 0);
    final page = _pageOf(word);
    final pages = _visiblePages();
    if (page == null || pages == null || !pages.contains(page)) {
      _set(null);
      return;
    }
    _set((page: page, word: word));
  }

  /// The ayahs hidden or words uncovered by hand (not by a recitation or
  /// the reciter): a word chosen stays chosen, the band on it (owner,
  /// 2026-11-15: uncovering words moved it); none chosen, the band on the
  /// next word to uncover.
  void _onHideMode(MushafHideModeState? was, MushafHideModeState now) {
    if (now.enabled &&
        !ref.read(recitationSessionControllerProvider).isActive &&
        _playingAyah == null) {
      final pages = _visiblePages();
      final start = state;
      // Turned on with a word chosen on the page: the words before it
      // left shown (what comes before, to read), it and those after it
      // hidden — the band staying on it, the next word to uncover (owner,
      // 2026-11-15).
      if (pages != null &&
          (was == null || !was.enabled) &&
          start != null &&
          pages.contains(start.page)) {
        final words = ref.read(mushafPageWordsProvider)[start.page];
        final at = words?.indexOf(start.word) ?? -1;
        if (at > 0) {
          final reveal = {
            // (A spread's page before it: all shown.)
            for (final p in pages)
              if (p < start.page) p: now.wordCounts[p] ?? 0,
            start.page: at,
          };
          Future.microtask(() {
            if (!ref.mounted) return;
            ref.read(mushafHideModeProvider.notifier).setRevealed(reveal);
          });
        }
      }
    }
    _drawCursor();
  }

  /// No word chosen: the band on the first word of the page on screen —
  /// with the ayahs hidden, on the next word to uncover (the page's first,
  /// none uncovered yet; on the facing or next page, this one all
  /// uncovered); `null` when all is uncovered, or off the Mushaf.
  WordRef? _pageCursor() {
    final hide = ref.read(mushafHideModeProvider);
    final pages = _visiblePages();
    if (pages == null) return null;
    if (!hide.enabled) {
      return ref.read(mushafPageWordRangesProvider)[pages.reduce(min)]?.first;
    }
    for (final page in pages.toList()..sort()) {
      final shown = hide.revealedOn(page);
      final total = hide.wordCounts[page];
      if (total != null && shown >= total) continue;
      final words = ref.read(mushafPageWordsProvider)[page];
      if (words == null || shown >= words.length) return null;
      return words[shown];
    }
    return null;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getString(_key);
    if (stored == null || !ref.mounted || state != null) return;
    try {
      final json = jsonDecode(stored) as Map<String, Object?>;
      final restored = (
        page: json['page']! as int,
        word: (
          ayahId: json['ayahId']! as int,
          wordIndex: json['wordIndex']! as int,
        ),
      );
      // Opened on another page meanwhile: not that one's.
      final pages = _visiblePages();
      if (pages != null && !pages.contains(restored.page)) {
        unawaited(_save(null));
        return;
      }
      state = restored;
    } on Object {
      unawaited(_save(null));
    }
  }

  /// The page(s) on screen (both of a spread), or `null` when no Mushaf is.
  Set<int>? _visiblePages() {
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return null;
    final spread = ref.read(fullBleedContentProvider);
    final first = firstVisiblePage(location.pageNumber, spread: spread);
    return {first, if (spread) first + 1};
  }

  /// The page [word] is on, among those reported.
  int? _pageOf(WordRef word) {
    for (final MapEntry(key: page, value: range)
        in ref.read(mushafPageWordRangesProvider).entries) {
      if (compareWordRefs(word, range.first) >= 0 &&
          compareWordRefs(word, range.last) <= 0) {
        return page;
      }
    }
    return null;
  }

  /// A page turned to: a start on a page no longer shown goes. (The Mushaf
  /// closed: kept, for when it opens again.)
  void _onScreen(QuranLocation? location) {
    final start = state;
    if (start == null || location is! QuranLocationPage) return;
    final pages = _visiblePages();
    if (pages != null && !pages.contains(start.page)) _set(null);
  }

  /// A recitation over: the next word to recite, where it is on screen.
  void _sessionEnded() {
    final word = _nextWord;
    _nextWord = null;
    if (word == null) return;
    final page = _pageOf(word);
    final pages = _visiblePages();
    if (page == null || pages == null || !pages.contains(page)) return;
    _set((page: page, word: word));
  }

  /// [word], tapped on the page: the next recitation's start — or, tapped
  /// again, none. Not while a recitation runs or the reciter plays.
  void choose(WordRef word) {
    if (ref.read(recitationSessionControllerProvider).isActive) return;
    // (A word's own sound playing, from its pill or sheet, is no reciter.)
    if (ref.read(quranAudioPlayerProvider) case final p? when !p.isWord) {
      return;
    }
    final page = _pageOf(word);
    final pages = _visiblePages();
    if (page == null || pages == null || !pages.contains(page)) return;
    if (state?.word == word) {
      _set(null);
    } else {
      _set((page: page, word: word));
    }
  }

  /// No chosen start (the page's first word, as before).
  void clear() => _set(null);

  void _set(RecitationStart? start) {
    if (state == start) return;
    state = start;
    unawaited(_save(start));
  }

  Future<void> _save(RecitationStart? start) {
    final storage = ref.read(browserStorageProvider);
    if (start == null) return storage.remove(_key);
    return storage.setString(
      _key,
      jsonEncode({
        'page': start.page,
        'ayahId': start.word.ayahId,
        'wordIndex': start.word.wordIndex,
      }),
    );
  }
}

final recitationStartProvider =
    NotifierProvider<RecitationStartController, RecitationStart?>(
      RecitationStartController.new,
    );
