import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_pages_on_screen.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_ayah_sheet.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/similar_ayahs_section.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/word_peek.dart';
import 'package:tahfeez_ai/features/recitation/application/mistake_hint.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_start.dart';
import 'package:tahfeez_ai/wbw/presentation/word_detail_sheet.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';

import '../test_helpers/real_app.dart';

void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  /// Word [index] of [ayahId] tapped on page [page], as the engine reports
  /// it (the finger down on the page first: where its pill goes).
  Future<void> tapWord(
    WidgetTester tester,
    int page,
    int ayahId,
    int index,
  ) async {
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('printed-page')).first),
    );
    FakePage.tapWordHandlers[page]!(
      MushafTokenHitRect(
        rect: Rect.zero,
        sourceTokenId: index,
        tokenType: MushafTokenType.quranWord,
        canonicalAyahId: ayahId,
        canonicalWordIndex: index,
        text: '',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a word tapped: the band on it and its pill, no sheet — gone '
      'after a few seconds; tapped again, the pill again', (tester) async {
    final container = await RealApp.launch(tester, route: '/quran/surah/1');
    await tapWord(tester, 1, 1002, 1);
    expect(container.read(recitationStartProvider)?.word, (
      ayahId: 1002,
      wordIndex: 1,
    ));
    expect(find.byKey(const ValueKey('word-peek')), findsOneWidget);
    expect(find.text('Word details'), findsNothing);

    // By itself, after its few seconds.
    await tester.pump(WordPeek.shownFor);
    await tester.pump(const Duration(milliseconds: 300));
    expect(WordPeek.isShown, isFalse);

    // The band's word tapped again: the pill again, the band kept.
    await tapWord(tester, 1, 1002, 1);
    expect(find.byKey(const ValueKey('word-peek')), findsOneWidget);
    expect(find.text('Word details'), findsNothing);
    expect(container.read(recitationStartProvider)?.word, (
      ayahId: 1002,
      wordIndex: 1,
    ));
    // Its sound, its meaning, its ayah.
    expect(find.byKey(const ValueKey('word-peek-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-peek-word')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-peek-ayah')), findsOneWidget);
    await tester.pump(WordPeek.shownFor);
    await tester.pump(const Duration(milliseconds: 300));
    await RealApp.quit(tester);
  });

  testWidgets("the pill opens the word's sheet, or its ayah's", (tester) async {
    await RealApp.launch(tester, route: '/quran/surah/1');
    await tapWord(tester, 1, 1003, 0);
    await tester.tap(find.byKey(const ValueKey('word-peek-word')));
    await RealApp.settle(tester);
    expect(find.text('Word details'), findsOneWidget);
    expect(WordPeek.isShown, isFalse);
    await tester.tapAt(const Offset(5, 5)); // the sheet closed
    await RealApp.settle(tester);

    await tapWord(tester, 1, 1004, 0);
    await tester.tap(find.byKey(const ValueKey('word-peek-ayah')));
    await RealApp.settle(tester);
    expect(find.text('Ayah details'), findsOneWidget);
    await RealApp.quit(tester);
  });

  testWidgets('the ayah sheet goes to the next and previous ayahs: buttons '
      'and swipes, across surahs', (tester) async {
    await RealApp.launch(tester, route: '/quran/surah/112');
    showAyahDetailSheet(
      tester.element(find.byType(Scaffold).last),
      ayahId: 112004,
    );
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('ayah-sheet-word-112004:0')), findsOne);
    // On past the surah's last: the next surah's first.
    await tester.tap(find.byKey(const ValueKey('ayah-sheet-next')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('ayah-sheet-word-113001:0')), findsOne);
    // Swiped to the left: the previous one.
    await tester.fling(
      find.byKey(const ValueKey('ayah-sheet-swipe')),
      const Offset(-300, 0),
      1000,
    );
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('ayah-sheet-word-112004:0')), findsOne);
    // To the right: the next.
    await tester.fling(
      find.byKey(const ValueKey('ayah-sheet-swipe')),
      const Offset(300, 0),
      1000,
    );
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('ayah-sheet-word-113001:0')), findsOne);
    await RealApp.quit(tester);
  });

  testWidgets('similar ayahs hidden from the ayah sheet by its own switch', (
    tester,
  ) async {
    final container = await RealApp.launch(tester, route: '/quran/surah/2');
    // 2:48 has ayahs like it.
    showAyahDetailSheet(
      tester.element(find.byType(Scaffold).last),
      ayahId: 2048,
    );
    await RealApp.settle(tester);
    expect(find.byType(SimilarAyahsSection), findsOneWidget);
    final view = container.read(ayahViewPreferencesProvider.notifier);
    await view.set(
      container.read(ayahViewPreferencesProvider).copyWith(showSimilar: false),
    );
    await RealApp.settle(tester);
    expect(find.byType(SimilarAyahsSection), findsNothing);
    await RealApp.quit(tester);
  });

  testWidgets("the word's sound asked for: the pill stays while it plays", (
    tester,
  ) async {
    await RealApp.launch(tester, route: '/quran/surah/1');
    await tapWord(tester, 1, 1002, 1);
    WordPeek.holdForSound();
    // Long past its few seconds, still shown while the sound plays.
    await tester.pump(WordPeek.shownFor * 2);
    expect(WordPeek.isShown, isTrue);
    // The sound over: gone a moment later.
    WordPeek.soundEnded();
    await tester.pump(WordPeek.afterSound);
    await tester.pump(const Duration(milliseconds: 300));
    expect(WordPeek.isShown, isFalse);
    await RealApp.quit(tester);
  });

  testWidgets('mistakes found together: one hint, on the first, "+N" for '
      'the others', (tester) async {
    final container = await RealApp.launch(tester, route: '/quran/surah/1');
    final hints = container.read(mistakeHintProvider.notifier);
    hints.report(const [
      (ayahId: 1003, wordIndex: 1),
      (ayahId: 1002, wordIndex: 2),
    ]);
    hints.report(const [(ayahId: 1004, wordIndex: 0)]);
    await tester.pump();
    final hint = container.read(mistakeHintProvider)!;
    expect(hint.word, (ayahId: 1002, wordIndex: 2));
    expect(hint.more, 2);
    await RealApp.quit(tester);
  });

  testWidgets("a mistake's hint: tapped, its word's sheet; the tap pill "
      'over it takes its place', (tester) async {
    await RealApp.launch(tester, route: '/quran/surah/1');
    final page = tester.getCenter(
      find.byKey(const ValueKey('printed-page')).first,
    );
    void hint() => MistakePeek.show(
      tester.element(find.byType(Scaffold).last),
      word: (ayahId: 1002, wordIndex: 1),
      // The word's box: where the finger will touch.
      rect: Rect.fromCenter(center: page, width: 60, height: 30),
      more: 1,
      onTap: () => showWordDetailSheet(
        tester.element(find.byType(Scaffold).last),
        wordRef: (ayahId: 1002, wordIndex: 1),
      ),
    );
    hint();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('mistake-peek')), findsOneWidget);
    expect(find.byKey(const ValueKey('mistake-peek-more')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mistake-peek')));
    await RealApp.settle(tester);
    expect(find.text('Word details'), findsOneWidget);
    expect(MistakePeek.isShown, isFalse);
    await tester.tapAt(const Offset(5, 5)); // the sheet closed
    await RealApp.settle(tester);

    // The tap pill shown over it: the hint gone.
    hint();
    await tester.pump();
    await tapWord(tester, 1, 1002, 1);
    await tester.pump();
    expect(WordPeek.isShown, isTrue);
    expect(MistakePeek.isShown, isFalse);
    await RealApp.quit(tester);
  });

  group('the mistake hint, through the Mushaf', () {
    const word = (ayahId: 1003, wordIndex: 1);

    /// The app on Al-Fatiha's page, [word] drawn at [box] (a page standing
    /// in for the engine's, which measures words); its hint reported.
    Future<ProviderContainer> hinted(WidgetTester tester, Rect box) async {
      final container = await RealApp.launch(tester, route: '/quran/surah/1');
      expect(
        container.read(mushafPageWordRangesProvider),
        contains(1),
        reason: "the page's words reported",
      );
      mushafWordLocators[1] = _At({word: box});
      addTearDown(() => mushafWordLocators.remove(1));
      container.read(mistakeHintProvider.notifier).report(const [word]);
      await tester.pump();
      await tester.pump();
      // (Its fade and slight grow in, done.)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      return container;
    }

    Rect pill(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('mistake-peek')));

    testWidgets('just above its word, centred on it', (tester) async {
      const box = Rect.fromLTWH(120, 420, 80, 40);
      await hinted(tester, box);
      expect(MistakePeek.isShown, isTrue);
      final r = pill(tester);
      expect(r.bottom, moreOrLessEquals(box.top - 6, epsilon: 0.5));
      expect(r.center.dx, moreOrLessEquals(box.center.dx, epsilon: 0.5));
      await RealApp.quit(tester);
    });

    testWidgets("a word on the page's first line: below it", (tester) async {
      final container = await RealApp.launch(tester, route: '/quran/surah/1');
      // The Mushaf's top on screen: the word's line right under it.
      final top = tester
          .getTopLeft(find.byKey(const ValueKey('printed-page')).first)
          .dy;
      final box = Rect.fromLTWH(150, top + 4, 80, 40);
      mushafWordLocators[1] = _At({word: box});
      addTearDown(() => mushafWordLocators.remove(1));
      container.read(mistakeHintProvider.notifier).report(const [word]);
      await tester.pump();
      await tester.pump();
      // (Its fade and slight grow in, done.)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final r = pill(tester);
      expect(r.top, moreOrLessEquals(box.bottom + 6, epsilon: 0.5));
      await RealApp.quit(tester);
    });

    testWidgets('stays 3 seconds, then goes', (tester) async {
      await hinted(tester, const Rect.fromLTWH(120, 420, 80, 40));
      expect(MistakePeek.shownFor, const Duration(seconds: 3));
      // (600 ms gone in showing it.)
      await tester.pump(const Duration(milliseconds: 2200));
      expect(MistakePeek.isShown, isTrue, reason: 'still within 3 s');
      await tester.pump(const Duration(milliseconds: 500));
      expect(MistakePeek.isShown, isFalse);
      await RealApp.quit(tester);
    });
  });

  test('the hints switch: on by default, kept as set', () {
    expect(const HifzSettings().mistakeHints, isTrue);
    final off = HifzSettings.fromJson(
      jsonDecode(
        jsonEncode(const HifzSettings().copyWith(mistakeHints: false).toJson()),
      ),
    );
    expect(off.mistakeHints, isFalse);
    // Saved before the switch existed: on.
    expect(HifzSettings.fromJson(const {}).mistakeHints, isTrue);
  });

  test("ayahs before and after, across surahs and at the Quran's ends", () {
    expect(nextAyahId(1007), 2001);
    expect(nextAyahId(2255), 2256);
    expect(nextAyahId(114006), isNull);
    expect(previousAyahId(2001), 1007);
    expect(previousAyahId(1001), isNull);
    expect(previousAyahId(113001), 112004);
  });
}

/// A page standing in for the engine's: where each word is drawn.
class _At implements MushafWordLocatingPage {
  _At(this.boxes);

  final Map<WordRef, Rect> boxes;

  @override
  Rect? wordRectOnScreen(WordRef word) => boxes[word];
}
