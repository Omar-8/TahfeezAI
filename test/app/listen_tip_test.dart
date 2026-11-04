import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/guide/app_tips.dart';
import 'package:tahfeez_ai/features/listen/application/listen_options.dart';
import 'package:tahfeez_ai/features/listen/application/quran_audio_player.dart';
import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';

import '../test_helpers/real_app.dart';

/// Listen's tip: a translation read aloud after each ayah — offered as
/// Play is pressed, before anything plays (never while listening). Close:
/// it plays; "Show me": the translations, and it plays once one is chosen.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final now = DateTime(2026, 11, 3, 10);

  Future<(ProviderContainer, _Player)> open(WidgetTester tester) async {
    final player = _Player();
    final container = await RealApp.launch(
      tester,
      route: '/quran/surah/112',
      size: const Size(400, 900),
      overrides: [
        recitationSupportedProvider.overrideWithValue(true),
        appTipsEnabledProvider.overrideWithValue(true),
        appTipsClockProvider.overrideWithValue(() => now),
        appTipsRandomProvider.overrideWithValue(_Heads()),
        quranAudioPlayerProvider.overrideWith(() => player),
      ],
    );
    final storage = container.read(browserStorageProvider);
    await tester.runAsync(() async {
      await storage.remove('appTips.lastShown');
      await storage.remove('appTips.off.listenTranslation');
      await storage.setString(
        'appTips.firstSeen',
        now.subtract(const Duration(days: 3)).toIso8601String(),
      );
    });
    // Its menu (a tap on Listen plays at once, as last set).
    await tester.tap(find.byKey(const ValueKey('listen-open-settings')));
    await RealApp.settle(tester);
    return (container, player);
  }

  Future<void> play(WidgetTester tester) async {
    final play = find.byKey(const ValueKey('listen-play'));
    await tester.ensureVisible(play);
    await tester.pumpAndSettle();
    await tester.tap(play);
    await RealApp.settle(tester);
  }

  testWidgets('Close: nothing played before it; then it plays', (tester) async {
    final (_, player) = await open(tester);
    await play(tester);
    expect(
      find.byKey(const ValueKey('app-tip-listenTranslation')),
      findsOneWidget,
    );
    expect(player.played, isNull, reason: 'not before the tip is closed');
    await tester.tap(find.byKey(const ValueKey('app-tip-close')));
    await RealApp.settle(tester);
    expect(player.played, isNotNull);
    expect(player.played!.translationVoice, '');
    await RealApp.quit(tester);
  });

  testWidgets('Show me: the translations; one chosen, it plays with it', (
    tester,
  ) async {
    final (_, player) = await open(tester);
    await play(tester);
    await tester.tap(find.byKey(const ValueKey('app-tip-show')));
    await RealApp.settle(tester);
    expect(player.played, isNull);
    await tester.tap(find.byKey(const ValueKey('translation-voice-en.walk')));
    await RealApp.settle(tester);
    expect(player.played?.translationVoice, 'en.walk');
    await RealApp.quit(tester);
  });

  testWidgets('"Don\'t show tips again": Play plays at once from then on', (
    tester,
  ) async {
    final (container, player) = await open(tester);
    await tester.runAsync(
      () => appTipsAllOff(container.read(browserStorageProvider)),
    );
    await play(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(player.played, isNotNull);
    await tester.runAsync(
      () => container.read(browserStorageProvider).remove('appTips.allOff'),
    );
    await RealApp.quit(tester);
  });
}

/// Plays nothing: keeps what it was asked to play.
class _Player extends QuranAudioPlayer {
  ListenOptions? played;

  @override
  NowPlaying? build() => null;

  @override
  Future<bool> playRange(int from, int to, {ListenOptions? options}) async {
    played = options;
    return true;
  }
}

class _Heads implements Random {
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
}
