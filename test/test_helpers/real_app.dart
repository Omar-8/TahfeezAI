import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/logging/logging_package_logger.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/app_typography.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_passages.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_quran_engine_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/mushaf/domain/quran_engine/quran_engine_mushaf_backend.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_token_hit_rect.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/features/settings/presentation/theme_choices.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/quran/data/import/bundled_dataset_seeder.dart';
import 'package:tahfeez_ai/quran/data/quran_database.dart';
import 'package:tahfeez_ai/quran/data/search_index_database.dart';
import 'package:tahfeez_ai/quran/data/tafsir_database.dart';
import 'package:tahfeez_ai/quran/data/translation_database.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';
import 'package:tahfeez_ai/quran/search_providers.dart';
import 'package:tahfeez_ai/quran/tafsir_providers.dart';
import 'package:tahfeez_ai/quran/translation_providers.dart';
import 'package:tahfeez_ai/wbw/data/wbw_database.dart';
import 'package:tahfeez_ai/wbw/wbw_providers.dart';

import 'empty_memorization_repository.dart';
import 'fake_audio_controller.dart';

/// The whole app as on a device, for tests that walk through it: the
/// app's own fonts, the bundled Quran, translations, tafsir and word
/// meanings seeded once ([prepare]), the printed page's native engine
/// stood in for by one serving the real pages' words.
class RealApp {
  RealApp._();

  static late QuranDatabase _quran;
  static late TranslationDatabase _translations;
  static late TafsirDatabase _tafsir;
  static late WbwDatabase _wbw;
  static late FakeEngineBackend _backend;

  /// Fonts loaded and the data seeded — once, in `setUpAll`.
  static Future<void> prepare() async {
    await loadAppFonts();
    _quran = QuranDatabase(NativeDatabase.memory());
    _translations = TranslationDatabase(NativeDatabase.memory());
    _tafsir = TafsirDatabase(NativeDatabase.memory());
    _wbw = WbwDatabase(NativeDatabase.memory());
    final seeding = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => _quran),
        translationDatabaseProvider.overrideWith((ref) => _translations),
        tafsirDatabaseProvider.overrideWith((ref) => _tafsir),
        wbwDatabaseProvider.overrideWith((ref) => _wbw),
      ],
    );
    await BundledDatasetSeeder(
      quranRepository: seeding.read(quranRepositoryProvider),
      quranDatabase: _quran,
      translationRepository: seeding.read(translationRepositoryProvider),
      tafsirRepository: seeding.read(tafsirRepositoryProvider),
      wbwRepository: seeding.read(wbwRepositoryProvider),
      logger: LoggingPackageLogger(),
      storage: seeding.read(browserStorageProvider),
    ).seedIfNeeded();
    final repository = seeding.read(quranRepositoryProvider);
    final mushaf = (await seeding.read(defaultMushafProvider.future))!;
    final script = seeding.read(quranScriptCodeProvider);
    _backend = FakeEngineBackend(
      await repository.getAyahPages(mushafId: mushaf.id),
      (ayahId) async => [
        for (final w in await repository.getWordsForAyah(
          ayahId,
          scriptCode: script,
        ))
          (ayahId: ayahId, wordIndex: w.wordIndex),
      ],
    );
    seeding.dispose();
  }

  /// In `tearDownAll`.
  static Future<void> close() async {
    await _quran.close();
    await _translations.close();
    await _tafsir.close();
    await _wbw.close();
  }

  /// The app started on [size] (logical pixels) in [locale], with the
  /// reader's and the app's choices as saved, at [route]. Returns its
  /// providers.
  static Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/home',
    Size size = const Size(390, 844),
    String locale = 'en',
    double textScale = 1.0,
    ReaderMode mode = ReaderMode.mushaf,
    AyahLayout layout = AyahLayout.paged,
    QuranFont quranFont = QuranFont.scheherazade,
    double ayahTextScale = 1.0,
    ArabicUiFont arabicFont = ArabicUiFont.kufi,
    MushafAppearance readerTheme = MushafAppearance.light,
    AppThemeChoice appTheme = AppThemeChoice.light,
    bool passages = false,
  }) async {
    recordErrors();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => _quran),
        translationDatabaseProvider.overrideWith((ref) => _translations),
        tafsirDatabaseProvider.overrideWith((ref) => _tafsir),
        wbwDatabaseProvider.overrideWith((ref) => _wbw),
        searchIndexDatabaseProvider.overrideWith((ref) {
          final db = SearchIndexDatabase(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        memorizationRepositoryProvider.overrideWithValue(
          const EmptyMemorizationRepository(),
        ),
        audioControllerProvider.overrideWith((ref) => FakeAudioController()),
        mushafQuranEngineBackendProvider.overrideWith((ref) async => _backend),
        localeControllerProvider.overrideWithBuild((ref, _) => Locale(locale)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(readerModeProvider.notifier).set(mode);
    await container
        .read(ayahViewPreferencesProvider.notifier)
        .set(
          AyahViewPreferences(
            layout: layout,
            showTranslation: true,
            showTransliteration: true,
            showTafsir: true,
            showWordMeanings: true,
            quranFont: quranFont,
          ),
        );
    await container
        .read(tafsirTextScaleControllerProvider.notifier)
        .setScale(ayahTextScale);
    await container
        .read(arabicFontControllerProvider.notifier)
        .setFont(arabicFont);
    await container
        .read(mushafAppearanceControllerProvider.notifier)
        .setAppearance(readerTheme);
    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(appTheme.mode);
    await container
        .read(appSurfaceToneProvider.notifier)
        .setTone(appTheme.tone);
    await container.read(mushafPassagesProvider.notifier).set(passages);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TahfeezApp(),
      ),
    );
    await settle(tester);
    if (route != '/home') {
      container.read(appRouterProvider).go(route);
      await settle(tester);
    }
    return container;
  }

  /// Closed, its timers run out — at a test's end.
  static Future<void> quit(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  static final _reported = <FlutterErrorDetails>[];

  /// Every error from here on kept, with the widget it came from.
  static void recordErrors() {
    _reported.clear();
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      _reported.add(details);
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Fails with what went wrong and where (the widget, the code), not only
  /// that it did. [ignore] lets through an error the test expects.
  static void fits(
    WidgetTester tester,
    String reason, {
    bool Function(Object error)? ignore,
  }) {
    final error = tester.takeException();
    if (error == null || (ignore?.call(error) ?? false)) return;
    final where = [
      for (final d in _reported)
        d.toString().split('\n').where((l) => l.contains('file:///')).take(3),
    ].expand((l) => l).toSet().join('\n');
    fail('$reason: $error\n$where');
  }

  /// Settled, data loaded (real time for the databases).
  static Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }
}

/// Every font the app bundles (`pubspec.yaml`'s `fonts:`), so text is
/// measured in the real typefaces rather than the test font.
Future<void> loadAppFonts() async {
  final lines = File('pubspec.yaml').readAsLinesSync();
  String? family;
  final assets = <String, List<String>>{};
  for (final line in lines) {
    final f = RegExp(r'^\s*- family:\s*(.+)$').firstMatch(line);
    if (f != null) family = f.group(1)!.trim();
    final a = RegExp(r'^\s*- asset:\s*(assets/fonts/\S+)$').firstMatch(line);
    if (a != null && family != null) {
      assets.putIfAbsent(family, () => []).add(a.group(1)!);
    }
  }
  for (final MapEntry(key: name, value: files) in assets.entries) {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
      );
    }
    await loader.load();
  }
}

