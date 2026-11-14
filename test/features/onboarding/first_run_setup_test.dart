import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/khatmah/application/khatmah_controller.dart';
import 'package:tahfeez_ai/features/listen/application/reciter_controller.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/mushaf/presentation/ayah_view_parts.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/features/quran/application/quran_index_providers.dart';
import 'package:tahfeez_ai/features/onboarding/presentation/first_run_setup.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';
import 'package:tahfeez_ai/quran/application/ayah_reading_extras.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';

import '../../test_helpers/fake_audio_controller.dart';
import '../../test_helpers/memory_storage.dart';
import '../../test_helpers/widget_test_overrides.dart';

/// The first start's setup: the language, what to begin with (a khatmah's
/// days), a reciter (a sample heard) and how reciting works (an ayah
/// recited, then a word's tap and long-press tried) — each applied as
/// chosen; skipped, it leaves things as they were; and it fits a small
/// phone at twice the text size in long and right-to-left languages.
void main() {
  late ProviderContainer container;
  late GoRouter router;
  late FakeAudioController audio;
  const demoWords = ['ٱلْحَمْدُ', 'لِلَّهِ', 'رَبِّ', 'ٱلْعَٰلَمِينَ'];

  Future<void> pump(
    WidgetTester tester, {
    String? locale,
    double width = 400,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    audio = FakeAudioController();
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showFirstRunSetup(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(path: '/memorize', builder: (_, _) => const Text('memorize')),
      ],
    );
    addTearDown(router.dispose);
    container = ProviderContainer(
      overrides: [
        ...tahfeezWidgetTestOverrides(audioController: audio),
        browserStorageProvider.overrideWithValue(MemoryStorage()),
        memorizationClockProvider.overrideWithValue(
          () => DateTime(2026, 11, 13, 9),
        ),
        // The demo's ayah (the database's own text in the app).
        ayahCanonicalWordsProvider.overrideWith(
          (ref, id) async => [
            for (final (i, w) in demoWords.indexed)
              AyahWord(ayahId: id, scriptId: 1, wordIndex: i, text: w),
          ],
        ),
        ayahWordMeaningsProvider.overrideWith(
          (ref, id) async => const {0: 'All praise', 2: 'Lord'},
        ),
        appRouterProvider.overrideWithValue(router),
        defaultMushafProvider.overrideWith(
          (ref) async => const Mushaf(
            id: 1,
            code: 'madinah',
            scriptId: 1,
            pageCount: 604,
            linesPerPage: 15,
            qiraah: 'Hafs',
            edition: 'Test',
            renderingType: MushafRenderingType.unicodeText,
          ),
        ),
        if (locale != null)
          localeControllerProvider.overrideWithBuild((_, _) => Locale(locale)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The language as the app's: the chosen one.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            routerConfig: router,
            locale: ref.watch(localeControllerProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    // Below the fold of a long step (built only once near): scrolled to.
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        finder,
        find.byType(CustomScrollView).last,
        const Offset(0, -150),
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('the welcome: what the app is for, that it is still learning', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('setup-emblem')), findsOne);
    expect(find.textContaining('still learning'), findsOne);
    expect(find.text('Get started'), findsOne);
  });

  /// The demo step animates without end: time stepped, never settled.
  Future<void> step(
    WidgetTester tester,
    String key, {
    bool long = false,
  }) async {
    final finder = find.byKey(ValueKey(key));
    // Scrolled to, a little at a time, until it can be touched.
    for (var i = 0; i < 12 && finder.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -200),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (long) {
      await tester.longPress(finder);
    } else {
      await tester.tap(finder);
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a khatmah: language, days, reciter — all applied', (
    tester,
  ) async {
    await pump(tester);
    await tapKey(tester, 'setup-next');
    expect(find.text('Choose your language'), findsOne);
    await tapKey(tester, 'setup-language-de');
    expect(container.read(localeControllerProvider), const Locale('de'));
    expect(find.text('Überspringen'), findsOne); // at once

    await tapKey(tester, 'setup-next');
    await tapKey(tester, 'setup-goal-khatmah');
    await tapKey(tester, 'setup-khatmah-15');
    expect(find.text('Etwa 41 Seiten pro Tag'), findsOne);

    await tapKey(tester, 'setup-next');
    await tapKey(tester, 'setup-reciter-ar.minshawi');
    expect(container.read(reciterProvider), 'ar.minshawi');
    // A sample: Al-Fātiḥah's opening, by the one tapped.
    await tapKey(tester, 'setup-sample-ar.mahermuaiqly');
    expect(container.read(reciterProvider), 'ar.mahermuaiqly');
    // Playing: its button now stops it.
    expect(find.byIcon(Icons.stop_circle_outlined), findsOne);

    await step(tester, 'setup-next');
    await step(tester, 'setup-done');
    expect(find.byType(FirstRunSetup), findsNothing);
    final k = container.read(khatmahProvider).value!;
    expect(k.days, 15);
    expect(router.state.matchedLocation, '/home');
  });

  testWidgets('to memorize: Memorize opens at the end', (tester) async {
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'setup-next');
    }
    await step(tester, 'setup-next');
    await step(tester, 'setup-done');
    expect(router.state.matchedLocation, '/memorize');
    expect(container.read(khatmahProvider).value, isNull);
  });

  testWidgets('how reciting works: the ayah recited word by word; a tap '
      'shows a meaning, a long-press the ayah\'s actions', (tester) async {
    await pump(tester);
    for (var i = 0; i < 4; i++) {
      await step(tester, 'setup-next');
    }
    expect(find.text('How reciting works'), findsOne);
    expect(find.text('Listening…'), findsOne);
    // The words said inked green, one word after another.
    Color? inkOf(int i) => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .descendant(
                of: find.byKey(const ValueKey('setup-demo-reciting')),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .at(i),
        )
        .style
        .color;
    const green = Color(0xFF43A047);
    final before = [for (var i = 0; i < 4; i++) inkOf(i) == green];
    await tester.pump(const Duration(milliseconds: 1700));
    final after = [for (var i = 0; i < 4; i++) inkOf(i) == green];
    expect(
      after.where((g) => g).length,
      greaterThan(before.where((g) => g).length),
    );
    expect(find.text('Right'), findsOne);
    expect(find.text('Pronunciation'), findsOne);

    await step(tester, 'setup-demo-word-0');
    expect(find.text('All praise'), findsOne);
    await step(tester, 'setup-demo-word-2', long: true);
    expect(find.byKey(const ValueKey('setup-demo-actions')), findsOne);
    expect(find.text('Bookmark ayah'), findsNothing);
    // Each works on the ayah: its translation, its tafsir, its recitation.
    // (None chosen in these tests: where to choose one, as the sheet says.)
    await step(tester, 'setup-demo-translation');
    expect(
      find.textContaining('No translation chosen').evaluate().isNotEmpty ||
          find.byType(AyahTranslations).evaluate().isNotEmpty,
      isTrue,
    );
    await step(tester, 'setup-demo-tafsir');
    expect(find.textContaining('No translation chosen'), findsNothing);
    expect(
      find.textContaining('No tafsir chosen').evaluate().isNotEmpty ||
          find
              .byKey(const ValueKey('setup-demo-tafsir-text'))
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
    await step(tester, 'setup-demo-listen');
    expect(container.read(quranAudioPlayerProvider)?.ayahId, 1002);
  });

  testWidgets('the demo: its page reported as the ayah alone, the shell\'s '
      'bar aside — both as they were once it is left', (tester) async {
    await pump(tester);
    final verses = container.read(mushafPageVersesProvider.notifier);
    const real = (
      first: (chapterNo: 1, verseNo: 1),
      last: (chapterNo: 1, verseNo: 7),
    );
    verses.report(1, real); // the Mushaf's page 1, open behind
    for (var i = 0; i < 4; i++) {
      await step(tester, 'setup-next');
    }
    expect(container.read(mushafPageVersesProvider)[1], (
      first: (chapterNo: 1, verseNo: 2),
      last: (chapterNo: 1, verseNo: 2),
    ));
    expect(container.read(mushafHideModeProvider).wordCounts[1], 4);
    expect(container.read(recitationBarElsewhereProvider), isTrue);
    expect(
      container.read(mushafRecitationTargetProvider)?.location,
      isA<QuranLocationPage>(),
    );

    await step(tester, 'setup-back');
    await tester.pump();
    expect(container.read(mushafPageVersesProvider)[1], real);
    expect(container.read(recitationBarElsewhereProvider), isFalse);
    expect(container.read(mushafRecitationTargetProvider), isNull);
  });

  testWidgets('animations off: the ayah shown recited, still', (tester) async {
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'setup-next');
    }
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tapKey(tester, 'setup-next');
    expect(find.text('How reciting works'), findsOne);
    // Settled: nothing runs on.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Back: the step before; Skip: out, nothing begun', (
    tester,
  ) async {
    await pump(tester);
    await tapKey(tester, 'setup-next');
    await tapKey(tester, 'setup-next');
    await tapKey(tester, 'setup-back');
    expect(find.text('Choose your language'), findsOne);
    await tapKey(tester, 'setup-skip');
    expect(find.byType(FirstRunSetup), findsNothing);
    expect(container.read(khatmahProvider).value, isNull);
  });

  for (final locale in ['en', 'de', 'ru', 'ar', 'ur', 'ja']) {
    testWidgets('$locale: every step at 320 px, text twice its size', (
      tester,
    ) async {
      await pump(tester, locale: locale, width: 320, textScale: 2);
      expect(tester.takeException(), isNull, reason: 'welcome');
      for (final (i, name) in ['language', 'goal', 'reciter'].indexed) {
        await tapKey(tester, 'setup-next');
        if (i == 1) await tapKey(tester, 'setup-goal-khatmah');
        expect(tester.takeException(), isNull, reason: name);
      }
      await step(tester, 'setup-next');
      expect(tester.takeException(), isNull, reason: 'demo');
      await step(tester, 'setup-demo-word-0');
      expect(tester.takeException(), isNull, reason: 'a meaning');
      await step(tester, 'setup-demo-word-1', long: true);
      expect(tester.takeException(), isNull, reason: 'the ayah\'s actions');
    });
  }
}
