import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/core_providers.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/home/presentation/hijri_calendar_screen.dart';
import 'package:tahfeez_ai/features/prayer/application/saved_place.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_place.dart';

import '../../test_helpers/real_app.dart';
import '../../test_helpers/web_platform.dart';

/// In a browser (owner, 2026-11-23, web only): on a wide Home the date and
/// the prayer times side by side, the six times in one row; the Hijri
/// calendar's days short enough for the month's events to show without
/// scrolling. The apps unchanged.
void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  Finder key(String k) => find.byKey(ValueKey(k));
  final web = [
    platformCapabilitiesProvider.overrideWithValue(const WebPlatform()),
  ];
  const makkah = QiblaPlace(
    latitude: 21.4225,
    longitude: 39.8262,
    name: 'Makkah',
    country: 'SA',
  );

  for (final (name, size, overrides, sideBySide, oneRow) in [
    ('a browser window', const Size(1440, 900), web, true, true),
    ('a narrow browser', const Size(390, 844), web, false, false),
    (
      'the app on a 13" iPad',
      const Size(1032, 1376),
      <Override>[],
      false,
      false,
    ),
  ]) {
    testWidgets('$name: the date and prayer times '
        '${sideBySide ? 'side by side' : 'one above the other'}, '
        '${oneRow ? 'one row' : 'two rows'} of times', (tester) async {
      final c = await RealApp.launch(tester, size: size, overrides: overrides);
      await c.read(savedPlaceProvider.notifier).set(makkah);
      await RealApp.settle(tester);
      RealApp.fits(tester, 'Home on $name');
      expect(key('home-today-row'), sideBySide ? findsOneWidget : findsNothing);
      final date = tester.getRect(key('home-date'));
      final prayer = tester.getRect(key('home-prayer'));
      if (sideBySide) {
        expect((date.top - prayer.top).abs(), lessThan(1));
        expect((date.height - prayer.height).abs(), lessThan(1));
        expect(date.right, lessThan(prayer.left));
        // The date's text in the middle of its taller card.
        final today = tester.getRect(key('home-date-today'));
        final hijri = tester.getRect(key('home-date-hijri'));
        expect((today.top + hijri.bottom) / 2, closeTo(date.center.dy, 2));
      } else {
        expect(prayer.top, greaterThan(date.bottom));
      }
      expect(
        key('home-prayer-one-row'),
        oneRow ? findsOneWidget : findsNothing,
      );
      final fajr = tester.getRect(key('home-prayer-fajr'));
      final isha = tester.getRect(key('home-prayer-isha'));
      expect((fajr.top - isha.top).abs() < 1, oneRow);
      await c
          .read(browserStorageProvider)
          .remove(SavedPlaceController.storageKey);
      await RealApp.quit(tester);
    });
  }

  for (final (name, overrides, short) in [
    ('a browser', web, true),
    ('the app', <Override>[], false),
  ]) {
    testWidgets('the Hijri calendar in $name: '
        '${short ? 'short days' : 'days as before'}', (tester) async {
      await RealApp.launch(
        tester,
        route: '/calendar',
        size: const Size(1440, 900),
        overrides: overrides,
      );
      RealApp.fits(tester, 'the Hijri calendar in $name');
      final day = tester.getSize(key('hijri-day-1'));
      if (short) {
        expect(day.height, lessThanOrEqualTo(hijriWebDayHeight + 0.5));
        // The month, and its foot, within the window.
        expect(tester.getRect(key('hijri-grid')).bottom, lessThan(600));
      } else {
        expect(day.height, greaterThan(day.width));
      }
      await RealApp.quit(tester);
    });
  }
}
