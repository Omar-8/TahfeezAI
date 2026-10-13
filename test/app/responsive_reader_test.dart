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
import 'package:tahfeez_ai/features/listen/presentation/follow_along_sheet.dart';
import 'package:tahfeez_ai/features/listen/presentation/listen_sheet.dart';
import 'package:tahfeez_ai/features/memorize/presentation/mark_known_sheet.dart';
import 'package:tahfeez_ai/features/memorize/presentation/plan_sheet.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_ayah_sheet.dart';
import 'package:tahfeez_ai/features/quran/presentation/go_to_ayah_sheet.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_loop_sheet.dart';
import 'package:tahfeez_ai/features/search/presentation/widgets/search_filter_sheet.dart';
import 'package:tahfeez_ai/quran/presentation/quick_reference_sheet.dart';
import 'package:tahfeez_ai/quran/presentation/tafsir_packs_sheet.dart';
import 'package:tahfeez_ai/quran/presentation/translation_packs_sheet.dart';
import 'package:tahfeez_ai/wbw/presentation/wbw_packs_sheet.dart';
import 'package:tahfeez_ai/wbw/presentation/word_detail_sheet.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
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

import '../test_helpers/empty_memorization_repository.dart';
import '../test_helpers/fake_audio_controller.dart';

/// The reader — the printed page's frame and Ayah mode in both layouts —
/// on every screen size, portrait and landscape, in every UI language, at
/// normal to Android's largest text, through every Quran font, Ayah mode
/// text size, Arabic font, reader and app theme, with passage tints, the
/// ayah highlighted and hide mode: laid out without overflow, scrolled
/// through, its view settings opened.
///
/// Real text, measured as on a device: the app's own fonts are loaded and
/// the bundled Quran, translations, tafsir and word meanings seeded (the
/// printed page itself is the native engine's, stood in for here).
void main() {
  late QuranDatabase quranDb;
  late TranslationDatabase translationDb;
  late TafsirDatabase tafsirDb;
  late WbwDatabase wbwDb;
  late _Backend backend;

  setUpAll(() async {
    await _loadAppFonts();
    quranDb = QuranDatabase(NativeDatabase.memory());
    translationDb = TranslationDatabase(NativeDatabase.memory());
    tafsirDb = TafsirDatabase(NativeDatabase.memory());
    wbwDb = WbwDatabase(NativeDatabase.memory());
    final seeding = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => quranDb),
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        tafsirDatabaseProvider.overrideWith((ref) => tafsirDb),
        wbwDatabaseProvider.overrideWith((ref) => wbwDb),
      ],
    );
    await BundledDatasetSeeder(
      quranRepository: seeding.read(quranRepositoryProvider),
      quranDatabase: quranDb,
      translationRepository: seeding.read(translationRepositoryProvider),
      tafsirRepository: seeding.read(tafsirRepositoryProvider),
      wbwRepository: seeding.read(wbwRepositoryProvider),
      logger: LoggingPackageLogger(),
      storage: seeding.read(browserStorageProvider),
    ).seedIfNeeded();
    final repository = seeding.read(quranRepositoryProvider);
    final mushaf = (await seeding.read(defaultMushafProvider.future))!;
    backend = _Backend(
      await repository.getAyahPages(mushafId: mushaf.id),
      (ayahId) async => [
        for (final w in await repository.getWordsForAyah(
          ayahId,
          scriptCode: seeding.read(quranScriptCodeProvider),
        ))
          (ayahId: ayahId, wordIndex: w.wordIndex),
      ],
    );
    seeding.dispose();
  });

  tearDownAll(() async {
    await quranDb.close();
    await translationDb.close();
    await tafsirDb.close();
    await wbwDb.close();
  });

  final reported = <FlutterErrorDetails>[];
  void recordErrors() {
    reported.clear();
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      reported.add(details);
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// Fails with what overflowed (the widget, where), not only that it did.
  void fits(WidgetTester tester, String reason) {
    final error = tester.takeException();
    if (error == null) return;
    final where = [
      for (final d in reported)
        d.toString().split('\n').where((l) => l.contains('file:///')).take(2),
    ].expand((l) => l).toSet().join('\n');
    fail('$reason: $error\n$where');
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> reader(
    WidgetTester tester, {
    required String route,
    required Size size,
    required String locale,
    required double textScale,
    required ReaderMode mode,
    AyahLayout layout = AyahLayout.paged,
    QuranFont quranFont = QuranFont.scheherazade,
    double ayahTextScale = 1.0,
    ArabicUiFont arabicFont = ArabicUiFont.kufi,
    MushafAppearance readerTheme = MushafAppearance.light,
    AppThemeChoice appTheme = AppThemeChoice.light,
    bool passages = false,
    bool hide = false,
    bool viewSettings = true,
    void Function(BuildContext context)? sheet,
  }) async {
    recordErrors();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = ProviderContainer(
      overrides: [
        quranDatabaseProvider.overrideWith((ref) => quranDb),
        translationDatabaseProvider.overrideWith((ref) => translationDb),
        tafsirDatabaseProvider.overrideWith((ref) => tafsirDb),
        wbwDatabaseProvider.overrideWith((ref) => wbwDb),
        searchIndexDatabaseProvider.overrideWith((ref) {
          final db = SearchIndexDatabase(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        memorizationRepositoryProvider.overrideWithValue(
          const EmptyMemorizationRepository(),
        ),
        audioControllerProvider.overrideWith((ref) => FakeAudioController()),
        mushafQuranEngineBackendProvider.overrideWith((ref) async => backend),
        localeControllerProvider.overrideWithBuild((ref, _) => Locale(locale)),
      ],
    );
    addTearDown(container.dispose);
    // The reader's choices, as saved.
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
    // An ayah opened at is highlighted too.
    container.read(appRouterProvider).go(route);
    await settle(tester);
    if (hide) {
      container.read(mushafHideModeProvider.notifier).toggle();
      await settle(tester);
    }
    fits(tester, 'opens');

    // Through the page: down every vertical list on screen.
    final scrollables = find.byType(Scrollable);
    for (var i = 0; i < scrollables.evaluate().length; i++) {
      final s = scrollables.at(i);
      final state = tester.state<ScrollableState>(s);
      if (state.position.axis != Axis.vertical) continue;
      for (
        var n = 0;
        n < 12 && state.position.pixels < state.position.maxScrollExtent;
        n++
      ) {
        await tester.drag(
          s,
          Offset(0, -size.height * 0.6),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }
      fits(tester, 'scrolled');
    }

    // A sheet over it — or its view settings (Ayah mode's options among
    // them) — through to its end.
    if (sheet != null || viewSettings) {
      if (sheet != null) {
        sheet(tester.element(find.byType(Scaffold).last));
      } else {
        await tester.tap(find.byIcon(Icons.tune).first);
      }
      await settle(tester);
      fits(tester, 'sheet opens');
      final list = find.byType(Scrollable).last;
      for (var n = 0; n < 8; n++) {
        await tester.drag(list, const Offset(0, -300), warnIfMissed: false);
        await tester.pumpAndSettle();
      }
      fits(tester, 'sheet scrolled');
    }
    // Closed, its timers run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  // Portrait and landscape, a foldable's cover screen up to a desktop.
  const portrait = {
    'narrow phone': Size(280, 653),
    'small phone': Size(320, 568),
    'android phone': Size(360, 640),
    'phone': Size(390, 844),
    'large phone': Size(430, 932),
    'small tablet': Size(600, 960),
    'tablet': Size(800, 1280),
    'large tablet': Size(1024, 1366),
  };
  final sizes = <String, Size>{
    for (final MapEntry(key: name, value: size) in portrait.entries) ...{
      name: size,
      '$name landscape': Size(size.height, size.width),
    },
    'desktop': const Size(1440, 900),
    'large desktop': const Size(1920, 1080),
  };
  const locales = ['en', 'ar', 'de', 'fr', 'tr', 'ur'];
  // Long (2:282, the longest ayah), medium (Ya-Sin's start, after a
  // surah's end) and short ayahs (page 604: three surahs, their headers).
  const pages = {
    'long ayah': '/quran/ayah/2/282',
    'medium ayahs': '/quran/surah/36',
    'short ayahs': '/quran/surah/112',
  };
  const modes = {
    'Mushaf': (ReaderMode.mushaf, AyahLayout.paged),
    'Ayah mode': (ReaderMode.ayah, AyahLayout.paged),
    'Ayah mode continuous': (ReaderMode.ayah, AyahLayout.continuous),
  };

  // The whole matrix (some 3,500 runs, about an hour) with
  // `tool/test_responsive_all.sh`, in shards — never as one process (each
  // reader run keeps memory until the process ends); otherwise a part of it
  // on every test run: the sizes most likely to break, a language each in
  // turn.
  final all = Platform.environment['TAHFEEZ_RESPONSIVE'] == 'all';
  const everyRun = {
    'narrow phone',
    'small phone',
    'phone landscape',
    'tablet landscape',
  };

  // Every combination of size, language, mode and page; the rest taken in
  // turn, so each value meets every size and language.
  var n = 0;
  var turn = 0;
  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    if (!all && !everyRun.contains(sizeName)) continue;
    for (final locale in all ? locales : [locales[turn++ % locales.length]]) {
      for (final MapEntry(key: modeName, value: (mode, layout))
          in modes.entries) {
        for (final MapEntry(key: pageName, value: route) in pages.entries) {
          final i = n++;
          final textScale = const [1.0, 1.5, 2.0][i % 3];
          final quranFont = QuranFont.values[i % QuranFont.values.length];
          final ayahScale = const [0.8, 1.0, 1.5, 2.0][(i ~/ 3) % 4];
          final arabicFont =
              ArabicUiFont.values[(i ~/ 2) % ArabicUiFont.values.length];
          final readerTheme =
              MushafAppearance.values[i % MushafAppearance.values.length];
          final appTheme =
              AppThemeChoice.values[(i ~/ 5) % AppThemeChoice.values.length];
          final passages = i.isEven;
          final hide = i % 4 == 1;
          testWidgets(
            '$sizeName, $locale, $modeName, $pageName — text ×$textScale, '
            '${quranFont.name}, Ayah text ×$ayahScale, ${arabicFont.name}, '
            '${readerTheme.name} page, ${appTheme.name} app'
            '${passages ? ', passages' : ''}${hide ? ', hidden' : ''}',
            (tester) => reader(
              tester,
              route: route,
              size: size,
              locale: locale,
              textScale: textScale,
              mode: mode,
              layout: layout,
              quranFont: quranFont,
              ayahTextScale: ayahScale,
              arabicFont: arabicFont,
              readerTheme: readerTheme,
              appTheme: appTheme,
              passages: passages,
              hide: hide,
            ),
          );
        }
      }
    }
  }

  // Every main screen, with the Quran and its translations installed (an
  // empty install shows little), in every language in turn.
  const screens = [
    '/home',
    '/quran',
    '/quran/bookmarks',
    '/memorize',
    '/memorize/progress',
    '/settings',
    '/settings/about',
  ];
  var s = 0;
  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    if (!all && !everyRun.contains(sizeName)) continue;
    for (final route in screens) {
      for (final locale in all ? locales : [locales[s % locales.length]]) {
        final i = s++;
        final textScale = const [2.0, 1.0, 1.5][i % 3];
        final arabicFont = ArabicUiFont.values[i % ArabicUiFont.values.length];
        final appTheme =
            AppThemeChoice.values[i % AppThemeChoice.values.length];
        testWidgets(
          '$sizeName, $locale, $route — text ×$textScale, '
          '${arabicFont.name}, ${appTheme.name} app',
          (tester) => reader(
            tester,
            route: route,
            size: size,
            locale: locale,
            textScale: textScale,
            mode: ReaderMode.mushaf,
            arabicFont: arabicFont,
            appTheme: appTheme,
            viewSettings: false,
          ),
        );
      }
    }
  }

  // Every sheet, over the reader (2:282), at large text.
  final sheets = <String, void Function(BuildContext)>{
    'listen': (c) => showListenSheet(c),
    'reciter': (c) => showReciterSheet(c),
    'follow along': (c) => showFollowAlongSheet(c),
    'loop': (c) => showRecitationLoopSheet(c),
    'hifz settings': (c) => showHifzSettingsSheet(c),
    'ayah': (c) =>
        showAyahDetailSheet(c, mushafId: 1, pageNumber: 48, ayahId: 2282),
    'word': (c) =>
        showWordDetailSheet(c, wordRef: (ayahId: 2282, wordIndex: 0)),
    'quick reference': (c) =>
        showQuickReferenceSheet(c, (chapterNo: 2, verseNo: 255)),
    'translations': showTranslationPacksSheet,
    'tafsir': showTafsirPacksSheet,
    'word meanings': showWbwPacksSheet,
    'go to ayah': (c) => showGoToAyahSheet(c),
    'search filters': showSearchFilterSheet,
    'plan': (c) => showPlanSheet(c),
    'mark what I know': (c) => showMarkKnownSheet(c),
  };
  var t = 0;
  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    if (!all && !everyRun.contains(sizeName)) continue;
    for (final MapEntry(key: name, value: open) in sheets.entries) {
      for (final locale in all ? locales : [locales[t % locales.length]]) {
        final i = t++;
        final textScale = const [2.0, 1.5][i % 2];
        testWidgets(
          '$sizeName, $locale, the $name sheet — text ×$textScale',
          (tester) => reader(
            tester,
            route: '/quran/ayah/2/282',
            size: size,
            locale: locale,
            textScale: textScale,
            mode: ReaderMode.values[i % 2],
            sheet: open,
          ),
        );
      }
    }
  }

  // The extremes: every Quran font at the largest text, system and Ayah
  // mode's, on every size (the longest ayah, German's long words) — on
  // every run, on the narrowest phone.
  for (final MapEntry(key: sizeName, value: size) in sizes.entries) {
    if (!all && sizeName != 'narrow phone') continue;
    for (final font in QuranFont.values) {
      testWidgets(
        '$sizeName, de, Ayah mode, long ayah — text ×2.0, '
        '${font.name}, Ayah text ×2.0',
        (tester) => reader(
          tester,
          route: pages['long ayah']!,
          size: size,
          locale: 'de',
          textScale: 2.0,
          mode: ReaderMode.ayah,
          quranFont: font,
          ayahTextScale: 2.0,
        ),
      );
    }
    // Every Arabic font, in both right-to-left languages.
    for (final font in ArabicUiFont.values) {
      for (final locale in const ['ar', 'ur']) {
        testWidgets(
          '$sizeName, $locale, Ayah mode, long ayah — text ×2.0, '
          '${font.name}',
          (tester) => reader(
            tester,
            route: pages['long ayah']!,
            size: size,
            locale: locale,
            textScale: 2.0,
            mode: ReaderMode.ayah,
            arabicFont: font,
            ayahTextScale: 2.0,
          ),
        );
      }
    }
  }
}

/// Every font the app bundles (`pubspec.yaml`'s `fonts:`), so text is
/// measured in the real typefaces rather than the test font.
Future<void> _loadAppFonts() async {
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
class _Backend implements QuranEngineMushafBackend {
  _Backend(Map<int, int> ayahPages, this._words) {
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
    return _Page(pageNumber, words, ends);
  }

  @override
  void disposePage(QuranEngineMushafPage page) {}

  @override
  Future<void> preloadAround(int pageNumber, {int radius = 1}) async {}
}

class _Page implements QuranEngineMushafPage {
  _Page(this.pageNumber, this.wordRefs, this.ayahWordBoundaries);

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
