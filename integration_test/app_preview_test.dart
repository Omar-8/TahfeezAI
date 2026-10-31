// The App Store's app preview: a ~25-second tour of the app, recorded from
// the simulator's screen (`xcrun simctl io recordVideo`, in
// .github/workflows/ios-screenshots.yml) and cut between the lines
// "app-preview: start" and "app-preview: end" this test prints. In real
// time (fully live frames), so the recording is smooth.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_preview_test.dart -d <simulator>
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/app/bootstrap.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/quran_text_style.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/home/presentation/home_sky.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';
import 'package:tahfeez_ai/memorization/memorization_providers.dart';
import 'package:tahfeez_ai/quran/domain/quran_ayah_numbers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('app preview', (tester) async {
    // Seen already: no welcome or guide over the tour.
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('firstRun.welcome', true);
    await prefs.setBool('firstRun.guide', true);

    await bootstrap();
    // By the clock: a slow device draws fewer frames, not a longer tour.
    Future<void> wait(double seconds) async {
      final clock = Stopwatch()..start();
      while (clock.elapsedMilliseconds < seconds * 1000) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await wait(20); // the first start puts the Qur'an databases in place
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Navigator).first));
    Future<void> go(String route, double seconds) async {
      router().go(route);
      await wait(seconds);
    }

    /// The screen's main list scrolled by [dy], slowly (as a finger would).
    Future<void> scroll(double dy, double seconds) async {
      final list = find.byType(Scrollable);
      if (list.evaluate().isEmpty) return;
      await tester.timedDrag(
        list.last,
        Offset(0, -dy),
        Duration(milliseconds: (seconds * 1000).round()),
      );
      await wait(0.6);
    }

    // Light, under a morning sky; Ayah mode with word meanings.
    debugSkyTime = DateTime(2026, 10, 26, 9);
    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.light);
    await container
        .read(appSurfaceToneProvider.notifier)
        .setTone(AppSurfaceTone.standard);
    await container
        .read(mushafAppearanceControllerProvider.notifier)
        .setAppearance(MushafAppearance.light);
    await container
        .read(ayahViewPreferencesProvider.notifier)
        .set(
          const AyahViewPreferences(
            layout: AyahLayout.paged,
            showTranslation: true,
            showTransliteration: false,
            showTafsir: false,
            showWordMeanings: true,
            quranFont: QuranFont.scheherazade,
          ),
        );
    // Juz ʿAmma's last surahs memorized; the tour's pages opened once
    // before (drawn already, and the last read shown on Home).
    await container.read(memorizationRepositoryProvider).markMemorized([
      for (var s = 93; s <= 114; s++)
        for (var a = 1; a <= surahAyahCounts[s - 1]; a++) s * 1000 + a,
    ]);
    container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await go('/quran/ayah/2/255', 3);
    await go('/quran/surah/1', 2);
    container.read(readerModeProvider.notifier).set(ReaderMode.mushaf);
    await go('/quran/surah/112', 3);
    await go('/quran/surah/36', 4);
    await go('/home', 3);

    debugPrint('app-preview: start');
    // Home.
    await wait(2.5);
    // Every surah, as the Mushaf writes it.
    await go('/quran', 1);
    await scroll(500, 1.2);
    // The printed page.
    container.read(readerModeProvider.notifier).set(ReaderMode.mushaf);
    await go('/quran/surah/36', 2.5);
    // Memorizing: the page hidden, the words coming back as recited.
    await go('/quran/surah/112', 1.5);
    final hide = container.read(mushafHideModeProvider.notifier);
    if (!container.read(mushafHideModeProvider).enabled) hide.toggle();
    await wait(1);
    for (var i = 0; i < 12; i++) {
      hide.revealNextWord(604);
      await wait(0.3);
    }
    await wait(1);
    hide.toggle();
    // Every word understood.
    container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
    await go('/quran/ayah/2/255', 1.5);
    await scroll(450, 1.8);
    // Listening: the reciter's ayah lit and followed.
    // (Its future is the whole range played: not waited for.)
    unawaited(
      container
          .read(quranAudioPlayerProvider.notifier)
          .playRange(1001, 1007, options: const ListenOptions()),
    );
    await go('/quran/surah/1', 5.5);
    await container.read(quranAudioPlayerProvider.notifier).stop();
    // Dark, under a night sky.
    debugSkyTime = DateTime(2026, 10, 26, 21);
    await container
        .read(themeModeControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await container
        .read(mushafAppearanceControllerProvider.notifier)
        .setAppearance(MushafAppearance.dark);
    await go('/home', 2.5);
    debugPrint('app-preview: end');
  });
}
