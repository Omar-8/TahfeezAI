import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/generated/app_localizations.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/core/ui/first_run.dart';
import 'package:tahfeez_ai/features/guide/app_tips.dart';
import 'package:tahfeez_ai/features/guide/app_tips_host.dart';
import 'package:tahfeez_ai/features/guide/guide.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';

class _Memory implements BrowserStorage {
  final values = <String, Object?>{};

  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
  @override
  Future<void> clearExcept(Set<String> keep) async =>
      values.removeWhere((k, _) => !keep.contains(k));
  @override
  Future<Map<String, Object?>> readAll() async => {...values};
  @override
  Future<void> writeAll(Map<String, Object?> v) async => values.addAll(v);
}

/// The coin always [value].
class _Coin implements Random {
  _Coin(this.value);

  double value;

  @override
  double nextDouble() => value;
  @override
  bool nextBool() => value < 0.5;
  @override
  int nextInt(int max) => (value * max).floor();
}

/// A player that plays nothing: its state set by the test.
class _Player extends QuranAudioPlayer {
  @override
  NowPlaying? build() => null;

  void set(NowPlaying? now) => state = now;
}

/// "Did you know" tips: none on the first day, then at most one every two
/// days, at random moments; each can be turned off for good.
void main() {
  final day0 = DateTime(2026, 11, 3, 10);

  group('appTipDue', () {
    test(
      'not on the first day; then due, and not again for two days',
      () async {
        final storage = _Memory();
        final heads = _Coin(0);
        Future<bool> due(DateTime now, [AppTip tip = AppTip.pageTheme]) =>
            appTipDue(storage, tip, now: now, random: heads);
        expect(await due(day0), isFalse, reason: 'the first day starts');
        expect(await due(day0.add(const Duration(hours: 23))), isFalse);
        final shown = day0.add(const Duration(days: 1));
        expect(await due(shown), isTrue);
        expect(
          await due(
            shown.add(const Duration(days: 1)),
            AppTip.listenTranslation,
          ),
          isFalse,
          reason: 'one tip every two days, whichever it is',
        );
        expect(
          await due(
            shown.add(const Duration(days: 2)),
            AppTip.listenTranslation,
          ),
          isTrue,
        );
      },
    );

    test('at random: tails, not now (and not counted as shown)', () async {
      final storage = _Memory();
      final coin = _Coin(0.9);
      await appTipsStart(storage, day0);
      final later = day0.add(const Duration(days: 3));
      expect(
        await appTipDue(storage, AppTip.pageTheme, now: later, random: coin),
        isFalse,
      );
      coin.value = 0.1;
      expect(
        await appTipDue(storage, AppTip.pageTheme, now: later, random: coin),
        isTrue,
      );
    });

    test('turned off: never again; the other tip still comes', () async {
      final storage = _Memory();
      await appTipsStart(storage, day0);
      await appTipOff(storage, AppTip.pageTheme);
      final later = day0.add(const Duration(days: 30));
      expect(
        await appTipDue(
          storage,
          AppTip.pageTheme,
          now: later,
          random: _Coin(0),
        ),
        isFalse,
      );
      expect(
        await appTipDue(
          storage,
          AppTip.listenTranslation,
          now: later,
          random: _Coin(0),
        ),
        isTrue,
      );
    });
  });

  group('in the reader', () {
    late _Memory storage;
    late ProviderContainer container;

    Future<void> open(WidgetTester tester) async {
      storage = _Memory()
        ..values['appTips.firstSeen'] = day0
            .subtract(const Duration(days: 3))
            .toIso8601String();
      container = ProviderContainer(
        overrides: [
          firstRunPromptsProvider.overrideWithValue(true),
          browserStorageProvider.overrideWithValue(storage),
          appTipsClockProvider.overrideWithValue(() => day0),
          appTipsRandomProvider.overrideWithValue(_Coin(0)),
          quranAudioPlayerProvider.overrideWith(_Player.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              appBar: AppBar(actions: const [AppTipsHost()]),
              body: const SizedBox.expand(),
            ),
          ),
        ),
      );
    }

    void play({String translationVoice = ''}) =>
        (container.read(quranAudioPlayerProvider.notifier) as _Player).set(
          NowPlaying.ayahs(
            const [1001, 1002, 1003],
            0,
            null,
            options: ListenOptions(translationVoice: translationVoice),
          ),
        );

    testWidgets('a while into reading: the page themes; Show me opens them, '
        'lit, and it is not shown again', (tester) async {
      await open(tester);
      await tester.pump(AppTipsHost.readingDelay - const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('app-tip-pageTheme')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-tip-pageTheme')), findsOneWidget);
      expect(find.text('Show me'), findsOneWidget);
      expect(find.text("Don't show this again"), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('app-tip-show')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mushaf-page-theme')), findsOneWidget);
      expect(container.read(guideProvider)?.tour, GuideTour.tipPageTheme);
      expect(storage.values['appTips.off.pageTheme'], isTrue);
      // A theme tapped: the guide is over (not back to the modes' tour).
      await tester.tap(
        find.byKey(const ValueKey('mushaf-page-theme-sepia')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(container.read(guideProvider), isNull);
    });

    testWidgets('listening without a translation: its tip; "Don\'t show '
        'this again" and Close: off for good', (tester) async {
      await open(tester);
      play();
      await tester.pump(AppTipsHost.readingDelay);
      expect(
        find.byKey(const ValueKey('app-tip-pageTheme')),
        findsNothing,
        reason: 'not the page themes while listening',
      );
      await tester.pump(AppTipsHost.listeningDelay);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-tip-listenTranslation')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('app-tip-never')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('app-tip-close')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('app-tip-listenTranslation')),
        findsNothing,
      );
      expect(storage.values['appTips.off.listenTranslation'], isTrue);
      expect(container.read(guideProvider), isNull);
    });

    testWidgets('Close alone: it may come again another day', (tester) async {
      await open(tester);
      play();
      await tester.pump(AppTipsHost.listeningDelay);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-tip-close')));
      await tester.pumpAndSettle();
      expect(storage.values['appTips.off.listenTranslation'], isNull);
      expect(storage.values['appTips.lastShown'], day0.toIso8601String());
    });

    testWidgets('listening with a translation already: no tip', (tester) async {
      await open(tester);
      play(translationVoice: 'en.walk');
      await tester.pump(AppTipsHost.listeningDelay * 2);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
