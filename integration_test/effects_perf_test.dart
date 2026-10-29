// Frame timing of the recitation's word animations on a phone: Yā-Sīn's
// first page recited word by word — each word revealed and marked right
// (the reveal, the glow) — on the printed page, then in Ayah mode.
//
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/effects_perf_test.dart -d <phone>
//
// (Uninstalls the app at the end, as every flutter drive run does, unless
// --keep-app-running.)
// The summaries land in build/perf/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahfeez_ai/app/app.dart';
import 'package:tahfeez_ai/app/bootstrap.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_word_overlay.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';
import 'package:tahfeez_ai/quran/application/quran_script_code.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';
import 'package:tahfeez_ai/quran/quran_providers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // No accessibility tree (semanticsEnabled): a phone builds one only for a
  // service that reads the screen (TalkBack) — here it doubled the frames.
  testWidgets('word animations, frame timing', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('firstRun.welcome', true);
    await prefs.setBool('firstRun.guide', true);
    await bootstrap();
    // Frames as the phone draws them, not only when the test pumps.
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    Future<void> run(double seconds) => tester.runAsync(
      () => Future<void>.delayed(
        Duration(milliseconds: (seconds * 1000).round()),
      ),
    );

    await run(20);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TahfeezApp)),
    );
    Future<void> go(String route) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(route);
      await run(5);
    }

    // Yā-Sīn 1–12: the first page of the surah (page 440).
    final repository = container.read(quranRepositoryProvider);
    final script = container.read(quranScriptCodeProvider);
    final words = <WordRef>[
      for (var a = 1; a <= 12; a++)
        for (final w in await repository.getWordsForAyah(
          36000 + a,
          scriptCode: script,
        ))
          (ayahId: w.ayahId, wordIndex: w.wordIndex),
    ];
    final overlay = container.read(mushafWordOverlayProvider.notifier);

    // A recitation's pace: a word every 0.35 s, each revealed and marked
    // right, to the page's last word — traced 10 words at a time (the
    // phone's trace holds only a few seconds: a whole recitation kept just
    // its end), each part reported as `<mode>.<nn>`; the driver joins them.
    Future<void> recite(String key) async {
      final revealed = <WordRef>{};
      final marks = <WordRef, MushafWordMark>{};
      const perPart = 10;
      for (var part = 0; part * perPart < words.length; part++) {
        final said = words.skip(part * perPart).take(perPart);
        final last = (part + 1) * perPart >= words.length;
        await binding.traceAction(
          () async {
            if (part == 0) {
              overlay.set(
                MushafWordOverlay(first: words.first, last: words.last),
              );
              await run(1);
            }
            for (final w in said) {
              revealed.add(w);
              marks[w] = MushafWordMark.correct;
              overlay.set(
                MushafWordOverlay(
                  first: words.first,
                  last: words.last,
                  revealed: {...revealed},
                  marks: {...marks},
                ),
              );
              await run(0.35);
            }
            if (last) {
              await run(2);
              overlay.set(null);
              await run(1);
            }
          },
          reportKey: '$key.${part.toString().padLeft(2, '0')}',
          // Frames and garbage collection only: the engine's string
          // conversions alone would fill the trace.
          streams: const ['Dart', 'Embedder', 'GC'],
        );
      }
    }

    for (final (mode, key) in [
      (ReaderMode.mushaf, 'mushaf'),
      (ReaderMode.ayah, 'ayah'),
    ]) {
      container.read(readerModeProvider.notifier).set(mode);
      await go('/quran/surah/36');
      debugPrint('perf: $key, ${words.length} words');
      await recite(key);
      await go('/home');
    }
    expect(Platform.isAndroid, isTrue);
  }, semanticsEnabled: false);
}
