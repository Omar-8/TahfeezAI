import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_focus_ayah.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_passages.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/quran_engine_mushaf_page_content.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

class _MaskRecordingPage implements QuranEngineMushafPage {
  _MaskRecordingPage(this.pageNumber);

  @override
  final int pageNumber;
  final masks = <({bool hidden, int revealed})>[];
  ValueChanged<MushafTokenHitRect>? onWordHit;
  ValueChanged<MushafTokenHitRect>? onWordLongHit;
  final ayahHighlights = <VerseRef>[];

  @override
  int get wordCount => 3;

  @override
  List<int> get ayahWordBoundaries => const [2, 3];

  @override
  ({VerseRef first, VerseRef last})? get verseSpan => (
    first: (chapterNo: 2, verseNo: pageNumber),
    last: (chapterNo: 2, verseNo: pageNumber + 1),
  );

  @override
  List<WordRef> get wordRefs => [
    for (var i = 0; i < 3; i++) (ayahId: 2000 + pageNumber, wordIndex: i),
  ];

  final hiddenCalls = <Set<int>>[];
  final highlights = <(int, Color)>[];

  /// The seamless bands last drawn.
  final bands = <PageBand>[];

  @override
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights, {
    List<PageBand> bands = const [],
  }) {
    // Like the engine: every highlight replaced, the ayah's too.
    ayahHighlights.clear();
    this.highlights
      ..clear()
      ..addAll([for (final h in highlights) (h.word, h.color)]);
    this.bands
      ..clear()
      ..addAll(bands);
  }

  @override
  void setHiddenWords(Set<int> hidden) => hiddenCalls.add(hidden);

  @override
  int highlightWordAt(int wordIndex, {required Color color}) {
    highlights.add((wordIndex, color));
    return highlights.length;
  }

  @override
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) =>
      masks.add((hidden: hidden, revealed: revealedWords));

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
  }) {
    this.onWordHit = onWordHit;
    this.onWordLongHit = onWordLongHit;
    return const SizedBox.expand();
  }

  @override
  int highlightWord(WordRef target, {String mode = 'band'}) => 0;
  @override
  int highlightAyah(VerseRef target, {String mode = 'band'}) {
    ayahHighlights.add(target);
    return ayahHighlights.length;
  }

  @override
  void clearHighlights() {
    highlights.clear();
    ayahHighlights.clear();
  }

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
  final pages = <int, _MaskRecordingPage>{};
  @override
  Future<String> initialize() async => 'fake';
  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async =>
      pages[pageNumber] = _MaskRecordingPage(pageNumber);
  @override
  void disposePage(QuranEngineMushafPage page) {}
  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

