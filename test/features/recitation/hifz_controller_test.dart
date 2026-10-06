import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_turn.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import '../../ai/matching/corpus_fixture.dart';
import '../../ai/matching/quran_stream_matcher_cases_test.dart' show kursi;
import 'live_recognition_controller_test.dart' show FakeRecognizer;
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

class _MemoryStorage implements BrowserStorage {
  final values = <String, Object>{};
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

void main() {
  final corpus = loadTestCorpus();
  late FakeRecognizer recognizer;
  late ProviderContainer container;
  late ProviderSubscription<HifzState> hifzListener;
  late int vibrations;
  late int beeps;

  HifzState hifz() => container.read(hifzControllerProvider);
  RecitationSessionController session() =>
      container.read(recitationSessionControllerProvider.notifier);

  /// Recognizer-style text for [chapter]:[verse] (its canonical words'
  /// match keys — what a recognizer writes for a perfect recitation).
  String spoken(int chapter, int verse) {
    final v = (chapterNo: chapter, verseNo: verse);
    return [
      for (
        var p = corpus.verseStartPosition(v)!;
        p <= corpus.verseEndPosition(v)!;
        p++
      )
        corpus.words[p].key,
    ].join(' ');
  }

  /// Streams [text] word by word, then as a final.
  Future<void> recite(String text) async {
    final words = text.split(' ');
    for (var k = 1; k < words.length; k++) {
      recognizer.events_.add(LivePartialTranscript(words.take(k).join(' ')));
    }
    recognizer.events_.add(LiveFinalTranscript(text));
    await pumpEventQueue();
  }

  // Page 42 shows 2:253 – 2:256.
  final page42First = corpus.verseStartPosition((chapterNo: 2, verseNo: 253))!;
  final page42Last = corpus.verseEndPosition((chapterNo: 2, verseNo: 256))!;

  Future<void> setUpHifz({
    ({int chapterNo, int verseNo})? from,
    ({int chapterNo, int verseNo})? to,
    bool strict = true,
    bool hideMode = true,
    int revealedOnPage = 0,
  }) async {
    recognizer = FakeRecognizer();
    vibrations = 0;
    beeps = 0;
    container = ProviderContainer(
      overrides: [
        recitationAudioSourceFactoryProvider.overrideWithValue(
          FakeAudioSource.new,
        ),
        recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
        recitationSessionRepositoryProvider.overrideWithValue(FakeRepository()),
        liveQuranRecognizerFactoryProvider.overrideWithValue(() => recognizer),
        quranWordCorpusProvider.overrideWith((ref) async => corpus),
        browserStorageProvider.overrideWithValue(_MemoryStorage()),
        hifzHapticsProvider.overrideWithValue(() => vibrations++),
        hifzBeepProvider.overrideWithValue(() => beeps++),
        acousticVerificationControllerProvider.overrideWith(_Acoustic.new),
      ],
    );
    addTearDown(container.dispose);
    // Page 42 (2:253–2:256) is on screen.
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('screen', const QuranLocation.page(1, 42));
    container.read(mushafPageVersesProvider.notifier).report(42, (
      first: (chapterNo: 2, verseNo: 253),
      last: (chapterNo: 2, verseNo: 256),
    ));
    container.read(mushafPageWordRangesProvider.notifier).report(42, (
      first: corpus.words[page42First].ref,
      last: corpus.words[page42Last].ref,
    ));
    final hide = container.read(mushafHideModeProvider.notifier)
      ..reportPageWords(42, wordCount: page42Last - page42First + 1);
    if (hideMode) {
      hide
        ..toggle()
        ..setRevealed({42: revealedOnPage});
    }
    container.listen(liveRecognitionControllerProvider, (_, _) {});
    hifzListener = container.listen(hifzControllerProvider, (_, _) {});
    await container.read(quranWordCorpusProvider.future);
    final settings = container.read(hifzSettingsProvider.notifier);
    settings.update(
      container.read(hifzSettingsProvider).copyWith(strict: strict),
    );
    // No switch: every recitation session is a Hifz test.
    if (from != null && to != null) {
      container.read(hifzControllerProvider.notifier).setRange((
        from: from,
        to: to,
      ));
    }
    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();
  }

  test(
    'session start hides the range; correct recitation reveals it all',
    () async {
      const kursiVerse = (chapterNo: 2, verseNo: 255);
      await setUpHifz(from: kursiVerse, to: kursiVerse);
      expect(hifz().running, isTrue);
      final overlay = container.read(mushafWordOverlayProvider)!;
      final firstWord =
          corpus.words[corpus.verseStartPosition(kursiVerse)!].ref;
      expect(overlay.isHidden(firstWord), isTrue, reason: 'hidden at start');
      expect(overlay.marks[firstWord], MushafWordMark.current);

      await recite(kursi);
      session().pause(); // pause: flushes the held last word
      await pumpEventQueue();

      expect(hifz().counts[HifzVerdict.correct], 50);
      expect(hifz().completed, isTrue);
      expect(hifz().running, isFalse);
      final done = container.read(mushafWordOverlayProvider)!;
      expect(done.isHidden(firstWord), isFalse);
      // Every recited word coloured correct (green); no next word left.
      expect(done.marks, hasLength(50));
      expect(done.marks.values.toSet(), {MushafWordMark.correct});
      expect(vibrations, 0);
    },
  );

  test('with the sound alert a mistake beeps, not vibrates', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    container
        .read(hifzSettingsProvider.notifier)
        .update(
          container
              .read(hifzSettingsProvider)
              .copyWith(alert: MistakeAlert.sound),
        );
    final upTo = kursi.substring(0, kursi.indexOf('خلفهم'));
    await recite('$upToخلفنا ولا يحيطون');
    expect((beeps, vibrations), (1, 0));
  });

