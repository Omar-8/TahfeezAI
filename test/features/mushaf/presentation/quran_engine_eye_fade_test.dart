// The eye hiding and showing a whole page's ayahs: its words fade out into
// the paper and back in — with a recitation's colours kept on the page or
// not (owner, 2026-11-09: the fade had gone, the page's words cut at once).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/quran_engine_mushaf_page_content.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

/// More words than an ayah or two: a whole page.
const _words = 100;

class _Page implements QuranEngineMushafPage, MushafWordEffectsPage {
  @override
  int get pageNumber => 42;

  /// The words drawn hidden now (whichever way they were hidden).
  Set<int> hidden = {};
  final effects = <(int, MushafWordEffect)>[];

  Set<int> played(MushafWordEffect effect) => {
    for (final (i, e) in effects)
      if (e == effect) i,
  };

  @override
  void playWordEffect(
    int wordIndex,
    MushafWordEffect effect, {
    Color? color,
    Duration delay = Duration.zero,
    bool halo = true,
    bool letters = true,
  }) => effects.add((wordIndex, effect));

  @override
  void setHiddenWords(Set<int> hidden) => this.hidden = {...hidden};

  @override
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) =>
      this.hidden = {
        if (hidden)
          for (var i = revealedWords; i < _words; i++) i,
      };

  @override
  int get wordCount => _words;
  @override
  List<int> get ayahWordBoundaries => const [50, _words];
  @override
  ({VerseRef first, VerseRef last})? get verseSpan =>
      (first: (chapterNo: 2, verseNo: 42), last: (chapterNo: 2, verseNo: 43));
  @override
  List<WordRef> get wordRefs => [
    for (var i = 0; i < _words; i++)
      (ayahId: i < 50 ? 2042 : 2043, wordIndex: i < 50 ? i : i - 50),
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
    String? Function(WordRef word)? hoverHint,
  }) => const SizedBox.expand();
  @override
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights, {
    List<PageBand> bands = const [],
  }) {}
  @override
  int highlightWordAt(int wordIndex, {required Color color}) => 0;
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
  void unmask() => hidden = {};
  @override
  void dispose() {}
}

class _Backend implements QuranEngineMushafBackend {
  final page = _Page();
  @override
  Future<String> initialize() async => 'fake';
  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async => page;
  @override
  void disposePage(QuranEngineMushafPage page) {}
  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

void main() {
  final all = {for (var i = 0; i < _words; i++) i};

  Future<(_Page, ProviderContainer)> open(WidgetTester tester) async {
    final backend = _Backend();
    final container = ProviderContainer(
      overrides: [
        mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
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
    return (backend.page, container);
  }

  /// The eye's taps, as the bar's button makes them: colours on → off →
  /// ayahs hidden (in colour) → shown (in colour).
  void tapEye(ProviderContainer container) {
    final hide = container.read(mushafHideModeProvider);
    final colours = container.read(mushafColoursShownProvider.notifier);
    if (!hide.enabled && container.read(mushafColoursShownProvider)) {
      colours.set(false);
      return;
    }
    container.read(mushafHideModeProvider.notifier).toggle();
    colours.set(true);
  }

  Future<void> expectFade(
    WidgetTester tester,
    _Page page,
    MushafWordEffect effect, {
    required Set<int> hiddenAfter,
  }) async {
    await tester.pump();
    expect(
      page.played(effect),
      all,
      reason: 'every word on the page ${effect.name}',
    );
    if (effect == MushafWordEffect.inkOut) {
      expect(page.hidden, isEmpty, reason: 'drawn until faded out');
    }
    await tester.pump(MushafWordEffect.inkOutTime);
    expect(page.hidden, hiddenAfter);
    page.effects.clear();
  }

  testWidgets('no colours on the page: the ayahs fade out and back in', (
    tester,
  ) async {
    final (page, container) = await open(tester);
    container.read(mushafColoursShownProvider.notifier).set(false);
    await tester.pump();
    page.effects.clear();

    tapEye(container);
    await expectFade(tester, page, MushafWordEffect.inkOut, hiddenAfter: all);
    tapEye(container);
    await expectFade(tester, page, MushafWordEffect.inkIn, hiddenAfter: {});
  });

  testWidgets('a recitation\'s colours kept on the page: the eye\'s three '
      'states — the ayahs fade out and back in', (tester) async {
    final (page, container) = await open(tester);
    const word = (ayahId: 2042, wordIndex: 3);
    container
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: word,
            last: word,
            marks: {word: MushafWordMark.correct},
            hideUnrevealed: false,
            followHideMode: true,
          ),
        );
    await tester.pump();
    expect(container.read(mushafWordOverlayProvider), isNotNull);
    page.effects.clear();

    tapEye(container); // colours off: nothing hidden
    await tester.pump(MushafWordEffect.inkOutTime);
    expect(page.hidden, isEmpty);
    page.effects.clear();

    tapEye(container); // the ayahs hidden (the colours on again)
    await expectFade(tester, page, MushafWordEffect.inkOut, hiddenAfter: all);

    tapEye(container); // shown again
    await expectFade(tester, page, MushafWordEffect.inkIn, hiddenAfter: {});
  });

  testWidgets('a page loaded: its first frame drawn barely there, then '
      'faded in', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
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
    double opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byType(SizedBox).last,
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    // Loaded: its first frame, painted but unseen (its cost not a jump in
    // what shows).
    await tester.pump();
    await tester.pump();
    expect(opacity(), inExclusiveRange(0.0, 0.05));
    // Then fading in.
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacity(), inExclusiveRange(0.05, 1.0));
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });
}
