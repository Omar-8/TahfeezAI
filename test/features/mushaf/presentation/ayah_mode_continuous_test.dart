import 'package:drift/native.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_focus_ayah.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_turn.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_pager.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';
import '../../../test_helpers/fake_audio_controller.dart';

/// Every page: ayahs 1:2 and 1:3, two words each (the synthetic dataset's).
class _Page implements QuranEngineMushafPage {
  _Page(this.pageNumber);

  @override
  final int pageNumber;

  @override
  int get wordCount => 4;
  @override
  List<int> get ayahWordBoundaries => const [2, 4];
  @override
  ({VerseRef first, VerseRef last})? get verseSpan =>
      (first: (chapterNo: 1, verseNo: 2), last: (chapterNo: 1, verseNo: 3));

  /// Page 9's ayahs are 1:1 and 1:2, page 10's 1:3 and 1:4, page 11's
  /// 1:5 and 1:6; any other page's, a surah's two (page 300's, surah 78's).
  int get _first => switch (pageNumber) {
    1 || 9 => 1001,
    10 => 1003,
    11 => 1005,
    _ => (2 + pageNumber % 112) * 1000 + 1,
  };
  @override
  List<WordRef> get wordRefs => [
    (ayahId: _first, wordIndex: 0),
    (ayahId: _first, wordIndex: 1),
    (ayahId: _first + 1, wordIndex: 0),
    (ayahId: _first + 1, wordIndex: 1),
  ];
  @override
  double get aspectRatio => 0.6;

  @override
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  }) => const SizedBox.expand(key: ValueKey('printed-page'));

  @override
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights, {
    List<PageBand> bands = const [],
  }) {}
  @override
  void setHiddenWords(Set<int> hidden) {}
  @override
  int highlightWordAt(int wordIndex, {required Color color}) => 0;
  @override
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) {}
  @override
  int highlightWord(WordRef target, {String mode = 'band'}) => 0;
  @override
  int highlightAyah(VerseRef target, {String mode = 'band'}) => 0;
  @override
  void clearHighlights() {}
  @override
  void maskWord(WordRef target, {String mode = 'hide'}) {}
  @override
  void maskAyah(VerseRef target, {String mode = 'hide'}) {}
  @override
  void revealNext([int count = 1]) {}
  @override
  void unmask() {}
  @override
  void dispose() {}
}

