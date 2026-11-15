import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_start.dart';
import 'package:tahfeez_ai/features/recitation/presentation/quick_start.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/domain/repositories/quran_repository.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../ai/matching/corpus_fixture.dart';
import 'live_recognition_controller_test.dart' show FakeRecognizer;
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

/// Where the next recitation starts (owner, 2026-11-14): a word tapped (not
/// during a session) — Recite from it, mid-ayah, the words before it kept
/// hidden; Listen, Loop and Follow along from its ayah, their own ranges
/// winning — the band on it before a session; another page turned to: the
/// page's first word again; a recitation ended on the page: the word after
/// the last recited; the reciter playing: no band, then the ayah after the
/// last played; the ayahs hidden: no band, then the word after those
/// uncovered; kept across restarts.
void main() {
  final corpus = loadTestCorpus();
  late FakeRecognizer recognizer;
  late ProviderContainer container;
  late _MemoryStorage storage;

  // Page 42 shows 2:253 – 2:256.
  final page42First = corpus.verseStartPosition((chapterNo: 2, verseNo: 253))!;
  final page42Last = corpus.verseEndPosition((chapterNo: 2, verseNo: 256))!;
  // Ayat al-Kursi (2:255) and a word in its middle.
  final kursiStart = corpus.verseStartPosition((chapterNo: 2, verseNo: 255))!;
  final kursiEnd = corpus.verseEndPosition((chapterNo: 2, verseNo: 255))!;
  final midKursi = kursiStart + 10;
  WordRef word(int position) => corpus.words[position].ref;

  HifzState hifz() => container.read(hifzControllerProvider);
  RecitationStart? start() => container.read(recitationStartProvider);
  RecitationSessionController session() =>
      container.read(recitationSessionControllerProvider.notifier);
  MushafWordOverlay? overlay() => container.read(mushafWordOverlayProvider);

  /// Recognizer-style text for corpus words [from]..[to].
  String spoken(int from, int to) =>
      [for (var p = from; p <= to; p++) corpus.words[p].key].join(' ');

  Future<void> recite(String text) async {
    final words = text.split(' ');
    for (var k = 1; k < words.length; k++) {
      recognizer.events_.add(LivePartialTranscript(words.take(k).join(' ')));
    }
    recognizer.events_.add(LiveFinalTranscript(text));
    await pumpEventQueue();
  }

  /// A fresh app over [storage]: page [page] on screen (42's words known).
  Future<void> open({int page = 42, bool hideMode = false}) async {
    recognizer = FakeRecognizer();
    container = ProviderContainer(
      overrides: [
        recitationAudioSourceFactoryProvider.overrideWithValue(
          FakeAudioSource.new,
        ),
        recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
        recitationSessionRepositoryProvider.overrideWithValue(FakeRepository()),
        liveQuranRecognizerFactoryProvider.overrideWithValue(() => recognizer),
        quranWordCorpusProvider.overrideWith((ref) async => corpus),
        browserStorageProvider.overrideWithValue(storage),
        hifzHapticsProvider.overrideWithValue(() {}),
        hifzBeepProvider.overrideWithValue(() {}),
        acousticVerificationControllerProvider.overrideWith(_Acoustic.new),
        quranRepositoryProvider.overrideWithValue(_Pages()),
        memorizationRecordDelayProvider.overrideWithValue(Duration.zero),
        memorizationRecorderProvider.overrideWithValue((_) async {}),
        quranAudioPlayerProvider.overrideWith(_Player.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(recitationStartProvider, (_, _) {});
    container.listen(liveRecognitionControllerProvider, (_, _) {});
    container.listen(hifzControllerProvider, (_, _) {});
    container.read(mushafPageVersesProvider.notifier).report(42, (
      first: (chapterNo: 2, verseNo: 253),
      last: (chapterNo: 2, verseNo: 256),
    ));
    container.read(mushafPageWordRangesProvider.notifier).report(42, (
      first: word(page42First),
      last: word(page42Last),
    ));
    container.read(mushafPageWordsProvider.notifier).report(42, [
      for (var p = page42First; p <= page42Last; p++) word(p),
    ]);
    final hide = container.read(mushafHideModeProvider.notifier)
      ..reportPageWords(42, wordCount: page42Last - page42First + 1);
    if (hideMode) {
      hide
        ..toggle()
        ..setRevealed({42: 0});
    }
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('screen', QuranLocation.page(1, page));
    await container.read(quranWordCorpusProvider.future);
    await pumpEventQueue();
  }

  Future<void> reciteOn42() async {
    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();
  }

  setUp(() => storage = _MemoryStorage());

  test('not loading the Quran\'s words itself (they slowed the app\'s first '
      'screens): only for the band with the ayahs hidden', () async {
    final c = ProviderContainer(
      overrides: [browserStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    c.listen(recitationStartProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.exists(quranWordCorpusProvider), isFalse);
    // A Mushaf open, the ayahs hidden: the band on the next word to
    // uncover, from the page's own words — the Quran's still not loaded.
    c.read(mushafPageWordRangesProvider.notifier).report(42, (
      first: word(page42First),
      last: word(page42Last),
    ));
    c.read(mushafPageWordsProvider.notifier).report(42, [
      for (var p = page42First; p <= page42Last; p++) word(p),
    ]);
    c.read(mushafHideModeProvider.notifier)
      ..reportPageWords(42, wordCount: page42Last - page42First + 1)
      ..toggle()
      ..revealNextWord(42);
    c
        .read(mushafRecitationTargetProvider.notifier)
        .show('screen', const QuranLocation.page(1, 42));
    await pumpEventQueue();
    expect(c.read(mushafWordOverlayProvider)!.marks, {
      word(page42First + 1): MushafWordMark.current,
    });
    expect(c.exists(quranWordCorpusProvider), isFalse);
  });

  test('a word tapped: the next start, its band drawn before any session; '
      'tapped again, none — the band on the page\'s first word', () async {
    await open();
    expect(start(), isNull);
    expect(overlay()!.marks, {
      word(page42First): MushafWordMark.current,
    }, reason: 'before a tap: the page\'s first word');
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    expect(start(), (page: 42, word: word(midKursi)));
    expect(overlay()!.marks[word(midKursi)], MushafWordMark.current);
    expect(overlay()!.isHidden(word(midKursi)), isFalse);

    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    expect(start(), isNull);
    expect(overlay()!.marks, {word(page42First): MushafWordMark.current});
  });

  test('Recite: from the word tapped, mid-ayah — the rest of the ayah '
      'recited from there is all correct', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await reciteOn42();
    expect(hifz().running, isTrue);
    // The band on it while the reciter is looked for.
    expect(overlay()!.marks, {word(midKursi): MushafWordMark.current});

    await recite(spoken(midKursi, kursiEnd));
    session().pause();
    await pumpEventQueue();
    // Every word from the tapped one on, right; none before it judged.
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    for (var p = midKursi; p <= kursiEnd; p++) {
      expect(marks[word(p)], MushafWordMark.correct, reason: '$p');
    }
    for (var p = kursiStart; p < midKursi; p++) {
      expect(marks[word(p)], isNull, reason: '$p');
    }
  });

  test('Recite begun before the word tapped (the ayahs shown): followed '
      'from where the reciter began', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await reciteOn42();
    await recite(spoken(kursiStart, midKursi + 3));
    session().pause();
    await pumpEventQueue();
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    // Judged from about where they began (located within a few words),
    // through the chosen word and on.
    for (var p = kursiStart + 4; p <= midKursi + 3; p++) {
      expect(marks[word(p)], MushafWordMark.correct, reason: '$p');
    }
  });

  test(
    'Recite begun before the word tapped, the ayahs hidden: followed '
    'from where the reciter began — the words before that still hidden',
    () async {
      await open(hideMode: true);
      container.read(recitationStartProvider.notifier).choose(word(midKursi));
      await reciteOn42();
      await recite(spoken(kursiStart, midKursi + 3));
      await pumpEventQueue();
      final shown = container.read(mushafWordOverlayProvider)!;
      for (var p = kursiStart + 2; p <= midKursi + 3; p++) {
        expect(shown.isHidden(word(p)), isFalse, reason: 'recited: $p');
      }
      expect(shown.isHidden(word(kursiStart - 1)), isTrue, reason: 'before');
      expect(hifz().expected, word(midKursi + 4));
    },
  );

  test('Recite with the ayahs hidden: from the word tapped, the words '
      'before it stay hidden', () async {
    await open(hideMode: true);
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await reciteOn42();
    final hide = container.read(mushafHideModeProvider);
    expect(hide.startOf(42), midKursi - page42First);
    expect(hifz().expected, word(midKursi));
    await recite(spoken(midKursi, midKursi + 4));
    await pumpEventQueue();
    final shown = container.read(mushafWordOverlayProvider)!;
    expect(shown.isHidden(word(midKursi - 1)), isTrue, reason: 'before it');
    expect(shown.isHidden(word(kursiStart)), isTrue, reason: "ayah's start");
    expect(shown.isHidden(word(midKursi)), isFalse, reason: 'recited');
  });

  test('a range of its own (Loop, Follow along, a test): its start wins over '
      'the word tapped', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    const ayah = (chapterNo: 2, verseNo: 256);
    container.read(hifzControllerProvider.notifier).setRange((
      from: ayah,
      to: ayah,
    ));
    await reciteOn42();
    expect(hifz().expected, word(corpus.verseStartPosition(ayah)!));
  });

  test('during a recitation a word tapped changes nothing', () async {
    await open();
    await reciteOn42();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    expect(start(), isNull);
  });

  test('another page turned to: the start goes (the page\'s first word, as '
      'before); kept on the phone gone too', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    container.read(mushafPageWordRangesProvider.notifier).report(43, (
      first: word(page42Last + 1),
      last: word(page42Last + 60),
    ));
    container.read(mushafPageWordsProvider.notifier).report(43, [
      for (var p = page42Last + 1; p <= page42Last + 60; p++) word(p),
    ]);
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('screen', const QuranLocation.page(1, 43));
    await pumpEventQueue();
    expect(start(), isNull);
    // The band on the new page's first word.
    expect(overlay()!.marks, {word(page42Last + 1): MushafWordMark.current});
    expect(storage.values['recitation.start.v1'], isNull);
  });

  test('a recitation ended on the page: the next start is the word after '
      'the last recited', () async {
    await open();
    await reciteOn42();
    // Located on the page (no start chosen): Ayat al-Kursi's first words.
    await recite(spoken(kursiStart, kursiStart + 5));
    await session().stop();
    await pumpEventQueue();
    expect(start(), (page: 42, word: word(kursiStart + 6)));
    expect(overlay()!.marks[word(kursiStart + 6)], MushafWordMark.current);
  });

  test('kept on the phone: the app opened again on its page, still there; '
      'on another page, gone', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();

    await open(); // the app again, page 42
    expect(start(), (page: 42, word: word(midKursi)));
    expect(overlay()!.marks[word(midKursi)], MushafWordMark.current);

    await open(page: 43); // the app again, another page
    expect(start(), isNull);
    expect(storage.values['recitation.start.v1'], isNull);
  });

  test('the reciter playing (Listen): no band; stopped, the band on the '
      'first word of the ayah after the last played', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    final player = container.read(quranAudioPlayerProvider.notifier) as _Player;
    container.listen(quranAudioPlayerProvider, (_, _) {});
    player.play(const NowPlaying.ayahs([2254, 2255], 0, null));
    await pumpEventQueue();
    expect(overlay(), isNull, reason: 'no band while it plays');
    player.play(const NowPlaying.ayahs([2254, 2255], 1, null));
    await pumpEventQueue();
    player.play(null); // stopped in Ayat al-Kursi
    await pumpEventQueue();
    expect(start(), (page: 42, word: word(kursiEnd + 1)));
    expect(overlay()!.marks[word(kursiEnd + 1)], MushafWordMark.current);
    // A word's own audio (its sheet): changes nothing.
    player.play(NowPlaying.word(2256, 3));
    await pumpEventQueue();
    player.play(null);
    await pumpEventQueue();
    expect(start(), (page: 42, word: word(kursiEnd + 1)));
  });

  test('the ayahs hidden: the band on the next word to uncover — the '
      'page\'s first, then the word after those uncovered', () async {
    await open();
    final hide = container.read(mushafHideModeProvider.notifier)..toggle();
    await pumpEventQueue();
    // (No word chosen.) The band on the page's first (hidden) word.
    expect(start(), isNull);
    expect(overlay()!.marks, {word(page42First): MushafWordMark.current});

    hide
      ..revealNextWord(42)
      ..revealNextWord(42);
    await pumpEventQueue();
    // Drawn there (not a start of its own: Recite starts there anyway).
    expect(overlay()!.marks, {word(page42First + 2): MushafWordMark.current});
    expect(start(), isNull);

    hide.hideLastWord(42);
    await pumpEventQueue();
    expect(overlay()!.marks, {word(page42First + 1): MushafWordMark.current});
    hide.hideLastWord(42);
    await pumpEventQueue();
    expect(overlay()!.marks, {word(page42First): MushafWordMark.current});

    // All uncovered: none.
    container.read(mushafHideModeProvider.notifier).setRevealed({
      42: page42Last - page42First + 1,
    });
    await pumpEventQueue();
    expect(overlay(), isNull);
  });

  test(
    'the ayahs hidden, a page uncovered to its end and the next turned '
    'to: the band on its first word (Al-Baqarah\'s after Al-Fatiha)',
    () async {
      await open(hideMode: true);
      final total = page42Last - page42First + 1;
      container.read(mushafHideModeProvider.notifier).setRevealed({42: total});
      await pumpEventQueue();
      expect(overlay(), isNull, reason: 'all uncovered');
      container.read(mushafPageWordRangesProvider.notifier).report(43, (
        first: word(page42Last + 1),
        last: word(page42Last + 60),
      ));
      container.read(mushafPageWordsProvider.notifier).report(43, [
        for (var p = page42Last + 1; p <= page42Last + 60; p++) word(p),
      ]);
      container
          .read(mushafHideModeProvider.notifier)
          .reportPageWords(43, wordCount: 60);
      container
          .read(mushafRecitationTargetProvider.notifier)
          .show('screen', const QuranLocation.page(1, 43));
      await pumpEventQueue();
      expect(overlay()!.marks, {word(page42Last + 1): MushafWordMark.current});
    },
  );

  for (final hidden in [false, true]) {
    test(
      'a recitation over (its colours still shown${hidden ? ', the ayahs '
                'hidden' : ''}), another page turned to: the band on its first word, '
      'the last recitation\'s band gone',
      () async {
        await open(hideMode: hidden);
        await reciteOn42();
        await recite(spoken(page42First, page42First + 5));
        await session().stop();
        await pumpEventQueue();
        container.read(mushafPageWordRangesProvider.notifier).report(43, (
          first: word(page42Last + 1),
          last: word(page42Last + 60),
        ));
        container.read(mushafPageWordsProvider.notifier).report(43, [
          for (var p = page42Last + 1; p <= page42Last + 60; p++) word(p),
        ]);
        container
            .read(mushafHideModeProvider.notifier)
            .reportPageWords(43, wordCount: 60);
        container
            .read(mushafRecitationTargetProvider.notifier)
            .show('screen', const QuranLocation.page(1, 43));
        await pumpEventQueue();
        final bands = {
          for (final e in overlay()!.marks.entries)
            if (e.value == MushafWordMark.current) e.key,
        };
        expect(bands, {word(page42Last + 1)});
      },
    );
  }

  test(
    'while a recitation runs: no band of the start\'s (its own only)',
    () async {
      await open();
      container.read(recitationStartProvider.notifier).choose(word(midKursi));
      await reciteOn42();
      await recite(spoken(midKursi, midKursi + 3));
      await pumpEventQueue();
      final bands = {
        for (final e in overlay()!.marks.entries)
          if (e.value == MushafWordMark.current) e.key,
      };
      expect(bands, hasLength(1));
      expect(bands, isNot(contains(word(midKursi))));
    },
  );

  for (final mark in [
    MushafWordMark.correct,
    MushafWordMark.wrong,
    MushafWordMark.skipped,
  ]) {
    test('a page recited before (its colours kept), its first word '
        '${mark.name}: the band around it, its own colour kept (owner, '
        '2026-11-14)', () async {
      await open();
      container
          .read(mushafWordOverlayProvider.notifier)
          .set(
            MushafWordOverlay(
              first: word(page42First),
              last: word(page42First + 10),
              marks: {
                for (var p = page42First; p <= page42First + 10; p++)
                  word(p): p == page42First ? mark : MushafWordMark.correct,
              },
              hideUnrevealed: false,
              followHideMode: true,
            ),
          );
      await pumpEventQueue();
      expect(overlay()!.marks[word(page42First)], mark, reason: 'its colour');
      expect(overlay()!.band, word(page42First), reason: 'the band too');
      expect(overlay()!.marks[word(page42First + 1)], MushafWordMark.correct);
      if (mark == MushafWordMark.wrong) {
        expect(markedMistakes(overlay()), contains(word(page42First)));
      }
      // A word without a colour: the band as its mark, as before.
      container
          .read(recitationStartProvider.notifier)
          .choose(word(page42First + 20));
      await pumpEventQueue();
      expect(overlay()!.marks[word(page42First + 20)], MushafWordMark.current);
      expect(overlay()!.band, isNull);
      expect(overlay()!.marks[word(page42First)], mark);
    });
  }

  test('a word chosen mid-page, then the ayahs hidden: the words before it '
      'shown, it and those after hidden — the band staying on it, Recite '
      'from it (owner, 2026-11-15)', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    container.read(mushafHideModeProvider.notifier).toggle();
    await pumpEventQueue();
    final hide = container.read(mushafHideModeProvider);
    final at = midKursi - page42First;
    expect(hide.revealedOn(42), at);
    expect(
      [
        for (var i = 0; i < at; i++)
          if (hide.isWordHidden(42, i)) i,
      ],
      isEmpty,
      reason: 'the words before it shown',
    );
    expect(hide.isWordHidden(42, at), isTrue, reason: 'it hidden');
    expect(hide.isWordHidden(42, at + 5), isTrue, reason: 'after it hidden');
    expect(overlay()!.marks, {word(midKursi): MushafWordMark.current});
    await reciteOn42();
    expect(hifz().expected, word(midKursi));
  });

  test('a word chosen, the ayahs hidden, words uncovered by hand: the band '
      'stays on the word chosen; Recite from it, the words before it shown '
      'still (owner, 2026-11-15)', () async {
    await open();
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    await pumpEventQueue();
    final hide = container.read(mushafHideModeProvider.notifier)..toggle();
    await pumpEventQueue();
    hide
      ..revealNextWord(42)
      ..revealNextWord(42);
    await pumpEventQueue();
    expect(start(), (page: 42, word: word(midKursi)));
    expect(
      overlay()!.marks[word(midKursi)],
      MushafWordMark.current,
      reason: 'the band where it was',
    );
    expect(overlay()!.marks[word(midKursi + 2)], isNot(MushafWordMark.current));

    await reciteOn42();
    expect(hifz().expected, word(midKursi));
    final shown = container.read(mushafWordOverlayProvider)!;
    expect(shown.isHidden(word(kursiStart)), isFalse, reason: 'before: shown');
    expect(shown.isHidden(word(midKursi - 1)), isFalse);
    expect(shown.isHidden(word(midKursi + 3)), isTrue, reason: 'after: hidden');
  });

  testWidgets('Listen, Loop and Follow along: from the start of the tapped '
      'word\'s ayah — their menus\' own "from" as before', (tester) async {
    await tester.runAsync(open);
    container.read(mushafPageVersesProvider.notifier).report(42, (
      first: (chapterNo: 2, verseNo: 253),
      last: (chapterNo: 2, verseNo: 256),
    ));
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(quickStartFrom(widgetRef), (chapterNo: 2, verseNo: 253));
    container.read(recitationStartProvider.notifier).choose(word(midKursi));
    expect(quickStartFrom(widgetRef), (chapterNo: 2, verseNo: 255));
    expect(quickStartFrom(widgetRef, chosenWord: false), (
      chapterNo: 2,
      verseNo: 253,
    ));
  });
}

class _MemoryStorage implements BrowserStorage {
  final values = <String, Object?>{};
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _Pages implements QuranRepository {
  @override
  Future<int?> getPageForAyah({
    required int mushafId,
    required int ayahId,
  }) async => 42;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends QuranAudioPlayer {
  @override
  NowPlaying? build() {
    shareReciterAyah();
    return null;
  }

  void play(NowPlaying? now) => state = now;
}

class _Acoustic extends AcousticVerificationController {
  @override
  AcousticVerificationState build() => const AcousticVerificationState();
}