  test('with both alerts a mistake vibrates and beeps', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    container
        .read(hifzSettingsProvider.notifier)
        .update(
          container
              .read(hifzSettingsProvider)
              .copyWith(alert: MistakeAlert.both),
        );
    final upTo = kursi.substring(0, kursi.indexOf('خلفهم'));
    await recite('$upToخلفنا ولا يحيطون');
    expect((beeps, vibrations), (1, 1));
    expect(
      HifzSettings.fromJson(
        const HifzSettings(alert: MistakeAlert.both).toJson(),
      ).alert,
      MistakeAlert.both,
    );
  });

  test('a pronunciation mistake on a recited word alerts once', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    await recite(kursi.split(' ').take(5).join(' '));
    final word = corpus.words[corpus.verseStartPosition(kursiVerse)! + 1].ref;
    final acoustic = container.read(
      acousticVerificationControllerProvider.notifier,
    ) as _Acoustic;
    acoustic.put({
      word: const AcousticWordResult(RecitationErrorType.wrongVowel, []),
    });
    await pumpEventQueue();
    expect(vibrations, 1);
    // The same mistake again (the ayah's check confirming it): no repeat.
    acoustic.put({
      word: const AcousticWordResult(RecitationErrorType.wrongVowel, []),
    });
    await pumpEventQueue();
    expect(vibrations, 1);
  });

  test('a saved vibrate switch becomes the vibrate alert', () {
    expect(HifzSettings.fromJson({'vibrate': false}).alert, MistakeAlert.off);
    expect(
      HifzSettings.fromJson({'vibrate': true}).alert,
      MistakeAlert.vibrate,
    );
    expect(
      HifzSettings.fromJson(HifzSettings(alert: MistakeAlert.sound).toJson())
          .alert,
      MistakeAlert.sound,
    );
  });

  test('wrong word: held with a mistake mark and a vibration, then '
      'self-corrected', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    final upTo = kursi.substring(0, kursi.indexOf('خلفهم'));

    await recite('$upToخلفنا ولا يحيطون');
    expect(hifz().pending, HifzVerdict.wrong);
    expect(vibrations, 1);
    final expected = hifz().expected!;
    final overlay = container.read(mushafWordOverlayProvider)!;
    expect(overlay.marks[expected], MushafWordMark.mistake);
    expect(overlay.isHidden(expected), isTrue);

    await recite('وما خلفهم ولا يحيطون');
    expect(hifz().pending, isNull);
    expect(hifz().counts[HifzVerdict.selfCorrected], 1);
    expect(
      container.read(mushafWordOverlayProvider)!.isHidden(expected),
      isFalse,
    );
  });

  test('skipped and repeated words', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse, strict: false);
    await recite(
      kursi.replaceFirst('سنه ', '').replaceFirst('الحي ', 'الحي الحي '),
    );
    session().pause();
    await pumpEventQueue();
    expect(hifz().counts[HifzVerdict.skipped], 1);
    expect(hifz().counts[HifzVerdict.repeated], 1);
    expect(hifz().completed, isTrue);
    expect(vibrations, 1, reason: 'the skip');
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    expect(
      marks.values.where((m) => m == MushafWordMark.skipped),
      hasLength(1),
      reason: 'the skipped word is yellow',
    );
    expect(
      marks.values.where((m) => m == MushafWordMark.correct),
      hasLength(49),
    );
  });

  test('pausing mid-range and resuming continues the test', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    final words = kursi.split(' ');
    await recite(words.take(20).join(' '));
    session().pause();
    await pumpEventQueue();
    expect(hifz().revealed, hasLength(20));
    session().resume();
    await pumpEventQueue();
    await recite(words.skip(20).join(' '));
    session().pause();
    await pumpEventQueue();
    expect(hifz().counts[HifzVerdict.correct], 50);
    expect(hifz().completed, isTrue);
  });

  test('page transition: moving past the visible page turns it', () async {
    await setUpHifz(
      from: (chapterNo: 2, verseNo: 256),
      to: (chapterNo: 2, verseNo: 257),
    );
    final words = spoken(2, 256).split(' ');
    await recite(words.take(words.length - 1).join(' '));
    expect(
      container.read(mushafPageTurnRequestsProvider),
      isNull,
      reason: 'the next word is still on the visible page',
    );
    // The page's last word: the next one is on the following page.
    await recite(words.join(' '));
    expect(container.read(mushafPageTurnRequestsProvider)?.direction, 1);
    expect(hifz().expected!.ayahId, 2257);
  });

  test('after the session the recited words keep their colours, until hide '
      'mode is toggled', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    final start = corpus.verseStartPosition(kursiVerse)!;
    await recite(kursi.split(' ').take(5).join(' '));
    expect(container.read(mushafWordOverlayProvider), isNotNull);
    await session().stop();
    await pumpEventQueue();
    expect(hifz().active, isFalse);
    final kept = container.read(mushafWordOverlayProvider)!;
    expect(kept.marks[corpus.words[start].ref], MushafWordMark.correct);
    expect(kept.marks.values, isNot(contains(MushafWordMark.current)));
    expect(kept.followHideMode, isTrue, reason: 'the page is not hidden');
    container.read(mushafHideModeProvider.notifier).toggle();
    await pumpEventQueue();
    expect(container.read(mushafWordOverlayProvider), isNull);
  });

  test('leaving the Mushaf clears the colours', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    await recite(kursi.split(' ').take(5).join(' '));
    await session().stop();
    await pumpEventQueue();
    expect(container.read(mushafWordOverlayProvider), isNotNull);
    // Nothing watches the test any more (the Mushaf closed): it goes, and
    // its colours with it.
    hifzListener.close();
    await pumpEventQueue();
    expect(container.read(mushafWordOverlayProvider), isNull);
  });

  test('a wrong word keeps what was heard in its place', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse, strict: false);
    final start = corpus.verseStartPosition(kursiVerse)!;
    await recite(
      kursi.replaceFirst('الحي', 'العلي').split(' ').take(15).join(' '),
    );
    final overlay = container.read(mushafWordOverlayProvider)!;
    final wrong = corpus.words[start + 5].ref;
    expect(overlay.marks[wrong], MushafWordMark.wrong);
    expect(overlay.heard[wrong], isNotEmpty);
  });

  test("a new recitation clears the last one's colours", () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    await recite(kursi.split(' ').take(5).join(' '));
    await session().stop();
    await pumpEventQueue();
    expect(container.read(mushafWordOverlayProvider)!.marks, isNotEmpty);
    await session().start(startLocation: const QuranLocation.page(1, 42));
    await pumpEventQueue();
    final overlay = container.read(mushafWordOverlayProvider);
    expect(overlay?.followHideMode ?? false, isFalse);
    expect(
      overlay?.marks.values.where((m) => m != MushafWordMark.current) ?? [],
      isEmpty,
    );
  });

  test('recited words are coloured; only the next word has a band', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse, strict: false);
    final start = corpus.verseStartPosition(kursiVerse)!;
    // A skip (lenient: marked and passed) and a wrong word.
    final text = kursi.replaceFirst('سنه ', '').replaceFirst('الحي', 'العلي');
    await recite(text.split(' ').take(15).join(' '));
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    expect(marks[corpus.words[start].ref], MushafWordMark.correct);
    expect(marks[corpus.words[start + 5].ref], MushafWordMark.wrong);
    expect(marks[corpus.words[start + 9].ref], MushafWordMark.skipped);
    expect(marks[hifz().expected], MushafWordMark.current);
    expect(
      marks.values.where((m) => m == MushafWordMark.current),
      hasLength(1),
    );
  });

  test('the band follows the reciter back over recited words', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    final start = corpus.verseStartPosition(kursiVerse)!;
    await recite(kursi.split(' ').take(20).join(' '));
    session().pause();
    await pumpEventQueue();
    session().resume();
    await pumpEventQueue();
    recognizer.events_.add(const LivePartialTranscript('الله لا'));
    await pumpEventQueue();
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    expect(marks[corpus.words[start + 2].ref], MushafWordMark.current);
    expect(
      marks.values.where((m) => m == MushafWordMark.current),
      hasLength(1),
      reason: 'the band moved back; the next new word has none',
    );
    expect(marks[corpus.words[start + 1].ref], MushafWordMark.correct);
  });

  test('words revealed by hand before reciting are not coloured', () async {
    final kursiStart = corpus.verseStartPosition((chapterNo: 2, verseNo: 255))!;
    await setUpHifz(revealedOnPage: kursiStart - page42First);
    await recite(kursi.split(' ').take(3).join(' '));
    final marks = container.read(mushafWordOverlayProvider)!.marks;
    expect(marks.containsKey(corpus.words[page42First].ref), isFalse);
    expect(marks[corpus.words[kursiStart].ref], MushafWordMark.correct);
  });

  test('a test continues from one surah into the next', () async {
    // Al-Fātiḥah on the visible page, the page's words known.
    await setUpHifz(hideMode: false);
    final fatihaEnd = corpus.verseEndPosition((chapterNo: 1, verseNo: 7))!;
    final judgeless = container.read(hifzControllerProvider.notifier);
    expect(judgeless, isNotNull);
    // Recite the last ayah of Al-Fātiḥah and the start of Al-Baqarah.
    await recite('${spoken(1, 7)} الف لام ميم ${spoken(2, 2)}');
    expect(hifz().completed, isFalse);
    expect(
      compareWordRefs(hifz().expected!, corpus.words[fatihaEnd].ref) > 0,
      isTrue,
      reason: 'the test went on past the end of Al-Fātiḥah',
    );
  });

  group('reciting with the page visible or partly revealed', () {
    final kursiStart = corpus.verseStartPosition((chapterNo: 2, verseNo: 255))!;

    test('hiding is optional: with the page visible, only the next word is '
        'marked and the test starts where the reciter does', () async {
      await setUpHifz(hideMode: false);
      await recite(kursi.split(' ').take(10).join(' '));
      final overlay = container.read(mushafWordOverlayProvider)!;
      expect(overlay.hideUnrevealed, isFalse);
      expect(overlay.isHidden(corpus.words[kursiStart + 20].ref), isFalse);
      expect(hifz().first, corpus.words[kursiStart].ref);
      expect(hifz().counts[HifzVerdict.correct], 10);
      expect(hifz().counts[HifzVerdict.skipped], 0);
      expect(
        overlay.marks[corpus.words[kursiStart + 10].ref],
        MushafWordMark.current,
      );
      expect(
        overlay.marks.values.where((m) => m == MushafWordMark.correct),
        hasLength(10),
      );
    });

    test(
      'the word just said is revealed at once; the next stays hidden',
      () async {
        await setUpHifz(revealedOnPage: kursiStart - page42First);
        recognizer.events_.add(const LivePartialTranscript('الله لا'));
        await pumpEventQueue();
        final overlay = container.read(mushafWordOverlayProvider)!;
        expect(overlay.isHidden(corpus.words[kursiStart + 1].ref), isFalse);
        expect(overlay.isHidden(corpus.words[kursiStart + 2].ref), isTrue);
        expect(
          overlay.marks[corpus.words[kursiStart + 2].ref],
          MushafWordMark.current,
        );
      },
    );

    test(
      'with hide mode on, the test continues from the first hidden word',
      () async {
        // 2:253 and 2:254 already uncovered by hand.
        await setUpHifz(revealedOnPage: kursiStart - page42First);
        expect(hifz().expected, corpus.words[kursiStart].ref);
        await recite(kursi);
        session().pause();
        await pumpEventQueue();
        expect(hifz().counts[HifzVerdict.correct], 50);
        expect(hifz().counts[HifzVerdict.skipped], 0);
      },
    );

    test('reveal buttons during a test mark words skipped; hiding back '
        'expects them again', () async {
      await setUpHifz(revealedOnPage: kursiStart - page42First);
      final controller = container.read(hifzControllerProvider.notifier);
      controller.revealNext();
      expect(hifz().counts[HifzVerdict.skipped], 1);
      expect(hifz().expected, corpus.words[kursiStart + 1].ref);
      controller.revealNext(wholeAyah: true);
      expect(hifz().counts[HifzVerdict.skipped], 50);
      expect(hifz().expected!.ayahId, 2256);

      controller.hideBack(wholeAyah: true);
      expect(hifz().expected, corpus.words[kursiStart].ref);
      expect(hifz().revealed.contains(corpus.words[kursiStart].ref), isFalse);
      controller.hideBack();
      expect(
        hifz().expected,
        corpus.words[kursiStart - 1].ref,
        reason: 'back into the words revealed before the test',
      );
    });

    test('hiding back past the visible page turns back', () async {
      await setUpHifz();
      container.read(hifzControllerProvider.notifier).hideBack();
      expect(
        container.read(mushafPageTurnRequestsProvider),
        isNull,
        reason: 'already at the start of the page and of the test',
      );
    });

    test('stopping carries progress into hide mode', () async {
      await setUpHifz(revealedOnPage: kursiStart - page42First);
      await recite(kursi.split(' ').take(12).join(' '));
      await session().stop();
      await pumpEventQueue();
      // The colours stay, hidden as hide mode now hides the page.
      expect(container.read(mushafWordOverlayProvider)?.followHideMode, isTrue);
      expect(
        container.read(mushafHideModeProvider).revealedOn(42),
        kursiStart - page42First + 12,
      );
    });
  });
}

/// The pronunciation check's results, set by the test.
class _Acoustic extends AcousticVerificationController {
  @override
  AcousticVerificationState build() => const AcousticVerificationState();

  void put(Map<WordRef, AcousticWordResult> words) =>
      state = AcousticVerificationState(words: words);
}
