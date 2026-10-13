import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';

import '../test_helpers/real_app.dart';

/// Every screen's every control, one at a time: the app started afresh on
/// the screen, the control tapped (or long-pressed), the app settled —
/// without an error, an overflow or anything thrown.
///
/// What only a device has (the microphone, files, links, sharing, sound)
/// answers "not here" and is let through. Skipped on ordinary test runs;
/// run with `tool/test_crawl.sh` — in shards, under a memory cap (each start
/// keeps some memory until the process ends).
void main() {
  final crawl = Platform.environment['TAHFEEZ_CRAWL'] == '1';
  // Up to this many controls a screen (a test each, so one failure names
  // its control and the rest still run).
  final most = int.tryParse(Platform.environment['CRAWL_MOST'] ?? '') ?? 80;
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  const screens = <String, (String, ReaderMode, AyahLayout)>{
    'Home': ('/home', ReaderMode.mushaf, AyahLayout.paged),
    'Quran': ('/quran', ReaderMode.mushaf, AyahLayout.paged),
    'Bookmarks': ('/quran/bookmarks', ReaderMode.mushaf, AyahLayout.paged),
    'Search': ('/quran/search', ReaderMode.mushaf, AyahLayout.paged),
    'Memorize': ('/memorize', ReaderMode.mushaf, AyahLayout.paged),
    'Progress': ('/memorize/progress', ReaderMode.mushaf, AyahLayout.paged),
    'Settings': ('/settings', ReaderMode.mushaf, AyahLayout.paged),
    'About': ('/settings/about', ReaderMode.mushaf, AyahLayout.paged),
    'Mushaf': ('/quran/surah/36', ReaderMode.mushaf, AyahLayout.paged),
    'Ayah mode': ('/quran/surah/36', ReaderMode.ayah, AyahLayout.paged),
    'Ayah mode continuous': (
      '/quran/surah/36',
      ReaderMode.ayah,
      AyahLayout.continuous,
    ),
  };

  /// Only a device can: no plugin here.
  bool deviceOnly(Object error) =>
      error is MissingPluginException ||
      '$error'.contains('MissingPluginException') ||
      '$error'.contains('No implementation found for method');

  /// What can be tapped, or long-pressed, on screen now.
  Finder controls({required bool long}) => find.byWidgetPredicate((w) {
    if (w is InkWell) return long ? w.onLongPress != null : w.onTap != null;
    if (w is GestureDetector) {
      return long ? w.onLongPress != null : w.onTap != null;
    }
    return false;
  }).hitTestable();

  Future<void> act(
    WidgetTester tester,
    String screen,
    int index, {
    required bool long,
  }) async {
    final (route, mode, layout) = screens[screen]!;
    await RealApp.launch(tester, route: route, mode: mode, layout: layout);
    RealApp.fits(tester, '$screen opens', ignore: deviceOnly);
    final all = controls(long: long);
    final count = all.evaluate().length;
    if (index == 0) {
      debugPrint(
        'Crawl: $screen has $count ${long ? 'long-press' : 'tap'} '
        'controls',
      );
    }
    // More than this crawl reaches: none left untried unnoticed — but for
    // a screen of many alike (Progress: a cell per page), tried in part.
    if (index == (long ? _mostLong : most) - 1 &&
        count > index + 1 &&
        !_sampled.contains(screen)) {
      fail('$screen has $count controls; raise the limit');
    }
    if (index >= count) {
      await RealApp.quit(tester);
      return;
    }
    final target = all.at(index);
    final label = _describe(tester, target);
    if (long) {
      await tester.longPress(target, warnIfMissed: false);
    } else {
      await tester.tap(target, warnIfMissed: false);
    }
    await RealApp.settle(tester);
    RealApp.fits(
      tester,
      '$screen, ${long ? 'long-pressed' : 'tapped'} #$index ($label)',
      ignore: deviceOnly,
    );
    // Back out of whatever it opened.
    await tester.binding.handlePopRoute();
    await RealApp.settle(tester);
    RealApp.fits(tester, '$screen, back after #$index', ignore: deviceOnly);
    await RealApp.quit(tester);
  }

  for (final screen in screens.keys) {
    for (var i = 0; i < most; i++) {
      testWidgets(
        '$screen: tap #$i',
        (tester) => act(tester, screen, i, long: false),
        skip: !crawl,
      );
    }
    for (var i = 0; i < _mostLong; i++) {
      testWidgets(
        '$screen: long-press #$i',
        (tester) => act(tester, screen, i, long: true),
        skip: !crawl,
      );
    }
  }
}

/// A control's words (its own text, or a tooltip), to tell which it was.
String _describe(WidgetTester tester, Finder control) {
  final texts = [
    for (final e
        in find
            .descendant(of: control, matching: find.byType(Text))
            .evaluate()
            .take(2))
      (e.widget as Text).data ?? '',
    for (final e
        in find
            .descendant(of: control, matching: find.byType(Tooltip))
            .evaluate()
            .take(1))
      (e.widget as Tooltip).message ?? '',
    for (final e
        in find
            .descendant(of: control, matching: find.byType(Icon))
            .evaluate()
            .take(1))
      '${(e.widget as Icon).icon?.codePoint.toRadixString(16)}',
  ].where((t) => t.isNotEmpty);
  return texts.join(' / ');
}

const _mostLong = 16;

/// Screens of many alike controls, crawled in part.
const _sampled = {'Progress'};
