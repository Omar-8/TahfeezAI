import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/theme/app_typography.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
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
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/quran/application/tafsir_selection_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/settings/presentation/theme_choices.dart';

import 'package:tahfeez_ai/features/mushaf/presentation/mushaf_appearance_sheet.dart';

import '../test_helpers/real_app.dart';

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
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  void fits(WidgetTester tester, String reason) => RealApp.fits(tester, reason);
  Future<void> settle(WidgetTester tester) => RealApp.settle(tester);

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
    final container = await RealApp.launch(
      tester,
      size: size,
      locale: locale,
      textScale: textScale,
      mode: mode,
      layout: layout,
      quranFont: quranFont,
      ayahTextScale: ayahTextScale,
      arabicFont: arabicFont,
      readerTheme: readerTheme,
      appTheme: appTheme,
      passages: passages,
    );
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
        // (Its options are in the Hifz settings too.)
        showMushafAppearanceSheet(tester.element(find.byType(Scaffold).last));
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
    await RealApp.quit(tester);
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
  const locales = [
    'en', 'ar', 'de', 'fr', 'tr', 'ur', 'id', 'es', 'ru', 'fa', 'bn', //
  ];
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
    'ayah': (c) => showAyahDetailSheet(c, ayahId: 2282),
    // Everything it can show, at its largest text.
    'ayah, everything ×2.0': (c) {
      final container = ProviderScope.containerOf(c);
      container
          .read(ayahViewPreferencesProvider.notifier)
          .set(
            const AyahViewPreferences(
              showTranslation: true,
              showTransliteration: true,
              showTafsir: true,
              showWordMeanings: true,
              quranFont: QuranFont.amiri,
            ),
          );
      container.read(tafsirTextScaleControllerProvider.notifier).setScale(2);
      showAyahDetailSheet(c, ayahId: 2282);
    },
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
    // Every Arabic font, in each right-to-left language.
    for (final font in ArabicUiFont.values) {
      for (final locale in const ['ar', 'ur', 'fa']) {
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
