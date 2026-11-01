import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_controller.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_downloads.dart';
import 'package:tahfeez_ai/features/listen/data/word_timings_repository.dart';
import 'package:tahfeez_ai/features/listen/domain/word_timings.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_word_feedback.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

import '../../test_helpers/fake_audio_controller.dart';

/// 1:2:4 «ٱلْعَٰلَمِينَ» — its 4th base letter is ل.
const _word = (ayahId: 1002, wordIndex: 3);
const _text = 'ٱلْعَٰلَمِينَ';

class _Heard extends AcousticVerificationController {
  @override
  AcousticVerificationState build() => const AcousticVerificationState(
    words: {
      _word: AcousticWordResult(RecitationErrorType.wrongVowel, [
        RecitationError(
          word: _word,
          letter: 4,
          type: RecitationErrorType.wrongVowel,
          expected: 'َ (َ)',
          observed: 'KASRA',
          likelihoodRatio: 6,
        ),
      ]),
    },
  );
}

class _Idgham extends AcousticVerificationController {
  static const _word = (ayahId: 2007, wordIndex: 8);

  @override
  AcousticVerificationState build() => const AcousticVerificationState(
    words: {
      _word: AcousticWordResult(RecitationErrorType.wrongLetter, [
        RecitationError(
          word: _word,
          letter: 5,
          type: RecitationErrorType.wrongLetter,
          expected: 'و (ٌ)',
          observed: 'ن',
          likelihoodRatio: 12,
        ),
        RecitationError(
          word: _word,
          letter: 5,
          type: RecitationErrorType.shaddaError,
          expected: 'و (ٌ)',
          observed: 'NO_SHADDA',
          likelihoodRatio: 6,
        ),
      ]),
    },
  );
}

/// 1:2's four words, timed.
class _Timings implements WordTimingsRepository {
  @override
  Future<AyahWordTimings?> timings(String edition, int ayahId) async =>
      quranComRecitations.containsKey(edition)
      ? const AyahWordTimings({
          1: (startMs: 100, endMs: 600),
          2: (startMs: 610, endMs: 1100),
          3: (startMs: 1110, endMs: 1900),
          4: (startMs: 1910, endMs: 3000),
        })
      : null;
}