/// The engine, stood in for: each page's ayahs (from the installed Mushaf's
/// page of every ayah) and their words, as the real one reports them.
class FakeEngineBackend implements QuranEngineMushafBackend {
  FakeEngineBackend(Map<int, int> ayahPages, this._words) {
    for (final MapEntry(key: ayah, value: page) in ayahPages.entries) {
      _ayahs.putIfAbsent(page, () => []).add(ayah);
    }
    for (final list in _ayahs.values) {
      list.sort();
    }
  }

  final Future<List<WordRef>> Function(int ayahId) _words;
  final _ayahs = <int, List<int>>{};

  @override
  Future<String> initialize() async => 'fake';

  @override
  Future<QuranEngineMushafPage> loadPage(int pageNumber) async {
    final words = <WordRef>[];
    final ends = <int>[];
    for (final ayah in _ayahs[pageNumber] ?? const <int>[]) {
      words.addAll(await _words(ayah));
      ends.add(words.length);
    }
    return FakePage(pageNumber, words, ends);
  }

  @override
  void disposePage(QuranEngineMushafPage page) {}

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

class FakePage implements QuranEngineMushafPage {
  FakePage(this.pageNumber, this.wordRefs, this.ayahWordBoundaries);

  @override
  final int pageNumber;
  @override
  final List<WordRef> wordRefs;
  @override
  final List<int> ayahWordBoundaries;

  @override
  int get wordCount => wordRefs.length;
  @override
  ({VerseRef first, VerseRef last})? get verseSpan => wordRefs.isEmpty
      ? null
      : (
          first: (
            chapterNo: wordRefs.first.ayahId ~/ 1000,
            verseNo: wordRefs.first.ayahId % 1000,
          ),
          last: (
            chapterNo: wordRefs.last.ayahId ~/ 1000,
            verseNo: wordRefs.last.ayahId % 1000,
          ),
        );
  @override
  double get aspectRatio => 0.62;

  @override
  Widget buildView({
    required Color ink,
    required Color paper,
    ValueChanged<MushafTokenHitRect>? onWordHit,
    ValueChanged<MushafTokenHitRect>? onDecorationHit,
    VoidCallback? onEmptyHit,
    ValueChanged<MushafTokenHitRect>? onWordLongHit,
  }) => ColoredBox(
    key: const ValueKey('printed-page'),
    color: paper,
    child: const SizedBox.expand(),
  );

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
