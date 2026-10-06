import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/acoustic/quran_acoustic_verifier.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/recitation/application/acoustic_verification_controller.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_word_feedback.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

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