class _Backend implements QuranEngineMushafBackend {
  @override
  Future<String> initialize() async => 'fake';
  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async =>
      _Page(pageNumber);
  @override
  void disposePage(QuranEngineMushafPage page) {}
  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

/// Ayah mode in one continuous scroll.
class _ContinuousView extends AyahViewPreferencesController {
  @override
  AyahViewPreferences build() =>
      AyahViewPreferences(layout: _layout, showTranslation: false);
}

var _layout = AyahLayout.continuous;

void main() {
  late ProviderContainer container;
  late List<int> changes;

  Future<void> pump(
    WidgetTester tester, {
    FakeAudioController? audio,
    AyahLayout layout = AyahLayout.continuous,
    int initialPage = 10,
    int? target,
    int? focus,
    AyahLayout? thenLayout,
  }) async {
    _layout = layout;
    final db = QuranDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await const QuranDatasetImporter().import(db, buildValidSyntheticPayload());
    container = ProviderContainer(
      overrides: [
        mushafQuranEngineBackendProvider.overrideWith(
          (ref) async => _Backend(),
        ),
        quranDatabaseProvider.overrideWith((ref) => db),
        quranScriptCodeProvider.overrideWith((ref) => testScriptCode),
        ayahViewPreferencesProvider.overrideWith(_ContinuousView.new),
        if (audio != null) ...[
          audioControllerProvider.overrideWithValue(audio),
          defaultMushafProvider.overrideWith((ref) async => null),
        ],
      ],
    );
    addTearDown(container.dispose);
    container.read(readerModeProvider);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    if (target != null) {
      container.read(ayahModeTargetProvider.notifier).show(target);
    }
    if (focus != null) {
      container.read(mushafFocusAyahProvider.notifier).focus('test', focus);
    }
    changes = [];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MushafPager(
              mushafId: 1,
              pageCount: 604,
              initialPageNumber: initialPage,
              onPageChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    if (thenLayout != null) {
      // The saved layout read back a moment later, the first page loaded.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      final view = container.read(ayahViewPreferencesProvider);
      await container
          .read(ayahViewPreferencesProvider.notifier)
          .set(view.copyWith(layout: thenLayout));
    }
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  Finder divider(int page) =>
      find.byKey(ValueKey('ayah-mode-page-divider-$page'), skipOffstage: false);

  testWidgets('continuous: pages one after another, no page buttons', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(PageView), findsNothing);
    expect(divider(10), findsOneWidget);
    expect(divider(11), findsOneWidget);
    // Opened at its page's top.
    expect(tester.getTopLeft(divider(10)).dy, inInclusiveRange(0, 100));
    expect(find.byKey(const ValueKey('ayah-mode-next-page')), findsNothing);
  });

  testWidgets('continuous: scrolling down into the next page turns to it, '
      'and up into the one before', (tester) async {
    await pump(tester);
    final list = find.byType(CustomScrollView);
    await tester.drag(list, Offset(0, -tester.getTopLeft(divider(11)).dy));
    await tester.pumpAndSettle();
    expect(changes.last, 11);
    await tester.drag(list, const Offset(0, 1200));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(changes.last, lessThan(10));
  });

  testWidgets('continuous: a page turn brings the page into view — nearby '
      'scrolled to, far away laid out afresh', (tester) async {
    await pump(tester);
    container.read(mushafPageTurnRequestsProvider.notifier).next();
    await tester.pumpAndSettle();
    expect(changes.last, 11);
    expect(tester.getTopLeft(divider(11)).dy, inInclusiveRange(0, 100));

    container.read(mushafPageTurnRequestsProvider.notifier).toPage(300);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(changes.last, 300);
    expect(tester.getTopLeft(divider(300)).dy, inInclusiveRange(0, 100));
  });

  void shortScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Rect rectOf(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  testWidgets('continuous: revealing scrolls to the word shown, on the page '
      'being read', (tester) async {
    shortScreen(tester);
    await pump(tester);
    final hide = container.read(mushafHideModeProvider.notifier);
    hide.toggle();
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      hide.revealNextWord(10);
      await tester.pumpAndSettle();
    }
    final word = rectOf(tester, 'ayah-word-1004:1');
    expect(word.top, greaterThanOrEqualTo(0));
    expect(word.bottom, lessThanOrEqualTo(260));
    // Its card's top at the top, as the modes show an ayah.
    final card = find.byKey(const ValueKey('ayah-mode-1004'));
    final position = Scrollable.of(tester.element(card)).position;
    expect(
      tester.getRect(card).top <= 40 ||
          position.pixels == position.maxScrollExtent,
      isTrue,
    );
    expect(changes, isEmpty, reason: 'still page 10');
  });

  testWidgets("continuous: listening, the reciter's ayah scrolled into view "
      'on the next page too', (tester) async {
    shortScreen(tester);
    final audio = FakeAudioController();
    await pump(tester, audio: audio);
    final player = container.read(quranAudioPlayerProvider.notifier);
    unawaited(player.playAyahs([1004]));
    await tester.pump();
    await tester.pumpAndSettle();
    var ayah = rectOf(tester, 'ayah-mode-1004');
    expect(ayah.top, inInclusiveRange(0, 130));
    unawaited(player.playAyahs([1006]));
    await tester.pump();
    await tester.pumpAndSettle();
    ayah = rectOf(tester, 'ayah-mode-1006');
    expect(ayah.top, inInclusiveRange(0, 130));
    unawaited(player.stop());
    await tester.pump(const Duration(seconds: 2));
  });

  for (final layout in AyahLayout.values) {
    testWidgets('${layout.name}: listening from an ayah on the page before '
        '(1:1 from page 10): turned to and scrolled to it', (tester) async {
      shortScreen(tester);
      final audio = FakeAudioController();
      await pump(tester, audio: audio, layout: layout);
      unawaited(
        container.read(quranAudioPlayerProvider.notifier).playAyahs([1001]),
      );
      await tester.pump();
      // The player turns to the ayah's page.
      container.read(mushafPageTurnRequestsProvider.notifier).toPage(9);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(changes.last, 9);
      final ayah = rectOf(tester, 'ayah-mode-1001');
      expect(ayah.top, inInclusiveRange(0, 130));
      unawaited(container.read(quranAudioPlayerProvider.notifier).stop());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('${layout.name}: revealing on the page before, after turning '
        'back to it: scrolled to the word shown', (tester) async {
      shortScreen(tester);
      await pump(tester, layout: layout);
      final hide = container.read(mushafHideModeProvider.notifier);
      hide.toggle();
      await tester.pumpAndSettle();
      container.read(mushafPageTurnRequestsProvider.notifier).toPage(9);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 4; i++) {
        hide.revealNextWord(9);
        await tester.pumpAndSettle();
      }
      final word = rectOf(tester, 'ayah-word-1002:1');
      expect(word.top, greaterThanOrEqualTo(0));
      expect(word.bottom, lessThanOrEqualTo(260));
      // Its card's top at the top — or as near as the page's end allows.
      final card = find.byKey(const ValueKey('ayah-mode-1002'));
      final position = Scrollable.of(tester.element(card)).position;
      expect(
        tester.getRect(card).top <= 40 ||
            position.pixels == position.maxScrollExtent,
        isTrue,
      );
    });

    testWidgets('${layout.name}: listening from an ayah far away (page 300 '
        'from page 10): turned to and scrolled to it', (tester) async {
      shortScreen(tester);
      final audio = FakeAudioController();
      await pump(tester, audio: audio, layout: layout);
      final player = container.read(quranAudioPlayerProvider.notifier);
      unawaited(player.playAyahs([78002, 78002]));
      await tester.pump();
      container.read(mushafPageTurnRequestsProvider.notifier).toPage(300);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(changes.last, 300);
      final ayah = rectOf(tester, 'ayah-mode-78002');
      expect(ayah.top, inInclusiveRange(0, 130));
      unawaited(container.read(quranAudioPlayerProvider.notifier).stop());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('${layout.name}: listening from the first page, from far '
        'down (page 1 from page 30)', (tester) async {
      shortScreen(tester);
      final audio = FakeAudioController();
      await pump(tester, audio: audio, layout: layout, initialPage: 30);
      final player = container.read(quranAudioPlayerProvider.notifier);
      unawaited(player.playAyahs([1001, 1001]));
      await tester.pump();
      container.read(mushafPageTurnRequestsProvider.notifier).toPage(1);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(changes.last, 1);
      final ayah = rectOf(tester, 'ayah-mode-1001');
      expect(ayah.top, inInclusiveRange(0, 130));
      unawaited(player.stop());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('continuous: a list laid out afresh (page 1) after reading far '
      "down another: at that page, not at the last list's place", (
    tester,
  ) async {
    shortScreen(tester);
    await pump(tester, initialPage: 1);
    final turns = container.read(mushafPageTurnRequestsProvider.notifier);
    turns.toPage(30);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    // Read on from there, far down.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    turns.toPage(1);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(changes.last, 1);
    expect(tester.getTopLeft(divider(1)).dy, inInclusiveRange(0, 100));
  });
  for (final layout in AyahLayout.values) {
    testWidgets('${layout.name}: read on from page 1 far down, then listening '
        'from 1:1: back at 1:1', (tester) async {
      shortScreen(tester);
      final audio = FakeAudioController();
      await pump(tester, audio: audio, layout: layout, initialPage: 1);
      final turns = container.read(mushafPageTurnRequestsProvider.notifier);
      // Down to page 5, by hand (continuous) or by turning (pages).
      if (layout == AyahLayout.continuous) {
        for (var i = 0; i < 4; i++) {
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
      } else {
        turns.toPage(5);
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
        }
      }
      expect(changes.last, greaterThanOrEqualTo(4));
      final player = container.read(quranAudioPlayerProvider.notifier);
      unawaited(player.playAyahs([1001, 1001]));
      await tester.pump();
      turns.toPage(1);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
      }
      expect(changes.last, 1);
      final ayah = rectOf(tester, 'ayah-mode-1001');
      expect(ayah.top, inInclusiveRange(0, 130));
      unawaited(player.stop());
      await tester.pump(const Duration(seconds: 2));
    });
  }

  testWidgets('a surah opened as the app starts: brought into view though '
      'the saved layout (continuous) arrives after the pages', (tester) async {
    shortScreen(tester);
    await pump(
      tester,
      layout: AyahLayout.paged,
      target: 1004,
      thenLayout: AyahLayout.continuous,
    );
    expect(find.byType(PageView), findsNothing);
    final card = rectOf(tester, 'ayah-mode-1004');
    final list = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(card.top - list, inInclusiveRange(0, 40));
  });

  testWidgets('an ayah asked for and another in focus on the same page: the '
      'one asked for brought into view, and no longer asked once shown', (
    tester,
  ) async {
    shortScreen(tester);
    await pump(tester, layout: AyahLayout.paged, target: 1004, focus: 1003);
    // Its card at the top — or as near as the page's end allows.
    final card = find.byKey(const ValueKey('ayah-mode-1004'));
    final position = Scrollable.of(tester.element(card)).position;
    final list = tester.getTopLeft(find.byType(SingleChildScrollView).first).dy;
    expect(
      tester.getRect(card).top - list <= 40 ||
          position.pixels == position.maxScrollExtent,
      isTrue,
    );
    // Settled: no longer asked (nothing left to pull the page back to it).
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(container.read(ayahModeTargetProvider), isNull);
  });
}