void main() {
  group('MushafHideModeController', () {
    late ProviderContainer container;
    MushafHideModeController hide() =>
        container.read(mushafHideModeProvider.notifier);
    MushafHideModeState state() => container.read(mushafHideModeProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('reveals nothing until hide mode is on', () {
      hide().reportPageWords(42, wordCount: 3);
      expect(hide().revealNextWord(42), isNull);
      hide().toggle();
      expect(state().enabled, isTrue);
      expect(hide().revealNextWord(42), 42);
      expect(state().revealedOn(42), 1);
    });

    test('stops at the page word count', () {
      hide()
        ..reportPageWords(42, wordCount: 2)
        ..toggle();
      expect(hide().revealNextWord(42), 42);
      expect(hide().revealNextWord(42), 42);
      expect(state().fullyRevealed(42), isTrue);
      expect(hide().revealNextWord(42), isNull);
      expect(state().revealedOn(42), 2);
    });

    test('in a spread, continues onto the facing page', () {
      hide()
        ..reportPageWords(41, wordCount: 1)
        ..reportPageWords(42, wordCount: 5)
        ..toggle();
      expect(hide().revealNextWord(41, spread: true), 41);
      expect(hide().revealNextWord(41, spread: true), 42);
      expect(hide().revealNextWord(41), isNull, reason: 'single page view');
    });

    test('a spread always starts at its odd, right-hand page', () {
      expect(firstVisiblePage(2, spread: true), 1);
      expect(firstVisiblePage(1, spread: true), 1);
      expect(firstVisiblePage(43, spread: true), 43);
      expect(firstVisiblePage(2, spread: false), 2);
    });

    test('opening Al-Baqarah in a spread reveals page 1, then 2, never the '
        'off-screen page 3', () {
      hide()
        ..reportPageWords(1, wordCount: 2, ayahBoundaries: [2])
        ..reportPageWords(2, wordCount: 1, ayahBoundaries: [1])
        ..toggle();
      final first = firstVisiblePage(2, spread: true); // reported page: 2
      expect(hide().revealNextWord(first, spread: true), 1);
      expect(hide().revealNextWord(first, spread: true), 1);
      expect(hide().revealNextWord(first, spread: true), 2);
      expect(
        hide().revealNextWord(first, spread: true),
        isNull,
        reason: 'page 3 is not on screen: the bar turns the page instead',
      );
      expect(state().revealedOn(3), 0);
    });

    test('reveal ayah finishes the current ayah, then whole ayahs', () {
      hide()
        ..reportPageWords(42, wordCount: 10, ayahBoundaries: [3, 7, 10])
        ..toggle();
      expect(hide().revealNextAyah(42), 42);
      expect(state().revealedOn(42), 3);
      hide().revealNextWord(42);
      expect(state().revealedOn(42), 4);
      hide().revealNextAyah(42);
      expect(state().revealedOn(42), 7, reason: 'rest of the second ayah');
      hide().revealNextAyah(42);
      expect(state().fullyRevealed(42), isTrue);
      expect(hide().revealNextAyah(42), isNull);
    });

    test('reveal ayah continues onto the facing page in a spread', () {
      hide()
        ..reportPageWords(41, wordCount: 2, ayahBoundaries: [2])
        ..reportPageWords(42, wordCount: 5, ayahBoundaries: [4, 5])
        ..toggle();
      hide().revealNextAyah(41, spread: true);
      expect(hide().revealNextAyah(41, spread: true), 42);
      expect(state().revealedOn(42), 4);
    });

    test('hiding goes back by word and by ayah', () {
      hide()
        ..reportPageWords(42, wordCount: 10, ayahBoundaries: [3, 7, 10])
        ..toggle()
        ..revealNextAyah(42)
        ..revealNextWord(42)
        ..revealNextWord(42);
      expect(state().revealedOn(42), 5);
      expect(hide().hideLastWord(42), 42);
      expect(state().revealedOn(42), 4);
      hide().hideLastAyah(42);
      expect(state().revealedOn(42), 3, reason: 'back to the ayah start');
      hide().hideLastAyah(42);
      expect(state().revealedOn(42), 0, reason: 'whole previous ayah');
      expect(hide().hideLastWord(42), isNull);
      expect(hide().hideLastAyah(42), isNull);
    });

    test('in a spread, hiding starts from the facing page', () {
      hide()
        ..reportPageWords(41, wordCount: 2, ayahBoundaries: [2])
        ..reportPageWords(42, wordCount: 3, ayahBoundaries: [3])
        ..toggle()
        ..revealNextAyah(41, spread: true)
        ..revealNextWord(41, spread: true);
      expect(hide().hideLastWord(41, spread: true), 42);
      expect(hide().hideLastWord(41, spread: true), 41);
    });

    test('pages revealed fully before loading are clamped on report', () {
      hide()
        ..toggle()
        ..revealPagesFully([40, 41]);
      hide().reportPageWords(40, wordCount: 6, ayahBoundaries: [6]);
      expect(state().revealedOn(40), 6);
      expect(state().fullyRevealed(40), isTrue);
      expect(hide().hideLastWord(40), 40);
      expect(state().revealedOn(40), 5);
    });

    test('isWordHidden follows reveal progress', () {
      hide().reportPageWords(42, wordCount: 3);
      expect(state().isWordHidden(42, 0), isFalse, reason: 'mode off');
      hide().toggle();
      expect(state().isWordHidden(42, 0), isTrue);
      hide().revealNextWord(42);
      expect(state().isWordHidden(42, 0), isFalse);
      expect(state().isWordHidden(42, 1), isTrue);
    });

    test('toggling starts every page hidden again', () {
      hide()
        ..reportPageWords(42, wordCount: 3)
        ..toggle()
        ..revealNextWord(42)
        ..toggle();
      expect(state().enabled, isFalse);
      hide().toggle();
      expect(state().revealedOn(42), 0);
      expect(state().wordCounts[42], 3, reason: 'word counts are kept');
    });
  });

  testWidgets('each page applies only its own hide state', (tester) async {
    final backend = _Backend();
    late WidgetRef widgetRef;
    const colors = MushafAppearanceColors(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF000000),
      secondaryText: Color(0xFF888888),
      headerInk: Color(0xFF000000),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const Row(
                children: [
                  Expanded(
                    child: QuranEngineMushafPageContent(
                      pageNumber: 41,
                      colors: colors,
                    ),
                  ),
                  Expanded(
                    child: QuranEngineMushafPageContent(
                      pageNumber: 42,
                      colors: colors,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p41 = backend.pages[41]!, p42 = backend.pages[42]!;
    expect(p41.masks, isEmpty, reason: 'never masked, nothing to undo');
    expect(widgetRef.read(mushafHideModeProvider).wordCounts, {41: 3, 42: 3});
    expect(widgetRef.read(mushafHideModeProvider).ayahBoundaries[42], [2, 3]);

    final hide = widgetRef.read(mushafHideModeProvider.notifier);
    hide.toggle();
    await tester.pump();
    expect(p41.masks, [(hidden: true, revealed: 0)]);
    expect(p42.masks, [(hidden: true, revealed: 0)]);

    hide.revealNextWord(42);
    await tester.pump();
    expect(p42.masks.last, (hidden: true, revealed: 1));
    expect(p41.masks, hasLength(1), reason: 'page 41 unchanged');

    hide.toggle();
    await tester.pump();
    expect(p41.masks.last, (hidden: false, revealed: 0));
    expect(p42.masks.last, (hidden: false, revealed: 0));
  });

  testWidgets('thematic passages: tinted, with the blue ayah drawn instead', (
    tester,
  ) async {
    final backend = _Backend();
    const tint = Color(0x3326A69A);
    final container = ProviderContainer(
      overrides: [
        mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        mushafPassagesProvider.overrideWith(_PassagesOn.new),
        passageColorsProvider.overrideWith((ref) async => {2042: tint}),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: QuranEngineMushafPageContent(
            pageNumber: 42,
            colors: MushafAppearanceColors(
              background: Color(0xFFFFFFFF),
              text: Color(0xFF000000),
              secondaryText: Color(0xFF888888),
              headerInk: Color(0xFF000000),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = backend.pages[42]!;
    expect(page.highlights, isEmpty);
    expect(
      [for (final b in page.bands) (b.surah, b.fromAyah, b.toAyah, b.color)],
      [(2, 42, 42, tint)],
      reason: 'the whole ayah as one band, not one per word',
    );

    final owner = Object();
    container.read(mushafFocusAyahProvider.notifier).focus(owner, 2042);
    await tester.pump();
    expect(page.bands, isEmpty, reason: 'the blue ayah instead');
    expect(page.ayahHighlights, [(chapterNo: 2, verseNo: 42)]);

    container.read(mushafFocusAyahProvider.notifier).clear(owner);
    await tester.pump();
    expect(page.bands, hasLength(1));
    expect(page.ayahHighlights, isEmpty);

    // Hide mode: no passage colours over the hidden words.
    container.read(mushafHideModeProvider.notifier).toggle();
    await tester.pump();
    expect(page.bands, isEmpty);
    container.read(mushafHideModeProvider.notifier).toggle();
    await tester.pump();
    expect(page.bands, hasLength(1));
  });

  testWidgets('a long-pressed word\'s ayah stays highlighted while its '
      'sheet is open', (tester) async {
    final backend = _Backend();
    final sheet = Completer<void>();
    final pressed = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
        child: MaterialApp(
          home: QuranEngineMushafPageContent(
            pageNumber: 42,
            colors: const MushafAppearanceColors(
              background: Color(0xFFFFFFFF),
              text: Color(0xFF000000),
              secondaryText: Color(0xFF888888),
              headerInk: Color(0xFF000000),
            ),
            onWordTap: (_) {},
            onWordLongPress: (hit) {
              pressed.add(hit.canonicalAyahId!);
              return sheet.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = backend.pages[42]!;
    page.onWordLongHit!(
      const MushafTokenHitRect(
        rect: Rect.zero,
        sourceTokenId: 1,
        tokenType: MushafTokenType.quranWord,
        canonicalAyahId: 2042,
        canonicalWordIndex: 1,
        text: '',
      ),
    );
    await tester.pump();
    expect(pressed, [2042]);
    expect(page.ayahHighlights, [(chapterNo: 2, verseNo: 42)]);

    sheet.complete();
    await tester.pumpAndSettle();
    expect(page.ayahHighlights, isEmpty, reason: 'the sheet was closed');
  });

  testWidgets('tapping a hidden word does not open its word sheet', (
    tester,
  ) async {
    final backend = _Backend();
    final taps = <int>[];
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return QuranEngineMushafPageContent(
                pageNumber: 42,
                colors: const MushafAppearanceColors(
                  background: Color(0xFFFFFFFF),
                  text: Color(0xFF000000),
                  secondaryText: Color(0xFF888888),
                  headerInk: Color(0xFF000000),
                ),
                onWordTap: (hit) => taps.add(hit.sourceTokenId),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = backend.pages[42]!;
    MushafTokenHitRect hit(int word) => MushafTokenHitRect(
      rect: Rect.zero,
      sourceTokenId: word,
      tokenType: MushafTokenType.quranWord,
      canonicalAyahId: 1,
      canonicalWordIndex: word + 1,
      text: '',
    );

    page.onWordHit!(hit(0));
    expect(taps, [0], reason: 'hide mode off');

    final hide = widgetRef.read(mushafHideModeProvider.notifier);
    hide.toggle();
    await tester.pump();
    page.onWordHit!(hit(0));
    page.onWordHit!(hit(2));
    expect(taps, [0], reason: 'hidden words ignore taps');

    hide.revealNextWord(42);
    await tester.pump();
    page.onWordHit!(hit(0));
    page.onWordHit!(hit(1));
    expect(taps, [0, 0], reason: 'only the revealed word responds');
  });

  testWidgets('a word overlay (Hifz) hides and marks words on its pages, '
      'and gives way to hide mode when cleared', (tester) async {
    final backend = _Backend();
    late WidgetRef widgetRef;
    const colors = MushafAppearanceColors(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF000000),
      secondaryText: Color(0xFF888888),
      headerInk: Color(0xFF000000),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const Row(
                children: [
                  Expanded(
                    child: QuranEngineMushafPageContent(
                      pageNumber: 41,
                      colors: colors,
                    ),
                  ),
                  Expanded(
                    child: QuranEngineMushafPageContent(
                      pageNumber: 42,
                      colors: colors,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final p41 = backend.pages[41]!, p42 = backend.pages[42]!;

    // Range 2:41 word 1 – 2:41 word 3, first word revealed, next marked.
    widgetRef
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: (ayahId: 2041, wordIndex: 0),
            last: (ayahId: 2041, wordIndex: 2),
            revealed: {(ayahId: 2041, wordIndex: 0)},
            marks: {(ayahId: 2041, wordIndex: 1): MushafWordMark.current},
          ),
        );
    await tester.pump();
    expect(p41.hiddenCalls.last, {1, 2});
    expect(p41.highlights.map((h) => h.$1), [1]);
    expect(p42.hiddenCalls.last, {
      0,
      1,
      2,
    }, reason: 'hiding covers every page, not only the range');

    widgetRef.read(mushafWordOverlayProvider.notifier).set(null);
    await tester.pump();
    expect(p41.hiddenCalls.last, isEmpty);
    expect(p41.highlights, isEmpty);
  });
}

class _PassagesOn extends MushafPassagesController {
  @override
  bool build() => true;
}
