// QA on a real device: the app as installed — the native Mushaf engine,
// sound, the microphone — walked through: the reader in its three
// layouts, hide mode, listening, reciting, Follow along, search, Go to
// ayah, and every main screen's every control tapped in turn (what leaves
// the app — links, the share sheet, files, the store — left out). Every
// error is kept and the run fails at the end listing them, with where each
// came from; screenshots go to screenshots/qa-*.png.
//
// Reinstalls the app (its data starts empty). The microphone and
// notification permissions are granted from the computer meanwhile:
//
//   (until adb shell pm grant ai.tahfeez.tahfeez_ai \
//      android.permission.RECORD_AUDIO 2>/dev/null; do sleep 1; done; \
//    adb shell pm grant ai.tahfeez.tahfeez_ai \
//      android.permission.POST_NOTIFICATIONS) &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/device_qa_test.dart -d <device>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qvp_flutter/qvp_flutter.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/app/bootstrap.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_session_controller.dart';

/// Controls that leave the app (a browser, the share sheet, the file
/// picker, the store): not tapped.
const _leavesApp = {
  'settings-feedback',
  'settings-github',
  'settings-rate',
  'settings-share',
  'settings-check-updates',
  'settings-export',
  'settings-import',
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device QA', (tester) async {
    // Every error kept, the walk going on; listed at the end.
    final errors = <String>[];
    var step = 'start';
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      final where = details
          .toString()
          .split('\n')
          .where((l) => l.contains('package:tahfeez_ai'))
          .take(3)
          .join('\n');
      errors.add('$step: ${details.exceptionAsString()}\n$where');
      debugPrint('QA ERROR at $step: ${details.exceptionAsString()}\n$where');
      // On to the test framework too (it keeps it for takeException).
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    void check() {
      // (Kept by the recorder above already, with where it came from.)
      tester.takeException();
    }

    await bootstrap();
    // Frames for [seconds] (the app animates, so it never settles).
    Future<void> run(double seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      check();
    }

    await run(30); // the first start seeds the Quran database
    // (Android draws to a surface screenshots can't read until converted.)
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    var shots = 0;
    Future<void> shot(String name) async {
      await tester.pump();
      await binding.takeScreenshot(
        'qa-${(++shots).toString().padLeft(2, '0')}-$name',
      );
    }

    BuildContext app() => tester.element(find.byType(TahfeezApp));
    final container = ProviderScope.containerOf(app());
    GoRouter router() =>
        GoRouter.of(tester.element(find.byType(Navigator).first));
    Future<void> go(String route) async {
      step = 'go $route';
      debugPrint('QA step: $step');
      router().go(route);
      await run(3);
    }

    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await run(1.5);
    }

    /// Closes a sheet or dialog if one opened (not the screen under it).
    Future<void> closeSheet() async {
      if (find.byType(BottomSheet).evaluate().isNotEmpty ||
          find.byType(Dialog).evaluate().isNotEmpty) {
        await back();
      }
    }

    await shot('home');

    // ── The reader, as printed ──
    container.read(readerModeProvider.notifier).set(ReaderMode.mushaf);
    await go('/quran/surah/36');
    expect(find.byType(QvpPageView), findsWidgets, reason: 'the page draws');
    await shot('mushaf-yasin');
    step = 'swipe pages';
    final page = find.byType(QvpPageView).first;
    await tester.fling(page, const Offset(300, 0), 1500);
    await run(2);
    await tester.fling(page, const Offset(-300, 0), 1500);
    await run(2);
    step = 'long-press a word';
    await tester.longPress(find.byType(QvpPageView).first);
    await run(2);
    await shot('mushaf-ayah-sheet');
    await closeSheet();

    // Hide mode: hidden, then revealed a little.
    step = 'hide mode';
    final hide = container.read(mushafHideModeProvider.notifier);
    if (!container.read(mushafHideModeProvider).enabled) hide.toggle();
    await run(2);
    for (var i = 0; i < 5; i++) {
      hide.revealNextWord(
        container.read(mushafHideModeProvider).revealed.keys.firstOrNull ?? 440,
      );
      await run(0.4);
    }
    await shot('mushaf-hidden');
    hide.toggle();
    await run(1);

    // ── Ayah mode, both layouts ──
    for (final layout in AyahLayout.values) {
      step = 'Ayah mode ${layout.name}';
      container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
      final view = container.read(ayahViewPreferencesProvider);
      container
          .read(ayahViewPreferencesProvider.notifier)
          .set(
            view.copyWith(
              layout: layout,
              showTranslation: true,
              showTransliteration: true,
              showTafsir: true,
              showWordMeanings: true,
            ),
          );
      await go('/quran/ayah/2/255');
      await shot('ayah-mode-${layout.name}');
      final list = find.byType(Scrollable).last;
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -500), 2000);
        await run(0.8);
      }
      await shot('ayah-mode-${layout.name}-scrolled');
      await tester.tap(find.byIcon(Icons.tune).first);
      await run(2);
      await shot('ayah-mode-${layout.name}-settings');
      await closeSheet();
    }

    // ── Listening, reciting, Follow along (no one speaking) ──
    step = 'listen';
    await go('/quran/surah/112');
    final played = await container
        .read(quranAudioPlayerProvider.notifier)
        .playAyahs([112001, 112002]);
    await run(6);
    await shot('listening${played ? '' : '-offline'}');
    await container.read(quranAudioPlayerProvider.notifier).stop();
    await run(1);
    for (final mode in ['Recite', 'Follow']) {
      step = mode;
      final button = find.text(mode);
      if (button.evaluate().isEmpty) {
        errors.add('$mode: no button in the bar');
        continue;
      }
      await tester.tap(button.first);
      await run(5);
      await shot(mode.toLowerCase());
      await container.read(recitationSessionControllerProvider.notifier).stop();
      await run(1);
      await closeSheet();
      // The reader again, its mode bar (a mode may have left a sheet).
      await go('/quran/surah/112');
    }

    // ── Search ──
    step = 'search';
    await go('/quran/search');
    await tester.enterText(find.byType(TextField).first, 'الرحمن');
    await run(3);
    await shot('search');

    // ── Every main screen's every control, one at a time ──
    for (final route in const [
      '/home',
      '/quran',
      '/quran/bookmarks',
      '/memorize',
      '/memorize/progress',
      '/settings',
      '/settings/about',
      '/quran/surah/36',
    ]) {
      if (route == '/quran/surah/36') {
        container.read(readerModeProvider.notifier).set(ReaderMode.ayah);
      }
      await go(route);
      final count = _controls().evaluate().length;
      for (var i = 0; i < count && i < 60; i++) {
        await go(route);
        final controls = _controls();
        if (i >= controls.evaluate().length) break;
        final control = controls.at(i);
        if (_leaves(tester, control)) continue;
        step = '$route, control #$i (${_describe(tester, control)})';
        debugPrint('QA step: $step');
        await tester.tap(control, warnIfMissed: false);
        await run(1.5);
        await back();
      }
      await shot('crawled-${route.replaceAll('/', '-')}');
    }

    await go('/home');
    FlutterError.onError = prior;
    expect(errors, isEmpty, reason: errors.join('\n\n'));
  });
}

Finder _controls() => find
    .byWidgetPredicate((w) => w is InkWell && w.onTap != null)
    .hitTestable();

/// Whether [control] is one that leaves the app ([_leavesApp]).
bool _leaves(WidgetTester tester, Finder control) {
  var leaves = false;
  tester.element(control).visitAncestorElements((e) {
    final key = e.widget.key;
    if (key is ValueKey && _leavesApp.contains(key.value)) {
      leaves = true;
      return false;
    }
    return true;
  });
  return leaves;
}

String _describe(WidgetTester tester, Finder control) => [
  for (final e
      in find
          .descendant(of: control, matching: find.byType(Text))
          .evaluate()
          .take(2))
    (e.widget as Text).data ?? '',
].where((t) => t.isNotEmpty).join(' / ');
