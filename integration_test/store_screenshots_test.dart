// The README's, the landing page's and the stores' screenshots, taken from
// the app on a device: each scene set up (theme, language, reader mode,
// demo memorization progress), then captured to screenshots/shot-*.png.
// tool/make_store_images.py frames them with their captions.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/store_screenshots_test.dart -d <device>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahfeez_ai/features/home/presentation/home_sky.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/app/bootstrap.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_passages.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/memorization/domain/models/memorization_models.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/domain/quran_ayah_numbers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    // Seen already: no welcome or guide over the scenes.
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('firstRun.welcome', true);
    await prefs.setBool('firstRun.guide', true);

    await bootstrap();
    Future<void> run(double seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await run(30); // the first start seeds the Quran database
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Navigator).first));
    Future<void> go(String route) async {
      router().go(route);
      await run(4);
    }

    Future<void> shot(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await run(1.5);
      await binding.takeScreenshot('shot-$name');
    }

    Future<void> closeSheet() async {
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        await tester.binding.handlePopRoute();
        await run(1.5);
      }
    }

    Future<void> theme({required bool dark, MushafAppearance? reader}) async {
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
      await container
          .read(appSurfaceToneProvider.notifier)
          .setTone(AppSurfaceTone.standard);
      await container
          .read(mushafAppearanceControllerProvider.notifier)
          .setAppearance(
            reader ?? (dark ? MushafAppearance.dark : MushafAppearance.light),
          );
      await run(1);
    }

    Future<void> ayahView({
      AyahLayout layout = AyahLayout.paged,
      bool meanings = true,
      bool tafsir = false,
      QuranFont font = QuranFont.scheherazade,
    }) async {
      await container
          .read(ayahViewPreferencesProvider.notifier)
          .set(
            AyahViewPreferences(
              layout: layout,
              showTranslation: true,
              showTransliteration: true,
              showTafsir: tafsir,
              showWordMeanings: meanings,
              quranFont: font,
            ),
          );
    }

    // ── Demo memorization progress: Juz ʿAmma's last surahs memorized,
    // revised these past days with varying strength ──
    final repo = container.read(memorizationRepositoryProvider);
    final memorized = [
      for (var s = 78; s <= 114; s++)
        if (s >= 93 || s == 78)
          for (var a = 1; a <= surahAyahCounts[s - 1]; a++) s * 1000 + a,
      for (var a = 1; a <= 7; a++) 1000 + a,
    ];
    await repo.markMemorized(memorized);
    final now = DateTime.now();
    var n = 0;
    await repo.recordTest([
      for (final ayah in memorized)
        if (ayah ~/ 1000 >= 97)
          AyahAttempt(
            ayahId: ayah,
            sessionId: 'demo-${ayah ~/ 1000}',
            at: now.subtract(Duration(days: 1 + (n++ % 6), hours: n % 5)),
            grade: n % 7 == 0
                ? AyahGrade.fail
                : n % 4 == 0
                ? AyahGrade.hard
                : AyahGrade.good,
            words: 6,
            wrong: n % 7 == 0 ? 1 : 0,
            pronunciation: n % 4 == 0 ? 1 : 0,
            hidden: true,
          ),
    ]);
    await run(2);

    // ── Light ── under a morning sky
    debugSkyTime = DateTime(2026, 10, 26, 9);
    await theme(dark: false);
    await go('/home');
    await shot('01-home-light');
    // The surah list: glass cards, the names in the Mushaf's calligraphy.
    await go('/quran');
    await shot('18-quran-tab-light');

    container.read(readerModeProvider.notifier).set(ReaderMode.mushaf);
    await go('/quran/surah/36');
    await shot('02-mushaf-light');

    // Listening: the reciter's ayah lit and followed (Ayah mode).
    await ayahView(meanings: false);
    container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await go('/quran/surah/1');
    await container
        .read(quranAudioPlayerProvider.notifier)
        .playRange(1001, 1007, options: const ListenOptions());
    await run(7);
    await shot('17-translations-light');
    await container.read(quranAudioPlayerProvider.notifier).stop();
    await run(1);

    // Ayah mode, light: word meanings, transliteration, translation.
    await ayahView();
    await go('/quran/ayah/2/255');
    await shot('04-ayah-mode-light');

    // Follow along's sheet.
    await go('/quran/surah/112');
    final follow = find.text('Follow');
    if (follow.evaluate().isNotEmpty) {
      await tester.tap(follow.first);
      await run(2);
      await shot('05-follow-along-light');
      await closeSheet();
    }

    // Tajweed: the Hifz settings (what the checking looks at).
    showHifzSettingsSheet(tester.element(find.byType(Scaffold).last));
    await run(2);
    await shot('06-tajweed-settings-light');
    await closeSheet();

    await go('/quran/search');
    await tester.enterText(find.byType(TextField).first, 'رحمة');
    await run(3);
    await shot('07-search-light');

    // ── Dark ── under a night sky
    debugSkyTime = DateTime(2026, 10, 26, 21);
    await theme(dark: true);
    await ayahView(tafsir: true, meanings: true);
    container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await go('/quran/surah/36');
    await shot('08-ayah-mode-dark');

    // Ayah mode's view: fonts, text size, what each ayah shows.
    await tester.tap(find.byIcon(Icons.tune).first);
    await run(2);
    await shot('09-view-settings-dark');
    await closeSheet();

    // Memorizing: the page hidden, words revealed as recited.
    container.read(readerModeProvider.notifier).set(ReaderMode.mushaf);
    await go('/quran/surah/112');
    final hide = container.read(mushafHideModeProvider.notifier);
    if (!container.read(mushafHideModeProvider).enabled) hide.toggle();
    await run(1);
    for (var i = 0; i < 9; i++) {
      hide.revealNextWord(604);
      await run(0.3);
    }
    await shot('10-hide-mode-dark');
    hide.toggle();
    await run(1);

    // Passages tinted (the printed page, sepia).
    await theme(dark: false, reader: MushafAppearance.sepia);
    await container.read(mushafPassagesProvider.notifier).set(true);
    await go('/quran/surah/18');
    await shot('11-mushaf-sepia-passages');
    await container.read(mushafPassagesProvider.notifier).set(false);

    await theme(dark: true);
    await go('/memorize');
    await shot('12-memorize-dark');
    await go('/memorize/progress');
    await shot('13-progress-dark');
    await go('/settings');
    await shot('14-settings-dark');

    // ── Arabic ──
    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('ar'));
    await run(2);
    await theme(dark: false);
    await go('/home');
    await shot('15-home-arabic-light');
    await ayahView(font: QuranFont.amiri);
    container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await go('/quran/surah/1');
    await shot('16-ayah-mode-arabic-light');

    await container.read(localeControllerProvider.notifier).setLocale(null);
    await go('/home');
  });
}
