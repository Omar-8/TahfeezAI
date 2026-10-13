import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_page_view.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/reader_mode_toggle.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

/// Page 2: ayahs 1:2 and 1:3, two words each (the synthetic dataset's).
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
  @override
  List<WordRef> get wordRefs => const [
    (ayahId: 1002, wordIndex: 0),
    (ayahId: 1002, wordIndex: 1),
    (ayahId: 1003, wordIndex: 0),
    (ayahId: 1003, wordIndex: 1),
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

/// Only the Arabic under test (no translation database needed).
class _PlainView extends AyahViewPreferencesController {
  @override
  AyahViewPreferences build() =>
      const AyahViewPreferences(showTranslation: false);
}

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    ReaderMode mode = ReaderMode.mushaf,
  }) async {
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
        ayahViewPreferencesProvider.overrideWith(_PlainView.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(readerModeProvider);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    // Saved between tests: each sets its own.
    await container.read(readerModeProvider.notifier).set(mode);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const [ReaderModeToggle()]),
            body: const MushafPageView(mushafId: 1, pageNumber: 2),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Color? inkOf(WidgetTester tester, int ayahId, int wordIndex) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey('ayah-word-$ayahId:$wordIndex')),
        matching: find.byType(Text),
      ),
    );
    return text.style?.color;
  }

  testWidgets('Ayah mode: the page ayah by ayah, its words reported as the '
      'printed page reports them', (tester) async {
    await pump(tester, mode: ReaderMode.ayah);
    expect(find.byKey(const ValueKey('printed-page')), findsNothing);
    expect(find.byKey(const ValueKey('ayah-mode-1002')), findsOneWidget);
    expect(find.byKey(const ValueKey('ayah-mode-1003')), findsOneWidget);
    expect(find.text('lafz'), findsNWidgets(2));
    final hide = container.read(mushafHideModeProvider);
    expect(hide.wordCounts[2], 4);
    expect(hide.ayahBoundaries[2], [2, 4]);
  });

  testWidgets('hide mode: the words not yet revealed hidden, in place', (
    tester,
  ) async {
    await pump(tester, mode: ReaderMode.ayah);
    final hide = container.read(mushafHideModeProvider.notifier);
    hide.toggle();
    await tester.pumpAndSettle();
    expect(inkOf(tester, 1002, 0), Colors.transparent);
    hide.revealNextWord(2);
    await tester.pumpAndSettle();
    expect(inkOf(tester, 1002, 0), isNot(Colors.transparent));
    expect(inkOf(tester, 1002, 1), Colors.transparent);
  });

  testWidgets("a recitation's marks: recited words inked by how they went", (
    tester,
  ) async {
    await pump(tester, mode: ReaderMode.ayah);
    container
        .read(mushafWordOverlayProvider.notifier)
        .set(
          const MushafWordOverlay(
            first: (ayahId: 1002, wordIndex: 0),
            last: (ayahId: 1003, wordIndex: 1),
            revealed: {
              (ayahId: 1002, wordIndex: 0),
              (ayahId: 1002, wordIndex: 1),
            },
            marks: {
              (ayahId: 1002, wordIndex: 0): MushafWordMark.correct,
              (ayahId: 1002, wordIndex: 1): MushafWordMark.wrong,
            },
          ),
        );
    await tester.pumpAndSettle();
    expect(inkOf(tester, 1002, 0), const Color(0xFF43A047));
    expect(inkOf(tester, 1002, 1), const Color(0xFFD32F2F));
    expect(inkOf(tester, 1003, 0), Colors.transparent, reason: 'not reached');
  });

  testWidgets('the top bar toggles the printed page and Ayah mode', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('printed-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reader-mode-toggle')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ayah-mode-1002')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reader-mode-toggle')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('printed-page')), findsOneWidget);
  });
}