void main() {
  Future<void> show(
    WidgetTester tester,
    MushafWordMark? mark, {
    Locale locale = const Locale('en'),
    Map<WordRef, String> heard = const {},
    Set<WordRef> corrected = const {},
  }) async {
    final container = ProviderContainer(
      overrides: [
        acousticVerificationControllerProvider.overrideWith(_Heard.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(mushafWordOverlayProvider.notifier)
        .set(
          MushafWordOverlay(
            first: _word,
            last: _word,
            marks: {_word: ?mark},
            hideUnrevealed: false,
            heard: heard,
            corrected: corrected,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RecitationWordFeedback(wordRef: _word, wordText: _text),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('base letters are counted as the phonetic reference counts them', () {
    expect(baseLetters(_text), ['ٱ', 'ل', 'ع', 'ٰ', 'ل', 'م', 'ي', 'ن']);
  });

  testWidgets('a pronunciation mistake names its letter and what was heard', (
    tester,
  ) async {
    await show(tester, MushafWordMark.tashkeel);
    expect(find.text('From your recitation'), findsOneWidget);
    expect(find.text('On «ل»: fatha expected, kasra heard'), findsOneWidget);
  });

  testWidgets('…in Arabic with the app in Arabic', (tester) async {
    await show(tester, MushafWordMark.tashkeel, locale: const Locale('ar'));
    expect(find.text('من تلاوتك'), findsOneWidget);
    expect(
      find.text('على «ل»: المتوقع الفتحة، والمسموع الكسرة'),
      findsOneWidget,
    );
  });

  testWidgets('a wrong or skipped word says so', (tester) async {
    await show(tester, MushafWordMark.wrong);
    expect(find.text('A different word was heard here.'), findsOneWidget);
    await show(tester, MushafWordMark.skipped);
    expect(find.text('This word was skipped.'), findsOneWidget);
  });

  testWidgets('a wrong word says what was heard instead, in the UI language', (
    tester,
  ) async {
    // Heard in the phonetic script: its long ۦ and qalqala ڇ made readable.
    const heard = {_word: 'ءَلعَلِۦڇ'};
    await show(tester, MushafWordMark.wrong, heard: heard);
    expect(find.text('Heard instead: «ءَلعَلِي»'), findsOneWidget);
    await show(
      tester,
      MushafWordMark.wrong,
      heard: heard,
      locale: const Locale('ar'),
    );
    expect(find.text('سُمع بدلًا منها: «ءَلعَلِي»'), findsOneWidget);
    await show(tester, MushafWordMark.wrong, corrected: const {_word});
    expect(find.text('Said wrong at first, then corrected.'), findsOneWidget);
  });

  testWidgets('a tanween said in full before و is explained as idgham, once', (
    tester,
  ) async {
    // 2:7 «غِشَٰوَةٌ وَلَهُمْ» joined, its tanween's nūn heard: two errors on
    // the merged و (a nūn heard, the doubled و single) — one idgham.
    const word = (ayahId: 2007, wordIndex: 8);
    final container = ProviderContainer(
      overrides: [
        acousticVerificationControllerProvider.overrideWith(_Idgham.new),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: word,
            last: word,
            marks: {word: MushafWordMark.tashkeel},
            hideUnrevealed: false,
          ),
        );
    for (final (locale, text) in [
      ('en', 'Idgham: the nūn merges into «و» (or stop before it)'),
      ('ar', 'إدغام: تُدغَم النون في «و» (أو قِف قبلها)'),
    ]) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RecitationWordFeedback(wordRef: word)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(text), findsOneWidget, reason: locale);
    }
  });

  test('ikhfāʾ, iqlāb and ikhfāʾ shafawī mistakes are named', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    RecitationError e(String expected, String heard) => RecitationError(
      word: _word,
      letter: 0,
      type: RecitationErrorType.wrongLetter,
      expected: expected,
      observed: heard,
      likelihoodRatio: 9,
    );
    expect(HifzStatusStrip.describe(e('ں (ٌ)', 'ن'), en), en.recIkhfa);
    expect(HifzStatusStrip.describe(e('۾ (ۢ)', 'ن'), ar), ar.recIqlab);
    expect(
      HifzStatusStrip.describe(e('۾ (م)', 'م'), ar),
      'إخفاء شفوي: تُخفى الميم قبل الباء بغنّة',
    );
    expect(
      HifzStatusStrip.describe(
        const RecitationError(
          word: _word,
          letter: 3,
          type: RecitationErrorType.qalqalaMissing,
          expected: 'ڇ (د)',
          observed: 'NO_QALQALA',
          likelihoodRatio: 8,
        ),
        ar,
      ),
      'قلقلة: «د» الساكنة تُقلقَل (نبرة خفيفة)',
    );
  });

  testWidgets('the correction: the word as the reciter recites it, or the '
      'word alone (said so) for a reciter without word timings', (
    tester,
  ) async {
    final audio = FakeAudioController();
    final container = ProviderContainer(
      overrides: [
        acousticVerificationControllerProvider.overrideWith(_Heard.new),
        audioControllerProvider.overrideWithValue(audio),
        defaultMushafProvider.overrideWith((ref) async => null),
        wordTimingsRepositoryProvider.overrideWithValue(_Timings()),
        // No storage to download to: everything streams.
        reciterAudioDirectoryProvider.overrideWith(
          (ref) async => throw UnsupportedError('none'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: _word,
            last: _word,
            marks: {_word: MushafWordMark.tashkeel},
            hideUnrevealed: false,
          ),
        );
    // The downloaded reciters looked for (for real, off the test clock).
    await tester.runAsync(
      () => container.read(reciterDownloadsProvider.notifier).ready(),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: RecitationWordFeedback(wordRef: _word, wordText: _text),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final listen = find.byKey(const ValueKey('recitation-word-listen'));
    expect(find.text('Listen to the correction'), findsOneWidget);
    expect(find.textContaining('no word timings'), findsNothing);

    // The last word: itself (the reciter stops on it), from Alafasy's 1:2.
    await tester.tap(listen);
    // (Its downloads looked for for real, off the test clock.)
    await tester.runAsync(
      () => container.read(reciterDownloadsProvider.notifier).ready(),
    );
    await tester.pumpAndSettle();
    final (url, start, end) = audio.clip!;
    expect(url, endsWith('/ar.alafasy/2.mp3'));
    expect(start, const Duration(milliseconds: 1760));
    expect(end, const Duration(milliseconds: 3300));

    await container.read(reciterProvider.notifier).select('ar.ghamdi');
    await tester.pumpAndSettle();
    expect(find.textContaining('no word timings'), findsOneWidget);
    await tester.tap(listen);
    await tester.pumpAndSettle();
    expect(audio.url, endsWith('/wbw/001_002_004.mp3'));
  });

  testWidgets('nothing for a word recited correctly or not recited', (
    tester,
  ) async {
    await show(tester, MushafWordMark.correct);
    expect(
      find.byKey(const ValueKey('recitation-word-feedback')),
      findsNothing,
    );
    await show(tester, null);
    expect(
      find.byKey(const ValueKey('recitation-word-feedback')),
      findsNothing,
    );
  });
}
