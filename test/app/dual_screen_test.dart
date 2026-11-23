import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/routing/app_router.dart';
import 'package:tahfeez_ai/core/ui/display_hinge.dart';
import 'package:tahfeez_ai/features/mushaf/application/reader_mode.dart';

import 'package:tahfeez_ai/features/recitation/application/recitation_providers.dart';

import '../test_helpers/real_app.dart';

/// A dual-screen device spanned (owner, 2026-11-23): nothing under the
/// hinge — the app on one screen (the one reading starts on), the other
/// showing Tahfeez's emblem; the Mushaf's pages a page on each screen.
/// Without a hinge, nothing of this.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  const side = Size(1114, 720);
  const sideHinge = Rect.fromLTWH(540, 0, 34, 720);
  const stacked = Size(720, 1114);
  const stackedHinge = Rect.fromLTWH(0, 540, 720, 34);
  final other = find.byKey(const ValueKey('dual-screen-other'));
  final shortcuts = find.byKey(const ValueKey('home-shortcuts'));
  final spine = find.byKey(const ValueKey('mushaf-hinge-spine'));

  test('a hinge only: not a fold, nor one short of the window', () {
    DisplayHinge? of(List<DisplayFeature> f) =>
        DisplayHinge.fromFeatures(f, side);
    DisplayFeature f(Rect r, DisplayFeatureType t) => DisplayFeature(
      bounds: r,
      type: t,
      state: t == DisplayFeatureType.cutout
          ? DisplayFeatureState.unknown
          : DisplayFeatureState.postureFlat,
    );
    expect(of(const []), isNull);
    expect(of([f(sideHinge, DisplayFeatureType.hinge)])!.vertical, isTrue);
    expect(
      of([f(const Rect.fromLTWH(557, 0, 0, 720), DisplayFeatureType.fold)]),
      isNull,
    );
    expect(
      of([f(const Rect.fromLTWH(0, 0, 100, 30), DisplayFeatureType.cutout)]),
      isNull,
    );
    expect(
      of([f(const Rect.fromLTWH(540, 0, 34, 300), DisplayFeatureType.hinge)]),
      isNull,
    );
    final h = of([f(sideHinge, DisplayFeatureType.hinge)])!;
    expect(h.screen(first: true), const Rect.fromLTWH(0, 0, 540, 720));
    expect(h.screen(first: false), const Rect.fromLTWH(574, 0, 540, 720));
  });

  testWidgets('side by side: Home on the left screen, the emblem on the '
      'right', (tester) async {
    await RealApp.launch(tester, size: side, hinge: sideHinge);
    RealApp.fits(tester, 'Home');
    expect(other, findsOneWidget);
    expect(tester.getRect(other), const Rect.fromLTWH(574, 0, 540, 720));
    expect(tester.getRect(shortcuts).right, lessThanOrEqualTo(540));
    await RealApp.quit(tester);
  });

  testWidgets('in Arabic: the app on the right screen', (tester) async {
    await RealApp.launch(tester, size: side, hinge: sideHinge, locale: 'ar');
    expect(tester.getRect(other), const Rect.fromLTWH(0, 0, 540, 720));
    expect(tester.getRect(shortcuts).left, greaterThanOrEqualTo(574));
    await RealApp.quit(tester);
  });

  testWidgets('one above the other: the app on the top screen', (tester) async {
    await RealApp.launch(tester, size: stacked, hinge: stackedHinge);
    RealApp.fits(tester, 'Home');
    expect(tester.getRect(other), const Rect.fromLTWH(0, 574, 720, 540));
    expect(tester.getRect(shortcuts).bottom, lessThanOrEqualTo(540));
    await RealApp.quit(tester);
  });

  testWidgets('the Mushaf: both screens, a page on each, the hinge the '
      'spine; Ayah mode\'s continuous list on one', (tester) async {
    final c = await RealApp.launch(
      tester,
      size: side,
      hinge: sideHinge,
      // As on a phone: the recitation bar in place of the rail.
      overrides: [recitationSupportedProvider.overrideWithValue(true)],
    );
    c.read(appRouterProvider).go('/quran/page/1/50');
    await RealApp.settle(tester);
    RealApp.fits(tester, 'Mushaf');
    expect(other, findsNothing);
    // (Under the reader's bar, down to the recitation bar.)
    final r = tester.getRect(spine);
    expect([r.left, r.right], [540, 574]);
    expect(r.height, greaterThan(400));
    // The bar as in a browser (owner, 2026-11-23): its modes under one
    // page, hide mode's buttons under the other — nothing under the hinge.
    final bar = find.byKey(const ValueKey('recitation-bottom-bar'));
    for (final type in [Text, Icon]) {
      for (final e
          in find.descendant(of: bar, matching: find.byType(type)).evaluate()) {
        final r = tester.getRect(find.byElementPredicate((x) => x == e));
        if (r.isEmpty) continue;
        expect(
          r.right <= 540 || r.left >= 574,
          isTrue,
          reason: '$type at $r is under the hinge',
        );
      }
    }
    // Back to Home: one screen again.
    c.read(appRouterProvider).go('/home');
    await RealApp.settle(tester);
    expect(other, findsOneWidget);
    expect(spine, findsNothing);
    await RealApp.quit(tester);

    final c2 = await RealApp.launch(
      tester,
      size: side,
      hinge: sideHinge,
      mode: ReaderMode.ayah,
      layout: AyahLayout.continuous,
    );
    c2.read(appRouterProvider).go('/quran/surah/36');
    await RealApp.settle(tester);
    RealApp.fits(tester, 'Ayah mode');
    expect(other, findsOneWidget);
    await RealApp.quit(tester);
  });

  testWidgets('no hinge (a phone, a tablet, a browser): as ever', (
    tester,
  ) async {
    await RealApp.launch(tester, size: side);
    expect(other, findsNothing);
    expect(tester.getRect(shortcuts).right, greaterThan(574));
    await RealApp.quit(tester);
  });
}
