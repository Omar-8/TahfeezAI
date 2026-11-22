import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/qibla/data/city_index.dart';
import 'package:tahfeez_ai/features/qibla/data/qibla_sensors.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_math.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_place.dart';

import '../../test_helpers/fake_qibla_sensors.dart';
import '../../test_helpers/real_app.dart';

void main() {
  group('the qibla', () {
    // Published qibla directions (great circle, degrees from true north).
    for (final (city, lat, lon, bearing, km) in [
      ('London', 51.5072, -0.1276, 118.99, 4794),
      ('New York', 40.7128, -74.0060, 58.48, 10306),
      ('Jakarta', -6.2088, 106.8456, 295.15, 7920),
      ('Sydney', -33.8688, 151.2093, 277.50, 13236),
      ('Cairo', 30.0444, 31.2357, 136.14, 1287),
    ]) {
      test('$city: $bearing°, $km km', () {
        expect(qiblaBearing(lat, lon), closeTo(bearing, 0.05));
        expect(distanceToKaabaKm(lat, lon), closeTo(km, 2));
      });
    }

    test('which way to turn, the short way round', () {
      expect(turnTowards(100, 119), closeTo(19, 1e-9));
      expect(turnTowards(130, 119), closeTo(-11, 1e-9));
      expect(turnTowards(350, 10), closeTo(20, 1e-9));
      expect(turnTowards(10, 350), closeTo(-20, 1e-9));
      expect(normalizeDegrees(-30), 330);
    });

    test("a place kept and read back; a city's flag", () {
      const cairo = QiblaPlace(
        latitude: 30.0626,
        longitude: 31.2497,
        name: 'Cairo',
        country: 'EG',
      );
      expect(QiblaPlace.decode(cairo.encode()), cairo);
      expect(cairo.flag, '🇪🇬');
      expect(QiblaPlace.decode('not json'), isNull);
    });
  });

  group('the cities', () {
    final index = CityIndex.fromJson(
      jsonDecode(utf8.decode(gzip.decode(File(kCitiesAsset).readAsBytesSync())))
          as Map<String, Object?>,
    );

    test('found by name in Latin and in their own scripts', () {
      expect(index.length, greaterThan(12000));
      expect(index.search('cairo').first.name, 'Cairo');
      expect(index.search('القاهرة').first.name, 'Cairo');
      expect(index.search('مكة').first.name, 'Makkah');
      expect(index.search('chennai').first.name, 'Chennai');
      expect(index.search('சென்னை').first.name, 'Chennai');
      expect(index.search('São Paulo').first.name, 'São Paulo');
      expect(index.search('sao paulo').first.name, 'São Paulo');
      expect(index.search('xqzv'), isEmpty);
      expect(index.search(''), isEmpty);
    });
  });

  group('the Qibla finder', () {
    final cities = CityIndex.fromJson(
      jsonDecode(utf8.decode(gzip.decode(File(kCitiesAsset).readAsBytesSync())))
          as Map<String, Object?>,
    );
    setUpAll(RealApp.prepare);
    tearDownAll(RealApp.close);

    Future<FakeQiblaSensors> open(
      WidgetTester tester, {
      LocateResult result = const Located(51.5072, -0.1276),
      bool hasCompass = true,
      String locale = 'en',
    }) async {
      final sensors = FakeQiblaSensors(result: result, hasCompass: hasCompass);
      await RealApp.launch(
        tester,
        route: '/qibla',
        locale: locale,
        qiblaSensors: sensors,
        // The city list as the app reads it, without its isolate.
        overrides: [cityIndexProvider.overrideWith((ref) async => cities)],
      );
      await RealApp.settle(tester);
      return sensors;
    }

    String text(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;

    testWidgets('automatic: from London, 119° and 4,794 km; facing it, '
        'said so; turned away, how far and which way', (tester) async {
      final sensors = await open(tester);
      expect(sensors.locateCalls, 1);
      expect(text(tester, 'qibla-bearing'), contains('119°'));
      expect(text(tester, 'qibla-bearing'), contains('4,794 km'));
      expect(find.text('Your location'), findsOneWidget);

      sensors.setHeading(119.5);
      await tester.pumpAndSettle();
      expect(find.text("You're facing the qibla"), findsOneWidget);

      sensors.setHeading(90);
      await tester.pumpAndSettle();
      expect(find.text('Turn right 29°'), findsOneWidget);
      sensors.setHeading(150);
      await tester.pumpAndSettle();
      expect(find.text('Turn left 31°'), findsOneWidget);
      await RealApp.quit(tester);
    });

    testWidgets('location refused: said so, and a city instead — kept for '
        'next time', (tester) async {
      await open(tester, result: const LocationDenied());
      expect(find.byKey(const ValueKey('qibla-status-denied')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qibla-choose-city')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qibla-manual')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('qibla-city-search')),
        'القاهرة',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qibla-city-Cairo-EG')));
      await tester.pumpAndSettle();
      expect(find.text('🇪🇬 Cairo'), findsOneWidget);
      expect(text(tester, 'qibla-bearing'), contains('136°'));
      await RealApp.quit(tester);

      // Opened again: the city, no location asked for.
      final sensors = await open(tester);
      expect(sensors.locateCalls, 0);
      expect(find.text('🇪🇬 Cairo'), findsOneWidget);

      // Back to automatic: the location asked for again, and kept so.
      await tester.tap(find.byKey(const ValueKey('qibla-place')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qibla-automatic')));
      await RealApp.settle(tester);
      expect(sensors.locateCalls, 1);
      expect(find.text('Your location'), findsOneWidget);
      await RealApp.quit(tester);
    });

    testWidgets('blocked for good: the phone settings, or a city', (
      tester,
    ) async {
      final sensors = await open(
        tester,
        result: const LocationDenied(forever: true),
      );
      expect(
        find.byKey(const ValueKey('qibla-status-deniedForever')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('qibla-action')));
      await tester.pumpAndSettle();
      expect(sensors.settingsOpened, 1);
      expect(find.byKey(const ValueKey('qibla-choose-city')), findsOneWidget);
      await RealApp.quit(tester);
    });

    // A language intl has no number data for: its digits in English
    // (the matrix found the screen failing in Hausa, Kurdish and Somali).
    for (final locale in ['ha', 'ckb', 'so']) {
      testWidgets('$locale: the distance shown, not an error', (tester) async {
        await open(tester, locale: locale);
        expect(text(tester, 'qibla-bearing'), contains('4,794'));
        await RealApp.quit(tester);
      });
    }

    testWidgets('no compass (a browser, a tablet): the dial still, north up, '
        'and how to use it', (tester) async {
      await open(tester, hasCompass: false);
      expect(
        find.text(
          'This device has no compass: turn until N on the dial points north.',
        ),
        findsOneWidget,
      );
      expect(text(tester, 'qibla-bearing'), contains('119°'));
      await RealApp.quit(tester);
    });
  });
}
