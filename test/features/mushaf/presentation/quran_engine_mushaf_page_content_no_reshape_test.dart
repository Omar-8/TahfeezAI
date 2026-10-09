// Verifies QuranEngineMushafPageContent passes its own box straight
// through to QuranEngineMushafPage.buildView() unmodified -- no
// AspectRatio/FittedBox (or anything else) pre-shapes, crops, or
// constrains it first. Both platform backends (QvpPageView on Android,
// the canvas view on Web) already compute their own uniform fit-to-box
// scale and centering internally, using whatever raw box they're given;
// a wrapper here would only get in the way of that (see this widget's
// own doc comments, and quran_engine_android_backend.dart's
// maxAspectSlack patch notes, for the history of why that used to not be
// true).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/quran_engine_mushaf_page_content.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

BoxConstraints? _observedConstraints;

class _FakePage implements QuranEngineMushafPage {
  @override
  int pageNumber = 1;

  // The real measured page ratio (345/550) -- deliberately irrelevant to
  // this test's assertion (this widget must no longer consult it to
  // shape the box), but kept realistic rather than an arbitrary value.
  @override
  double get aspectRatio => 345 / 550;

  @override
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _observedConstraints = constraints;
        return ColoredBox(color: paper);
      },
    );
  }

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
  void setMemorizationMask({required bool hidden, int revealedWords = 0}) {}

  @override
  int get wordCount => 0;

  @override
  List<int> get ayahWordBoundaries => const [];

  @override
  ({VerseRef first, VerseRef last})? get verseSpan => null;

  @override
  List<WordRef> get wordRefs => const [];

  @override
  void setWordHighlights(
    List<({int word, Color color, bool ink})> highlights,
  ) {}

  @override
  void setHiddenWords(Set<int> hidden) {}

  @override
  int highlightWordAt(int wordIndex, {required Color color}) => 0;
  @override
  void dispose() {}
}

class _FakeBackend implements QuranEngineMushafBackend {
  @override
  Future<String> initialize() async => 'fake';
  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async => _FakePage();
  @override
  void disposePage(QuranEngineMushafPage page) {}
  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

void main() {
  testWidgets('QuranEngineMushafPageContent hands its exact box to buildView() '
      'unmodified, for a box shaped nothing like the page itself', (
    tester,
  ) async {
    _observedConstraints = null;
    final backend = _FakeBackend();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                // Deliberately mismatched vs the page's own 345/550
                // ratio -- if anything upstream of buildView() still
                // reshaped the box (AspectRatio/FittedBox/etc.), this
                // exact (400, 250) rectangle would not reach it intact.
                width: 400,
                height: 250,
                child: QuranEngineMushafPageContent(
                  pageNumber: 1,
                  colors: const MushafAppearanceColors(
                    background: Color(0xFFFFFFFF),
                    text: Color(0xFF000000),
                    secondaryText: Color(0xFF888888),
                    headerInk: Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final constraints = _observedConstraints;
    expect(constraints, isNotNull);
    expect(constraints!.maxWidth, closeTo(400, 0.5));
    expect(constraints.maxHeight, closeTo(250, 0.5));
  });
}
