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
import 'package:tahfeez_ai/features/recitation/application/recitation_position.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_loop_sheet.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/repositories/quran_repository.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../ai/matching/corpus_fixture.dart';
import '../../ai/matching/quran_stream_matcher_cases_test.dart' show kursi;
import 'live_recognition_controller_test.dart' show FakeRecognizer;
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

class _MemoryStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}

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
  // What the memorization recorder was given.
  late List<AyahAttempt> recorded;

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
    HifzLoop? loop,
  }) async {
    recognizer = FakeRecognizer();
    vibrations = 0;
    beeps = 0;
    recorded = [];
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
        quranRepositoryProvider.overrideWithValue(_Pages()),
        memorizationRecordDelayProvider.overrideWithValue(Duration.zero),
        memorizationRecorderProvider.overrideWithValue(
          (attempts) async => recorded.addAll(attempts),
        ),
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
      final controller = container.read(hifzControllerProvider.notifier);
      if (loop != null) {
        controller.setLoop((from: from, to: to), loop);
      } else {
        controller.setRange((from: from, to: to));
      }
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

  test('a quick early pronunciation verdict is marked at once, softly; only '
      'a confirmed one alerts', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    await recite(kursi.split(' ').take(5).join(' '));
    final word = corpus.words[corpus.verseStartPosition(kursiVerse)! + 1].ref;
    final acoustic = container.read(
      acousticVerificationControllerProvider.notifier,
    ) as _Acoustic;
    // A word's quick early verdict: marked as checking, no alert.
    acoustic.put({
      word: const AcousticWordResult(
        RecitationErrorType.wrongVowel,
        [],
        provisional: true,
      ),
    });
    await pumpEventQueue();
    expect(vibrations, 0);
    expect(
      container.read(mushafWordOverlayProvider)!.marks[word],
      MushafWordMark.checking,
    );
    // The ayah's check withdraws it: the mark goes, no alert.
    acoustic.put({
      word: const AcousticWordResult(RecitationErrorType.correct, []),
    });
    await pumpEventQueue();
    expect(vibrations, 0);
    expect(
      container.read(mushafWordOverlayProvider)!.marks[word],
      MushafWordMark.correct,
    );
    // Confirmed: alerted and marked.
    acoustic.put({
      word: const AcousticWordResult(RecitationErrorType.wrongVowel, []),
    });
    await pumpEventQueue();
    expect(vibrations, 1);
    expect(
      container.read(mushafWordOverlayProvider)!.marks[word],
      MushafWordMark.tashkeel,
    );
  });

  test('a tajweed-only mistake: its own mark and its own alert', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    container
        .read(hifzSettingsProvider.notifier)
        .update(
          container
              .read(hifzSettingsProvider)
              .copyWith(
                alert: MistakeAlert.vibrate,
                tajweedAlert: MistakeAlert.sound,
              ),
        );
    await recite(kursi.split(' ').take(5).join(' '));
    final start = corpus.verseStartPosition(kursiVerse)!;
    final first = corpus.words[start + 1].ref,
        second = corpus.words[start + 2].ref;
    final acoustic = container.read(
      acousticVerificationControllerProvider.notifier,
    ) as _Acoustic;
    RecitationError error(
      WordRef w,
      RecitationErrorType type, {
      TajweedRule? rule,
    }) => RecitationError(
      word: w,
      letter: 0,
      type: type,
      expected: 'ں',
      likelihoodRatio: 5,
      rule: rule,
    );
    // A hidden nūn said plainly (ikhfāʾ): tajweed only.
    acoustic.put({
      first: AcousticWordResult(RecitationErrorType.wrongLetter, [
        error(first, RecitationErrorType.wrongLetter, rule: TajweedRule.ikhfa),
      ]),
    });
    await pumpEventQueue();
    expect(
      container.read(mushafWordOverlayProvider)!.marks[first],
      MushafWordMark.tajweed,
    );
    expect((beeps, vibrations), (1, 0), reason: 'the tajweed alert: sound');
    // A vowel said wrong: a pronunciation mistake, the mistake alert.
    acoustic.put({
      first: AcousticWordResult(RecitationErrorType.wrongLetter, [
        error(first, RecitationErrorType.wrongLetter, rule: TajweedRule.ikhfa),
      ]),
      second: AcousticWordResult(RecitationErrorType.wrongVowel, [
        error(second, RecitationErrorType.wrongVowel),
      ]),
    });
    await pumpEventQueue();
    expect(
      container.read(mushafWordOverlayProvider)!.marks[second],
      MushafWordMark.tashkeel,
    );
    expect((beeps, vibrations), (1, 1));
  });

  test(
    'tajweed mistakes: by rule or kind; a word is tajweed-only if all are',
    () {
      const w = (ayahId: 1001, wordIndex: 0);
      RecitationError e(RecitationErrorType type, {TajweedRule? rule}) =>
          RecitationError(
            word: w,
            letter: 0,
            type: type,
            expected: 'x',
            likelihoodRatio: 5,
            rule: rule,
          );
      expect(
        e(RecitationErrorType.wrongLetter, rule: TajweedRule.idgham).isTajweed,
        isTrue,
      );
      expect(e(RecitationErrorType.maddShort).isTajweed, isTrue);
      expect(e(RecitationErrorType.qalqalaMissing).isTajweed, isTrue);
      expect(e(RecitationErrorType.ghunnahMissing).isTajweed, isTrue);
      expect(e(RecitationErrorType.wrongLetter).isTajweed, isFalse);
      expect(
        AcousticWordResult(RecitationErrorType.maddShort, [
          e(RecitationErrorType.maddShort),
        ]).isTajweedOnly,
        isTrue,
      );
      expect(
        AcousticWordResult(RecitationErrorType.wrongVowel, [
          e(RecitationErrorType.maddShort),
          e(RecitationErrorType.wrongVowel),
        ]).isTajweedOnly,
        isFalse,
      );
      // (an uncertain sound alongside doesn't count either way)
      expect(
        AcousticWordResult(RecitationErrorType.maddShort, [
          e(RecitationErrorType.maddShort),
          e(RecitationErrorType.uncertain),
        ]).isTajweedOnly,
        isTrue,
      );
    },
  );

  test('the tajweed alert: as the mistake alert until chosen', () {
    expect(
      HifzSettings.fromJson({'alert': 'sound'}).tajweedAlert,
      MistakeAlert.sound,
    );
    const off = HifzSettings(tajweedAlert: MistakeAlert.off);
    expect(HifzSettings.fromJson(off.toJson()).tajweedAlert, MistakeAlert.off);
    expect(HifzSettings.fromJson(off.toJson()).alert, MistakeAlert.vibrate);
  });

  test('a sure quick verdict (a clear wrong vowel) alerts at once, and not '
      'again when confirmed', () async {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    await setUpHifz(from: kursiVerse, to: kursiVerse);
    await recite(kursi.split(' ').take(5).join(' '));
    final word = corpus.words[corpus.verseStartPosition(kursiVerse)! + 1].ref;
    final acoustic = container.read(
      acousticVerificationControllerProvider.notifier,
    ) as _Acoustic;
    RecitationError vowel(double llr) => RecitationError(
      word: word,
      letter: 0,
      type: RecitationErrorType.wrongVowel,
      expected: 'a',
      likelihoodRatio: llr,
    );
    acoustic.put({
      word: AcousticWordResult(RecitationErrorType.wrongVowel, [
        vowel(AcousticWordResult.sureVowelLlr + 1),
      ], provisional: true),
    });
    await pumpEventQueue();
    expect(vibrations, 1);
    expect(
      container.read(mushafWordOverlayProvider)!.marks[word],
      MushafWordMark.tashkeel,
    );
    acoustic.put({
      word: AcousticWordResult(RecitationErrorType.wrongVowel, [vowel(9)]),
    });
    await pumpEventQueue();
    expect(vibrations, 1, reason: 'once per word');
  });

  test(
    'recitedIn: an ayah with a word recited, correct ones included',
    () async {
      const kursiVerse = (chapterNo: 2, verseNo: 255);
      await setUpHifz(from: kursiVerse, to: kursiVerse);
      final hifz = container.read(hifzControllerProvider.notifier);
      expect(hifz.recitedIn(2255), isFalse);
      await recite(kursi.split(' ').take(3).join(' '));
      expect(hifz.recitedIn(2255), isTrue);
      expect(hifz.recitedIn(2256), isFalse);
    },
  );

  test('tajweed rules: every one until chosen, then as saved', () {
    expect(
      HifzSettings.fromJson({}).tajweedRules,
      HifzSettings.defaultTajweedRules,
    );
    final some = HifzSettings(tajweedRules: {TajweedRule.madd});
    expect(HifzSettings.fromJson(some.toJson()).tajweedRules, {
      TajweedRule.madd,
    });
    expect(
      HifzSettings.fromJson({
        'tajweedRules': ['qalqala', 'unknown'],
      }).tajweedRules,
      // (Saved before idghām into mīm was offered: that one on.)
      {TajweedRule.qalqala, TajweedRule.idghamMim},
    );
  });

  test('a tajweed rule added since the rules were chosen is on; a rule '
      'turned off stays off', () {
    // Saved before idghām into mīm existed, with qalqala turned off.
    final old = HifzSettings.fromJson({
      'tajweedRules': ['ikhfa', 'iqlab', 'ikhfaShafawi', 'idgham', 'madd'],
    });
    expect(old.tajweedRules, contains(TajweedRule.idghamMim));
    expect(old.tajweedRules, isNot(contains(TajweedRule.qalqala)));
    // Turned off since: stays off.
    final off = HifzSettings.fromJson(
      old
          .copyWith(
            tajweedRules: {...old.tajweedRules}..remove(TajweedRule.idghamMim),
          )
          .toJson(),
    );
    expect(off.tajweedRules, isNot(contains(TajweedRule.idghamMim)));
  });

  test(
    'the experimental ghunnah rule is off until chosen, kept when chosen',
    () {
      expect(
        const HifzSettings().tajweedRules,
        isNot(contains(TajweedRule.ghunnah)),
      );
      expect(
        HifzSettings.fromJson({
          'tajweedRules': ['madd'],
        }).tajweedRules,
        isNot(contains(TajweedRule.ghunnah)),
        reason: 'not turned on as a rule added since',
      );
      final on = const HifzSettings().copyWith(
        tajweedRules: {
          ...HifzSettings.defaultTajweedRules,
          TajweedRule.ghunnah,
        },
      );
      expect(
        HifzSettings.fromJson(on.toJson()).tajweedRules,
        contains(TajweedRule.ghunnah),
      );
    },
  );

  test('pronunciation strictness: balanced until chosen, then as saved', () {
    expect(HifzSettings.fromJson({}).strictness, RecitationStrictness.balanced);
    const lenient = HifzSettings(strictness: RecitationStrictness.lenient);
    expect(
      HifzSettings.fromJson(lenient.toJson()).strictness,
      RecitationStrictness.lenient,
    );
    expect(
      HifzSettings.fromJson({'strictness': 'unknown'}).strictness,
      RecitationStrictness.balanced,
    );
  });

  test(
    'mistake colours: orange and light blue until chosen, then as saved',
    () {
      const defaults = HifzSettings();
      expect(defaults.pronunciationColor, 0xFFEF6C00);
      expect(defaults.tajweedColor, 0xFF039BE5);
      // Orange keeps the page's own peach for a mistake still being checked.
      expect(defaults.inks.containsKey(MushafWordMark.checking), isFalse);
      final chosen = defaults.copyWith(
        pronunciationColor: HifzSettings.pronunciationColors[4],
        tajweedColor: HifzSettings.tajweedColors[3],
      );
      final restored = HifzSettings.fromJson(chosen.toJson());
      expect(restored.pronunciationColor, HifzSettings.pronunciationColors[4]);
      expect(restored.tajweedColor, HifzSettings.tajweedColors[3]);
      expect(restored.inks, {
        MushafWordMark.tashkeel: 0xFF00897B,
        MushafWordMark.tajweed: 0xFF8E24AA,
        // Teal lightened 55% toward white.
        MushafWordMark.checking: 0xFF8CCAC4,
      });
      // A colour no longer offered (or none saved): the default.
      final other = HifzSettings.fromJson({
        'pronunciationColor': 0xFF123456,
        'tajweedColor': 'blue',
      });
      expect(other.pronunciationColor, HifzSettings.defaultPronunciationColor);
      expect(other.tajweedColor, HifzSettings.defaultTajweedColor);
    },
  );

  test('strictness shifts every threshold together, tajweed too', () {
    const base = AcousticThresholds(
      error: 3,
      letterError: 3,
      shaddaError: 3,
      sukunError: 3,
      missingVowelError: 3,
      qalqalaError: 2,
      maddShare: 0.65,
      ghunnahHold: 1.2,
      sounds: {SoundGroup.similarLetter: SoundMargins(error: 4)},
    );
    final balanced = AcousticVerificationController.withStrictness(
      base,
      RecitationStrictness.balanced,
    );
    expect(identical(balanced, base), isTrue);
    final lenient = AcousticVerificationController.withStrictness(
      base,
      RecitationStrictness.lenient,
    );
    expect(
      [
        lenient.error,
        lenient.letterError,
        lenient.shaddaError,
        lenient.sukunError,
        lenient.missingVowelError,
        lenient.qalqalaError,
      ],
      [4, 4, 4, 4, 4, 3],
    );
    expect(lenient.maddShare, closeTo(0.55, 1e-9));
    expect(lenient.ghunnahHold, closeTo(1.5, 1e-9));
    // The sound groups' margins stay on top, unchanged.
    expect(lenient.sounds, base.sounds);
    final strict = AcousticVerificationController.withStrictness(
      base,
      RecitationStrictness.strict,
    );
    expect(strict.error, 2.5);
    expect(strict.sukunError, 2.5);
    expect(strict.qalqalaError, 1.5);
    expect(strict.maddShare, closeTo(0.72, 1e-9));
    expect(strict.ghunnahHold, closeTo(1.02, 1e-9));
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

  test('page visible: the reciter is looked for on that page only', () async {
    // Page 42 on screen; «إِنَّ ٱلْإِنسَٰنَ» also opens 100:6 and 103:2.
    await setUpHifz(hideMode: false);
    await recite(spoken(103, 2));
    expect(hifz().first, isNull, reason: 'not on the page: not located');
    await recite(spoken(2, 255));
    expect(hifz().first?.ayahId, inInclusiveRange(2253, 2256), reason: 'on it');
  });

  test('a test continues from one surah into the next', () async {
    // Al-Fātiḥah on the visible page, the page's words known.
    await setUpHifz(hideMode: false);
    final fatihaEnd = corpus.verseEndPosition((chapterNo: 1, verseNo: 7))!;
    container.read(mushafPageWordRangesProvider.notifier).report(1, (
      first: (ayahId: 1001, wordIndex: 0),
      last: corpus.words[fatihaEnd].ref,
    ));
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('screen', const QuranLocation.page(1, 1));
    await pumpEventQueue();
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

  test('the progress line: the share of the page done', () {
    expect(pageProgress(9, first: 10, last: 19), 0, reason: 'nothing yet');
    expect(pageProgress(14, first: 10, last: 19), 0.5);
    expect(pageProgress(19, first: 10, last: 19), 1);
    expect(pageProgress(40, first: 10, last: 19), 1, reason: 'past it');
  });

  test(
    'a range chosen in the Memorize tab becomes the test\'s range',
    () async {
      await setUpHifz();
      await session().stop();
      await pumpEventQueue();
      const range = (
        from: (chapterNo: 2, verseNo: 255),
        to: (chapterNo: 2, verseNo: 256),
      );
      container.read(requestedHifzRangeProvider.notifier).request(range);
      await pumpEventQueue();
      expect(hifz().range, range);
      expect(
        container.read(requestedHifzRangeProvider),
        isNull,
        reason: 'taken',
      );
    },
  );

  group('memorization: each test recorded per ayah', () {
    const kursiVerse = (chapterNo: 2, verseNo: 255);

    test('a clean test from memory: the ayah graded good', () async {
      await setUpHifz(from: kursiVerse, to: kursiVerse);
      await recite(kursi);
      await session().stop();
      await pumpEventQueue();
      final a = recorded.single;
      expect(
        (a.ayahId, a.grade, a.words, a.hidden),
        (2255, AyahGrade.good, 50, true),
      );
    });

    test(
      'a skipped word fails it; an ayah not finished is not graded',
      () async {
        await setUpHifz(
          from: kursiVerse,
          to: (chapterNo: 2, verseNo: 256),
          strict: false,
        );
        await recite(kursi.replaceFirst('سنه ', ''));
        await recite(spoken(2, 256).split(' ').take(5).join(' '));
        await session().stop();
        await pumpEventQueue();
        expect(
          [for (final a in recorded) (a.ayahId, a.grade, a.skipped)],
          [(2255, AyahGrade.fail, 1)],
        );
      },
    );

    test('a loop records every repetition', () async {
      await setUpHifz(
        from: kursiVerse,
        to: kursiVerse,
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2),
      );
      await recite(kursi);
      session().pause();
      await pumpEventQueue();
      session().resume();
      await pumpEventQueue();
      expect(recorded, hasLength(1), reason: 'the first repetition');
      await recite(kursi);
      await session().stop();
      await pumpEventQueue();
      expect(recorded.map((a) => a.grade), [AyahGrade.good, AyahGrade.good]);
    });
  });

  group('loop recitation', () {
    const kursiVerse = (chapterNo: 2, verseNo: 255);
    final kursiFirst = corpus.words[corpus.verseStartPosition(kursiVerse)!].ref;

    /// Pausing flushes the held last word; resuming goes on reciting.
    Future<void> pauseAndResume() async {
      session().pause();
      await pumpEventQueue();
      session().resume();
      await pumpEventQueue();
    }

    test('each ayah: recited the set number of times, then the next', () async {
      await setUpHifz(
        from: kursiVerse,
        to: (chapterNo: 2, verseNo: 256),
        loop: const HifzLoop(mode: HifzLoopMode.eachAyah, count: 2),
      );
      expect((hifz().repetition, hifz().loopAyah), (1, kursiVerse));
      expect(loopProgress(hifz(), corpus), (value: 0.0, segments: 2));
      final next = corpus
          .words[corpus.verseStartPosition((chapterNo: 2, verseNo: 256))!]
          .ref;
      expect(
        container.read(mushafWordOverlayProvider)!.isHidden(next),
        isTrue,
        reason: 'the ayahs still to come are hidden too',
      );

      await recite(kursi);
      await pauseAndResume();
      // Again: hidden and tested afresh.
      expect((hifz().repetition, hifz().loopAyah), (2, kursiVerse));
      expect(hifz().running, isTrue);
      expect(hifz().revealed, isEmpty);
      expect(hifz().counts[HifzVerdict.correct], 0);
      expect(
        container.read(mushafWordOverlayProvider)!.isHidden(kursiFirst),
        isTrue,
      );
      expect(container.read(recitationPassProvider), 1);
      // One of four recitations (2 ayahs × 2) done.
      expect(loopProgress(hifz(), corpus), (value: 0.25, segments: 2));

      await recite(kursi);
      await pauseAndResume();
      expect(
        (hifz().repetition, hifz().loopAyah),
        (1, (chapterNo: 2, verseNo: 256)),
      );
      expect(hifz().expected, next);
      expect(loopProgress(hifz(), corpus)?.value, 0.5);
      expect(
        container.read(mushafWordOverlayProvider)!.isHidden(kursiFirst),
        isFalse,
        reason: 'an ayah done is shown',
      );

      for (var k = 0; k < 2; k++) {
        await recite(spoken(2, 256));
        await pauseAndResume();
      }
      expect(hifz().completed, isTrue);
      expect(hifz().running, isFalse);
      expect(hifz().repetition, 2);
      expect(container.read(recitationPassProvider), 3);
      expect(loopProgress(hifz(), corpus)?.value, 1);
    });

    test('whole range, each ayah twice per pass: ayah by ayah, then the '
        'range again from its start, hidden again', () async {
      const second = (chapterNo: 2, verseNo: 256);
      await setUpHifz(
        from: kursiVerse,
        to: second,
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2, perAyah: 2),
      );
      expect(
        (hifz().repetition, hifz().loopAyah, hifz().ayahRepetition),
        (1, kursiVerse, 1),
      );
      await recite(kursi);
      await pauseAndResume();
      expect(
        (hifz().repetition, hifz().loopAyah, hifz().ayahRepetition),
        (1, kursiVerse, 2),
        reason: 'the same ayah, its second time',
      );
      expect(loopProgress(hifz(), corpus)?.value, closeTo(0.125, 0.001));
      await recite(kursi);
      await pauseAndResume();
      expect(
        (hifz().repetition, hifz().loopAyah, hifz().ayahRepetition),
        (1, second, 1),
      );
      expect(
        container.read(mushafWordOverlayProvider)!.isHidden(kursiFirst),
        isFalse,
        reason: 'the ayah done is shown',
      );
      for (var k = 0; k < 2; k++) {
        await recite(spoken(2, 256));
        await pauseAndResume();
      }
      expect(
        (hifz().repetition, hifz().loopAyah, hifz().ayahRepetition),
        (2, kursiVerse, 1),
        reason: 'the second pass, from the start',
      );
      expect(loopProgress(hifz(), corpus)?.value, closeTo(0.5, 0.001));
      expect(
        container.read(mushafWordOverlayProvider)!.isHidden(kursiFirst),
        isTrue,
        reason: 'the range hidden again',
      );
    });

    test('strict: a pass with a mistake waits, its marks kept, to be '
        'recited again or skipped', () async {
      await setUpHifz(
        from: kursiVerse,
        to: kursiVerse,
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2, strict: true),
        // (The test's own strictness off: a skipped word does not hold it.)
        strict: false,
      );
      // A word left out.
      final words = kursi.split(' ')..removeAt(6);
      await recite(words.join(' '));
      await pauseAndResume();
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(hifz().loopReview, isTrue);
      expect(hifz().repetition, 1, reason: 'not on to the next pass');
      expect(hifz().counts[HifzVerdict.skipped], greaterThan(0));

      container.read(hifzControllerProvider.notifier).loopTryAgain();
      await pumpEventQueue();
      expect(hifz().loopReview, isFalse);
      expect(hifz().repetition, 1, reason: 'the same pass, not counted');
      expect(hifz().expected, kursiFirst);

      await recite(words.join(' '));
      await pauseAndResume();
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(hifz().loopReview, isTrue);
      container.read(hifzControllerProvider.notifier).loopSkip();
      await pumpEventQueue();
      expect((hifz().loopReview, hifz().repetition), (false, 2));
      expect(hifz().expected, kursiFirst);

      // Without a mistake: on, no review.
      await recite(kursi);
      await pauseAndResume();
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      expect(hifz().loopReview, isFalse);
      expect(hifz().completed, isTrue);
    });

    test('whole range: recited again from its start; the session end ends '
        'the loop', () async {
      await setUpHifz(
        from: kursiVerse,
        to: kursiVerse,
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2),
      );
      expect(hifz().loopAyah, isNull);
      await recite(kursi);
      await pauseAndResume();
      expect(hifz().repetition, 2);
      expect(hifz().expected, kursiFirst);
      expect(loopProgress(hifz(), corpus), (value: 0.5, segments: 2));
      await recite(kursi.split(' ').take(25).join(' '));
      expect(loopProgress(hifz(), corpus)?.value, closeTo(0.75, 0.02));
      await recite(kursi.split(' ').skip(25).join(' '));
      session().pause();
      await pumpEventQueue();
      expect(hifz().completed, isTrue);
      expect(
        container.read(mushafPageTurnRequestsProvider),
        isNull,
        reason: 'its start is on the page',
      );

      await session().stop();
      await pumpEventQueue();
      expect(hifz().loop, isNull);
      expect(hifz().range, isNull, reason: 'the range chosen before');
    });

    test("a repetition's pronunciation verdicts are its own", () async {
      await setUpHifz(
        from: kursiVerse,
        to: kursiVerse,
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 3),
      );
      await recite(kursi);
      await pauseAndResume();
      final acoustic = container.read(
        acousticVerificationControllerProvider.notifier,
      ) as _Acoustic;
      // The first repetition's check, arriving once the second has begun:
      // alerted, but not marked on the second.
      acoustic.put({
        kursiFirst: const AcousticWordResult(
          RecitationErrorType.wrongVowel,
          [],
        ),
      });
      await pumpEventQueue();
      expect(vibrations, 1);
      await recite(kursi.split(' ').take(5).join(' '));
      final marks = container.read(mushafWordOverlayProvider)!.marks;
      expect(marks[kursiFirst], MushafWordMark.correct);

      acoustic.put({
        kursiFirst: const AcousticWordResult(
          RecitationErrorType.wrongVowel,
          [],
          pass: 1,
        ),
      });
      await pumpEventQueue();
      expect(vibrations, 2);
      expect(
        container.read(mushafWordOverlayProvider)!.marks[kursiFirst],
        MushafWordMark.tashkeel,
      );
    });

    test('a range ending on a later page goes back to its start', () async {
      await setUpHifz(
        from: (chapterNo: 2, verseNo: 256),
        to: (chapterNo: 2, verseNo: 257),
        loop: const HifzLoop(mode: HifzLoopMode.range, count: 2),
      );
      await recite(spoken(2, 256));
      // The page turned to 43, where 2:257 is.
      final p43First = corpus.verseStartPosition((chapterNo: 2, verseNo: 257))!;
      container
          .read(mushafRecitationTargetProvider.notifier)
          .show('screen', const QuranLocation.page(1, 43));
      container.read(mushafPageWordRangesProvider.notifier).report(43, (
        first: corpus.words[p43First].ref,
        last: corpus
            .words[corpus.verseEndPosition((chapterNo: 2, verseNo: 257))!]
            .ref,
      ));
      await pumpEventQueue();
      await recite(spoken(2, 257));
      await pauseAndResume();
      expect(hifz().repetition, 2);
      expect(container.read(mushafPageTurnRequestsProvider)?.page, 42);
      expect(
        hifz().expected,
        corpus
            .words[corpus.verseStartPosition((chapterNo: 2, verseNo: 256))!]
            .ref,
      );
    });
  });
}

/// Page lookups: every ayah is on page 42.
class _Pages implements QuranRepository {
  @override
  Future<int?> getPageForAyah({
    required int mushafId,
    required int ayahId,
  }) async => 42;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The pronunciation check's results, set by the test.
class _Acoustic extends AcousticVerificationController {
  @override
  AcousticVerificationState build() => const AcousticVerificationState();

  void put(Map<WordRef, AcousticWordResult> words) =>
      state = AcousticVerificationState(words: words);
}
