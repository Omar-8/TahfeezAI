import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_audio.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_haptics.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_progress.dart';
import 'package:tahfeez_ai/features/athkar/data/athkar_source.dart';
import 'package:tahfeez_ai/features/athkar/domain/athkar.dart';
import 'package:tahfeez_ai/features/athkar/presentation/athkar_category_screen.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/real_app.dart';

/// Plays nothing: what was asked, and fails when told to (offline).
class _FakePlayer implements AthkarPlayer {
  final played = <Uri>[];
  var stopped = 0;
  var offline = false;

  Completer<void>? _playing;

  @override
  Future<void> play(Uri uri) async {
    if (offline) throw const SocketException('offline');
    played.add(uri);
    // Until stopped (as the real one: its stop ends the play).
    await (_playing = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    stopped++;
    if (!(_playing?.isCompleted ?? true)) _playing!.complete();
  }

  @override
  Future<void> dispose() => stop();
}

/// Athkar (owner, 2026-11-21): from Home and the side menu; chapters as
/// tiles in sections, searched; a chapter's athkar as tiles ticked once
/// said, and one after another — counted with a tap, on by themselves.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final book = AthkarBook.fromJson(
    jsonDecode(utf8.decode(gzip.decode(File(kAthkarAsset).readAsBytesSync())))
        as Map<String, Object?>,
  );
  late List<bool> felt;
  late _FakePlayer player;

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/home',
    String locale = 'en',
  }) {
    felt = [];
    player = _FakePlayer();
    return RealApp.launch(
      tester,
      route: route,
      locale: locale,
      overrides: [
        athkarHapticsProvider.overrideWithValue(
          ({required bool done}) => felt.add(done),
        ),
        athkarPlayerFactoryProvider.overrideWithValue(() => player),
      ],
    );
  }

  /// Today's counts cleared (kept on the phone between tests).
  Future<void> clear(ProviderContainer c) async {
    for (final category in book.categories) {
      c.read(athkarProgressProvider.notifier).reset(category);
    }
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets("Home's Athkar: the chapters in sections; searched by a "
      'title or a zikr, in English or Arabic', (tester) async {
    final c = await launch(tester);
    await RealApp.settle(tester);
    await tester.tap(key('home-athkar'));
    await RealApp.settle(tester);
    // The sections as tiles, not their chapters (owner, 2026-11-21).
    expect(key('athkar-section-daily'), findsOneWidget);
    expect(key('athkar-section-hajj'), findsOneWidget);
    expect(key('athkar-category-27'), findsNothing);
    // A section: its chapters as tiles, under its name.
    await tester.tap(key('athkar-section-daily'));
    await RealApp.settle(tester);
    expect(find.text('Morning, evening & sleep'), findsOneWidget);
    expect(find.text('Waking up'), findsOneWidget, reason: 'short names');
    expect(key('athkar-category-27'), findsOneWidget);
    expect(key('athkar-category-28'), findsOneWidget);
    expect(key('athkar-category-12'), findsNothing, reason: 'another section');
    await tester.pageBack();
    await RealApp.settle(tester);

    await tester.enterText(key('athkar-search'), 'before sleeping');
    await RealApp.settle(tester);
    expect(key('athkar-category-28'), findsOneWidget);
    expect(key('athkar-category-27'), findsNothing);
    expect(key('athkar-section-daily'), findsNothing, reason: 'flat results');

    // In Arabic, its marks aside: «الكرسي» finds Ayat al-Kursi's chapters.
    await tester.enterText(key('athkar-search'), 'كرسيه');
    await RealApp.settle(tester);
    expect(key('athkar-category-27'), findsOneWidget);
    await tester.enterText(key('athkar-search'), 'zzzz');
    await RealApp.settle(tester);
    expect(find.textContaining('No results'), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('a chapter: Start, each zikr counted with a tap and on to the '
      'next by itself; its tiles ticked, "x of y done"', (tester) async {
    final c = await launch(tester, route: '/athkar/27');
    await RealApp.settle(tester);
    final me = book.category(27)!;
    final first = me.athkar[0], second = me.athkar[1];
    expect(first.repeat, 1);
    expect(second.repeat, 3);
    expect(find.text('0 of 24 done'), findsOneWidget);
    await tester.tap(key('athkar-start'));
    await RealApp.settle(tester);
    expect(key('athkar-card-${first.id}'), findsOneWidget);
    expect(find.textContaining('1 / 24'), findsOneWidget);

    // Once: done, felt, and on to the next.
    await tester.tap(key('athkar-card-${first.id}'));
    await tester.pump();
    expect(felt, [true]);
    await tester.pump(AthkarReaderScreen.advanceAfter);
    await RealApp.settle(tester);
    expect(find.textContaining('2 / 24'), findsOneWidget);

    // Three times, on its counter: the third finishes it.
    for (var i = 0; i < 3; i++) {
      await tester.tap(key('athkar-counter-${second.id}'));
      await tester.pump();
    }
    expect(felt, [true, false, false, true]);
    await tester.pump(AthkarReaderScreen.advanceAfter);
    await RealApp.settle(tester);
    expect(find.textContaining('3 / 24'), findsOneWidget);

    // Swiped back: counted already, no more.
    await tester.tap(key('athkar-previous'));
    await RealApp.settle(tester);
    await tester.tap(key('athkar-counter-${second.id}'));
    await tester.pump();
    expect(felt, hasLength(4));

    // Back to its tiles: the two ticked; Continue, from the third.
    await tester.pageBack();
    await RealApp.settle(tester);
    expect(find.text('2 of 24 done'), findsOneWidget);
    expect(key('athkar-zikr-done-${first.id}'), findsOneWidget);
    expect(key('athkar-zikr-done-${second.id}'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(key('athkar-start'));
    await RealApp.settle(tester);
    expect(find.textContaining('3 / 24'), findsOneWidget);
    await tester.pageBack();
    await RealApp.settle(tester);

    // Start again: today's for this chapter cleared.
    await tester.tap(key('athkar-start-again'));
    await RealApp.settle(tester);
    expect(find.text('0 of 24 done'), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('a chapter of one zikr opens on it; done, its tile ticked on '
      'the Athkar page', (tester) async {
    final c = await launch(tester, route: '/athkar/section/home');
    await RealApp.settle(tester);
    final restroom = book.category(6)!;
    expect(restroom.athkar, hasLength(1));
    await tester.tap(key('athkar-category-6'));
    await RealApp.settle(tester);
    final zikr = restroom.athkar.single;
    expect(key('athkar-card-${zikr.id}'), findsOneWidget);
    expect(key('athkar-start'), findsNothing, reason: 'no tiles for one');
    await tester.tap(key('athkar-card-${zikr.id}'));
    await tester.pump(AthkarReaderScreen.advanceAfter);
    await RealApp.settle(tester);
    expect(key('athkar-all-done'), findsNothing, reason: 'stays on it');
    await tester.pageBack();
    await RealApp.settle(tester);
    expect(key('athkar-category-done-6'), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('the last zikr done: "All done"', (tester) async {
    final c = await launch(tester, route: '/athkar/9');
    await RealApp.settle(tester);
    final chapter = book.category(9)!;
    await tester.tap(key('athkar-start'));
    await RealApp.settle(tester);
    for (final z in chapter.athkar) {
      for (var i = 0; i < z.repeat; i++) {
        await tester.tap(key('athkar-counter-${z.id}'));
        await tester.pump();
      }
      await tester.pump(AthkarReaderScreen.advanceAfter);
      await RealApp.settle(tester);
    }
    expect(key('athkar-all-done'), findsOneWidget);
    expect(find.textContaining('All done'), findsOneWidget);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('its translation: English under the Arabic — said to be '
      'English in other languages; none in Arabic', (tester) async {
    final zikr = book.category(27)!.athkar[1];
    for (final (locale, english, note) in [
      ('en', true, false),
      ('fr', true, true),
      ('ar', false, false),
    ]) {
      final c = await launch(
        tester,
        route: '/athkar/27/read?at=1',
        locale: locale,
      );
      await RealApp.settle(tester);
      expect(key('athkar-arabic-${zikr.id}'), findsOneWidget);
      expect(
        key('athkar-english-${zikr.id}'),
        english ? findsOneWidget : findsNothing,
        reason: locale,
      );
      expect(
        find.text('Traduction en anglais'),
        note ? findsOneWidget : findsNothing,
        reason: locale,
      );
      await clear(c);
      await RealApp.quit(tester);
    }
  });

  testWidgets("a chapter's long name whole (not cut short); the counter "
      'between the arrows, at the foot', (tester) async {
    final c = await launch(tester, route: '/athkar/30');
    await RealApp.settle(tester);
    final long = book.category(30)!;
    // Its short name; the book's in full under it, whole.
    final heading = tester.widget<Text>(key('athkar-heading'));
    expect(heading.data, long.titleIn('en'));
    final full = tester.widget<Text>(key('athkar-heading-full'));
    expect(full.data, long.english);
    expect(full.maxLines, isNull);
    expect(full.overflow, isNull);
    // (One zikr: its card at once.)
    final zikr = long.athkar.single;
    final counter = tester.getRect(key('athkar-counter-${zikr.id}'));
    final card = tester.getRect(key('athkar-card-${zikr.id}'));
    expect(counter.top, greaterThan(card.bottom), reason: 'under the card');
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.height - counter.bottom, lessThan(64), reason: 'at the foot');
    await RealApp.quit(tester);
    await clear(c);

    final m = await launch(tester, route: '/athkar/27/read?at=1');
    await RealApp.settle(tester);
    final second = book.category(27)!.athkar[1];
    final row = tester.getRect(key('athkar-counter-${second.id}'));
    for (final k in ['athkar-previous', 'athkar-next']) {
      expect(
        tester.getCenter(key(k)).dy,
        closeTo(row.center.dy, 12),
        reason: '$k beside the counter',
      );
    }
    await clear(m);
    await RealApp.quit(tester);
  });

  testWidgets('right to left: previous at the right, pointing right', (
    tester,
  ) async {
    final c = await launch(tester, route: '/athkar/27/read?at=1', locale: 'ar');
    await RealApp.settle(tester);
    final previous = tester.getCenter(key('athkar-previous'));
    final next = tester.getCenter(key('athkar-next'));
    expect(previous.dx, greaterThan(next.dx));
    Icon icon(String k) => tester.widget<Icon>(
      find.descendant(of: key(k), matching: find.byType(Icon)),
    );
    expect(icon('athkar-previous').icon, Icons.chevron_right_rounded);
    expect(icon('athkar-next').icon, Icons.chevron_left_rounded);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('listening: from hisnmuslim.com, stopped with the same '
      'button; offline, said so', (tester) async {
    final c = await launch(tester, route: '/athkar/27/read?at=0');
    await RealApp.settle(tester);
    final zikr = book.category(27)!.athkar[0];
    await tester.tap(find.byTooltip('Listen'));
    await tester.pump();
    expect(
      player.played.single.toString(),
      'https://www.hisnmuslim.com/audio/ar/${zikr.audio}',
    );
    expect(find.byTooltip('Stop listening'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop listening'));
    await tester.pump();
    expect(player.stopped, greaterThan(0));
    expect(find.byTooltip('Listen'), findsOneWidget);

    player.offline = true;
    await tester.tap(find.byTooltip('Listen'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('hisnmuslim.com'), findsOneWidget);
    await RealApp.settle(tester);
    await clear(c);
    await RealApp.quit(tester);
  });

  testWidgets('from the side menu', (tester) async {
    await launch(tester);
    await RealApp.settle(tester);
    await openFromMenu(tester, 'athkar');
    expect(key('athkar-search'), findsOneWidget);
    await RealApp.quit(tester);
  });
}
