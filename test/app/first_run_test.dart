import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/features/guide/guide.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';

import '../test_helpers/real_app.dart';

/// The first time: Home's welcome, and the guide as the reader first opens
/// (the printed page or Ayah mode) — each once only.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  testWidgets('the welcome on Home the first time, then never again', (
    tester,
  ) async {
    await RealApp.launch(tester, firstRun: true);
    expect(find.byKey(const ValueKey('home-welcome')), findsOneWidget);
    expect(find.textContaining('still learning'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-welcome-continue')));
    await RealApp.settle(tester);
    expect(find.byKey(const ValueKey('home-welcome')), findsNothing);
    await RealApp.quit(tester);

    // Started again (what was shown is remembered).
    await RealApp.launch(tester, firstRun: true);
    expect(find.byKey(const ValueKey('home-welcome')), findsNothing);
    await RealApp.quit(tester);
  });

  testWidgets('the guide as the reader first opens, then only from its '
      'button — Mushaf first, Ayah mode after', (tester) async {
    Future<void> openReader(ReaderMode mode, {required bool guided}) async {
      final container = await RealApp.launch(
        tester,
        firstRun: true,
        mode: mode,
      );
      // (The welcome out of the way, if still due.)
      final welcome = find.byKey(const ValueKey('home-welcome-continue'));
      if (welcome.evaluate().isNotEmpty) {
        await tester.tap(welcome);
        await RealApp.settle(tester);
      }
      container.read(appRouterProvider).go('/quran/surah/36');
      await RealApp.settle(tester);
      await tester.pump(const Duration(seconds: 2));
      await RealApp.settle(tester);
      expect(
        container.read(guideProvider) != null,
        guided,
        reason: guided ? 'started by itself' : 'once only',
      );
      if (guided) {
        // The short one: a word, Recite, the eye ("?" for the rest).
        expect(container.read(guideProvider)?.tour, GuideTour.intro);
        expect(guideSteps(GuideTour.intro), hasLength(3));
      }
      container.read(guideProvider.notifier).close();
      await RealApp.settle(tester);
      await RealApp.quit(tester);
    }

    await openReader(ReaderMode.mushaf, guided: true);
    await openReader(ReaderMode.ayah, guided: false);
  });

  testWidgets('the ayahs hidden the first time: their buttons shown, once', (
    tester,
  ) async {
    final container = await RealApp.launch(tester, firstRun: true);
    final welcome = find.byKey(const ValueKey('home-welcome-continue'));
    if (welcome.evaluate().isNotEmpty) {
      await tester.tap(welcome);
      await RealApp.settle(tester);
    }
    container.read(appRouterProvider).go('/quran/surah/36');
    await RealApp.settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await RealApp.settle(tester);
    container.read(guideProvider.notifier).close();
    await RealApp.settle(tester);

    Future<GuideState?> hideAyahs() async {
      container.read(mushafHideModeProvider.notifier).toggle();
      await tester.pump(const Duration(seconds: 1));
      await RealApp.settle(tester);
      final shown = container.read(guideProvider);
      container.read(guideProvider.notifier).close();
      container.read(mushafHideModeProvider.notifier).toggle();
      await RealApp.settle(tester);
      return shown;
    }

    expect((await hideAyahs())?.tour, GuideTour.firstHide);
    expect(await hideAyahs(), isNull, reason: 'once only');
    await RealApp.quit(tester);
  });
}
