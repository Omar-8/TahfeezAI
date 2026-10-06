import 'package:flutter/material.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/ai/speech/live_quran_recognizer.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/platform/platform_capabilities.dart';
import 'package:tahfeez_ai/core/ui/full_bleed_content.dart';
import 'package:tahfeez_ai/ai/hifz/hifz_judge.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_hide_mode.dart';
import 'package:tahfeez_ai/ai/matching/quran_word_corpus.dart';
import 'package:tahfeez_ai/features/recitation/application/hifz_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/quran_match_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_providers.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_turn.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/features/recitation/application/live_recognition_controller.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';
import 'package:tahfeez_ai/features/recitation/domain/recitation_audio_source.dart';
import 'package:tahfeez_ai/features/recitation/presentation/recitation_controls.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';

import 'live_recognition_controller_test.dart' show FakeRecognizer;
import 'recitation_session_controller_test.dart'
    show FakeAudioSource, FakeRepository, FakeStore;

void main() {
  late FakeAudioSource source;
  late FakeRepository repository;
  late ValueNotifier<bool> mushafOpen;
  late FakeRecognizer recognizer;

  const bar = ValueKey('recitation-bottom-bar');

  Widget app({
    bool supported = true,
    bool devPanel = true,
    int pageCount = 604,
    bool web = false,
  }) {
    return ProviderScope(
      overrides: [
        recitationSupportedProvider.overrideWithValue(supported),
        // No database in widget tests: an empty canonical word list.
        quranWordCorpusProvider.overrideWith(
          (ref) async => QuranWordCorpus.fromWords(const []),
        ),
        if (web)
          platformCapabilitiesProvider.overrideWithValue(const _WebPlatform()),
        recitationAudioSourceFactoryProvider.overrideWithValue(() => source),
        recitationRecordingStoreProvider.overrideWithValue(FakeStore()),
        recitationSessionRepositoryProvider.overrideWithValue(repository),
        recitationKeepRecordingsProvider.overrideWithValue(true),
        liveQuranRecognizerFactoryProvider.overrideWithValue(() => recognizer),
        liveRecognitionEnabledProvider.overrideWithValue(true),
        liveRecognitionDevPanelEnabledProvider.overrideWithValue(devPanel),
        mushafByIdProvider(1).overrideWith(
          (ref) async => Mushaf(
            id: 1,
            code: 'test',
            scriptId: 1,
            pageCount: pageCount,
            linesPerPage: 15,
            qiraah: 'Hafs',
            edition: 'test',
            renderingType: MushafRenderingType.unicodeText,
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: mushafOpen,
          builder: (context, open, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Top bar'),
              actions: const [HifzSettingsButton()],
            ),
            body: open
                ? const RecitationMushafAnchor(
                    location: QuranLocation.page(1, 5),
                    child: Text('mushaf body'),
                  )
                : const Text('quran index'),
            bottomNavigationBar: const RecitationBottomBar(
              navigation: Text('Home Quran Search'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    source = FakeAudioSource();
    repository = FakeRepository();
    mushafOpen = ValueNotifier(true);
    recognizer = FakeRecognizer();
  });

  testWidgets('eye toggles hide mode; reveal uncovers one word at a time', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    container
        .read(mushafHideModeProvider.notifier)
        .reportPageWords(5, wordCount: 2);

    expect(find.byTooltip('Reveal next word'), findsNothing);
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).enabled, isTrue);
    expect(find.byTooltip('Show ayahs'), findsOneWidget);

    expect(find.byTooltip('Reveal next ayah'), findsOneWidget);
    expect(find.text('Tap the mic to start reciting'), findsNothing);
    final reveal = find.byTooltip('Reveal next word');
    await tester.tap(reveal);
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).revealedOn(5), 2);
    expect(
      container.read(mushafPageTurnRequestsProvider),
      isNull,
      reason: 'revealing never turns the page',
    );
    // Page fully uncovered: both reveal buttons now turn to the next page.
    await tester.tap(reveal);
    await tester.tap(find.byTooltip('Reveal next ayah'));
    await tester.pumpAndSettle();
    expect(container.read(mushafPageTurnRequestsProvider), (
      id: 2,
      direction: 1,
    ));
    expect(container.read(mushafHideModeProvider).revealedOn(5), 2);

    await tester.tap(find.byTooltip('Show ayahs'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).enabled, isFalse);
    expect(find.byTooltip('Reveal next word'), findsNothing);
  });

  testWidgets('hide buttons go back word by word, then to the previous page', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    container
        .read(mushafHideModeProvider.notifier)
        .reportPageWords(5, wordCount: 4, ayahBoundaries: [2, 4]);
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reveal next ayah'));
    await tester.tap(find.byTooltip('Reveal next word'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).revealedOn(5), 3);

    await tester.tap(find.byTooltip('Hide previous word'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).revealedOn(5), 2);
    await tester.tap(find.byTooltip('Hide previous ayah'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).revealedOn(5), 0);
    expect(container.read(mushafPageTurnRequestsProvider), isNull);

    // Everything hidden: going back turns to page 4, fully uncovered.
    await tester.tap(find.byTooltip('Hide previous word'));
    await tester.pumpAndSettle();
    expect(container.read(mushafPageTurnRequestsProvider)?.direction, -1);
    final hide = container.read(mushafHideModeProvider);
    expect(hide.fullyRevealed(4) || hide.revealedOn(4) > 1000, isTrue);
  });

  testWidgets('hide buttons disable at the start of page 1', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    mushafOpen.value = false;
    await tester.pumpAndSettle();
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('test-owner', const QuranLocation.page(1, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    for (final key in ['mushaf-hide-word', 'mushaf-hide-ayah']) {
      final button = tester.widget<IconButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNull, reason: key);
    }
  });

  testWidgets('recording with hide mode on fits one row on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(devPanel: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'no overflow');
    final stopY = tester.getCenter(find.byTooltip('Stop')).dy;
    for (final tip in [
      'Listening…',
      'Reveal next ayah',
      'Reveal next word',
      'Show ayahs',
      'Hide previous word',
      'Hide previous ayah',
      'Pause',
      'Stop',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      expect(
        tester.getCenter(find.byTooltip(tip)).dy,
        closeTo(stopY, 1),
        reason: tip,
      );
    }
  });

  testWidgets('web centers the bar buttons as one group', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(web: true));
    await tester.pumpAndSettle();

    final mic = tester.getRect(find.byTooltip('Start recitation'));
    final eye = tester.getRect(find.byTooltip('Hide ayahs'));
    // The eye is the group's last button.
    final groupCenter = (mic.left + eye.right) / 2;
    expect(groupCenter, closeTo(600, 2));
    expect(eye.left - mic.right, lessThan(40), reason: 'kept together');
  });

  testWidgets('Android keeps the mic and hide buttons at the edges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final mic = tester.getRect(find.byTooltip('Start recitation'));
    final eye = tester.getRect(find.byTooltip('Hide ayahs'));
    expect(mic.left, lessThan(40));
    expect(eye.right, greaterThan(1160));
  });

  testWidgets('the eye stays put when toggled, before and during a session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(devPanel: false));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    container
        .read(mushafHideModeProvider.notifier)
        .reportPageWords(5, wordCount: 2);
    await tester.pumpAndSettle();

    Future<void> toggleKeepsEye() async {
      final off = tester.getRect(find.byTooltip('Hide ayahs'));
      await tester.tap(find.byTooltip('Hide ayahs'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Reveal next word'), findsOneWidget);
      expect(tester.getRect(find.byTooltip('Show ayahs')), off);
      await tester.tap(find.byTooltip('Show ayahs'));
      await tester.pumpAndSettle();
    }

    await toggleKeepsEye();
    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    await toggleKeepsEye();

    // Recording, with every hide button showing: still one row.
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    final row = tester.getCenter(find.byTooltip('Stop')).dy;
    for (final tip in ['Listening…', 'Reveal next ayah', 'Show ayahs']) {
      expect(tester.getCenter(find.byTooltip(tip)).dy, closeTo(row, 1));
    }
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  testWidgets('spread opened on page 2 reveals pages 1 and 2, then turns', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    // Al-Baqarah opened in a two-page spread: the screen reports page 2,
    // but pages 1 and 2 are both showing.
    mushafOpen.value = false;
    await tester.pumpAndSettle();
    container
        .read(mushafRecitationTargetProvider.notifier)
        .show('spread', const QuranLocation.page(1, 2));
    container.read(fullBleedContentProvider.notifier).request();
    container.read(mushafHideModeProvider.notifier)
      ..reportPageWords(1, wordCount: 2, ayahBoundaries: [2])
      ..reportPageWords(2, wordCount: 2, ayahBoundaries: [2]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Reveal next word'));
    await tester.pumpAndSettle();
    final hide = container.read(mushafHideModeProvider);
    expect(hide.revealedOn(1), 1, reason: 'Al-Fātiḥah page first');
    expect(hide.revealedOn(2), 0);

    await tester.tap(find.byTooltip('Reveal next ayah'));
    await tester.tap(find.byTooltip('Reveal next ayah'));
    await tester.pumpAndSettle();
    expect(container.read(mushafHideModeProvider).revealedOn(2), 2);
    expect(container.read(mushafPageTurnRequestsProvider), isNull);

    await tester.tap(find.byTooltip('Reveal next word'));
    await tester.pumpAndSettle();
    expect(container.read(mushafPageTurnRequestsProvider)?.direction, 1);
    expect(container.read(mushafHideModeProvider).revealedOn(3), 0);
  });

  testWidgets('Hifz settings are in the top bar', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hifz mode'), findsNothing, reason: 'no switch');
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Hifz settings'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hifz settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Hifz settings'));
    await tester.pumpAndSettle();
    expect(find.text('Strict'), findsOneWidget);
    expect(find.text('Highlight the next word'), findsOneWidget);
    expect(find.text('Show mistakes'), findsOneWidget);
    expect(
      find.text('Vibrate on mistakes'),
      findsNothing,
      reason: 'Android only',
    );
    await tester.tap(find.text('Strict'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Strict')),
    );
    expect(container.read(hifzSettingsProvider).strict, isFalse);
  });

  testWidgets('Hifz status strip shows progress and a pending mistake', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HifzStatusStrip(
            state: HifzState(
              running: true,
              first: (ayahId: 2255, wordIndex: 0),
              last: (ayahId: 2255, wordIndex: 49),
              expected: (ayahId: 2255, wordIndex: 31),
              pending: HifzVerdict.wrong,
              counts: {HifzVerdict.correct: 31, HifzVerdict.wrong: 1},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Wrong word — recite it again'), findsOneWidget);
    expect(find.textContaining('✓ 31  ✗ 1'), findsOneWidget);
  });

  testWidgets('reveal buttons disable at the end of the last page', (
    tester,
  ) async {
    await tester.pumpWidget(app(pageCount: 5));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('mushaf body')),
    );
    container
        .read(mushafHideModeProvider.notifier)
        .reportPageWords(5, wordCount: 1);
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reveal next word'));
    await tester.pumpAndSettle();
    for (final key in ['mushaf-reveal-word', 'mushaf-reveal-ayah']) {
      final button = tester.widget<IconButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNull, reason: key);
    }
  });

  testWidgets('hide controls stay available while recording', (tester) async {
    await tester.pumpWidget(app(devPanel: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Listening…'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide ayahs'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reveal next word'), findsOneWidget);
    expect(find.byTooltip('Stop'), findsOneWidget);
  });

  testWidgets('leaving the Mushaf ends the recitation session', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Listening…'), findsOneWidget);

    mushafOpen.value = false;
    // The Mushaf clears its target, then the session stops (closing the
    // mic completes in the root zone).
    for (
      var i = 0;
      i < 20 && find.byTooltip('Listening…').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.pumpAndSettle();

    expect(find.byTooltip('Listening…'), findsNothing);
    expect(find.text('Home Quran Search'), findsOneWidget);
  });

  testWidgets('dev panel shows live recognition during a session', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recognition-dev-panel')), findsNothing);

    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recognition-dev-panel')), findsOneWidget);
    expect(find.textContaining('Fake · listening'), findsOneWidget);

    recognizer.events_
      ..add(const LivePartialTranscript('الله لا'))
      ..add(const LiveFinalTranscript('الله لا اله الا هو'));
    await tester.pumpAndSettle();
    expect(find.text('الله لا'), findsOneWidget);
    expect(find.text('الله لا اله الا هو'), findsOneWidget);
    expect(find.textContaining('1P/1F'), findsOneWidget);
  });

  testWidgets('no dev panel when it is disabled', (tester) async {
    await tester.pumpWidget(app(devPanel: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recognition-dev-panel')), findsNothing);
    expect(recognizer.inputs, hasLength(1), reason: 'recognition still runs');
  });

  testWidgets('opening a Mushaf swaps the navigation for the recitation bar', (
    tester,
  ) async {
    mushafOpen.value = false;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Home Quran Search'), findsOneWidget);
    expect(find.byKey(bar), findsNothing);

    mushafOpen.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(bar), findsOneWidget);
    expect(find.text('Home Quran Search'), findsNothing);
    expect(find.byTooltip('Start recitation'), findsOneWidget);
    expect(find.text('Top bar'), findsOneWidget);

    mushafOpen.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Home Quran Search'), findsOneWidget);
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('start → recording → pause/resume → stop', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();

    // One row: a recording indicator, no status text or timer.
    expect(find.byTooltip('Listening…'), findsOneWidget);
    expect(find.text('Listening…'), findsNothing);
    expect(find.text('0:00'), findsNothing);
    expect(find.byTooltip('Start recitation'), findsNothing);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Paused'), findsOneWidget);

    await tester.tap(find.byTooltip('Resume'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Listening…'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    // Closing the mic completes some futures in the root zone; let those
    // real microtasks run before settling the fake-async frame clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Listening…'), findsNothing);
    expect(find.byTooltip('Start recitation'), findsOneWidget);
    expect(find.textContaining('Recitation saved'), findsNothing);
    expect(
      repository.saved.single.startLocation,
      const QuranLocation.page(1, 5),
    );
  });

  testWidgets('permission denied shows a message and no session', (
    tester,
  ) async {
    source.permission = MicrophonePermission.denied;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Start recitation'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Microphone access is needed'), findsOneWidget);
    expect(find.byTooltip('Listening…'), findsNothing);
  });

  testWidgets('navigation is untouched where recitation is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(app(supported: false));
    await tester.pumpAndSettle();

    expect(find.text('Home Quran Search'), findsOneWidget);
    expect(find.byKey(bar), findsNothing);
  });

  test('formatRecitationDuration', () {
    expect(formatRecitationDuration(const Duration(seconds: 9)), '0:09');
    expect(
      formatRecitationDuration(const Duration(minutes: 12, seconds: 3)),
      '12:03',
    );
    expect(
      formatRecitationDuration(const Duration(hours: 1, seconds: 4)),
      '1:00:04',
    );
  });
}

class _WebPlatform implements PlatformCapabilities {
  const _WebPlatform();
  @override
  bool get isWeb => true;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get supportsBackgroundAudioSession => false;
  @override
  bool get supportsHomeScreenWidgets => false;
  @override
  bool get supportsScheduledNotifications => false;
  @override
  bool get supportsNativeFileStorage => false;
}
