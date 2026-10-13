import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_turn.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_pager.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/data/import/quran_dataset_importer.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

import '../../../quran/quran_test_fixtures.dart';

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

/// Ayah mode in one continuous scroll.
class _ContinuousView extends AyahViewPreferencesController {
  @override
  AyahViewPreferences build() => const AyahViewPreferences(
    layout: AyahLayout.continuous,
    showTranslation: false,
  );
}

void main() {
  late ProviderContainer container;
  late List<int> changes;

  Future<void> pump(WidgetTester tester) async {
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
      ],
    );
    addTearDown(container.dispose);
    container.read(readerModeProvider);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
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
              initialPageNumber: 10,
              onPageChanged: changes.add,
            ),
          ),
        ),
      ),
    );
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
    expect(tester.getTopLeft(divider(10)).dy, lessThan(100));
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
    expect(tester.getTopLeft(divider(11)).dy, lessThan(100));

    container.read(mushafPageTurnRequestsProvider.notifier).toPage(300);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
    expect(changes.last, 300);
    expect(tester.getTopLeft(divider(300)).dy, lessThan(100));
  });
}
