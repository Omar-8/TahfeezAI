import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/localization/clock_format.dart';
import 'package:tahfeez_ai/features/home_widgets/data/home_widget_bridge.dart';
import 'package:tahfeez_ai/features/home_widgets/domain/home_widget_payload.dart';
import 'package:tahfeez_ai/features/prayer/application/saved_place.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_place.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/real_app.dart';

class _FakeBridge implements HomeWidgetBridge {
  final published = <HomeWidgetPayload>[];
  final redraws = <(List<DateTime>, List<DateTime>)>[];
  final tapped = StreamController<Uri?>.broadcast();
  Uri? launched;

  @override
  bool get supported => true;
  @override
  Future<void> publish(HomeWidgetPayload payload) async =>
      published.add(payload);
  @override
  Future<void> scheduleRedraws(
    List<DateTime> prayerTimes,
    List<DateTime> midnights,
  ) async => redraws.add((prayerTimes, midnights));
  @override
  Future<Uri?> launchedWith() async => launched;
  @override
  Stream<Uri?> get taps => tapped.stream;
}

/// Home-screen widgets (owner, 2026-11-22): what the app writes for them,
/// in its language, kept up to date; a tapped one opens its screen.
void main() {
  test('a widget link opens only one of the app\'s own routes', () {
    Uri u(String s) => Uri.parse(s);
    expect(homeWidgetRoute(u('tahfeezwidget://open?route=/prayer')), '/prayer');
    expect(
      homeWidgetRoute(
        u('tahfeezwidget://open?homeWidget&route=%2Fquran%2Fayah%2F2%2F255'),
      ),
      '/quran/ayah/2/255',
    );
    expect(
      homeWidgetRoute(u('tahfeezwidget://open?route=//evil.example')),
      isNull,
    );
    expect(homeWidgetRoute(u('tahfeezwidget://open?route=https://x')), isNull);
    expect(homeWidgetRoute(u('tahfeezwidget://open')), isNull);
    expect(homeWidgetRoute(null), isNull);
    expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  group('in the app', () {
    setUpAll(RealApp.prepare);
    tearDownAll(RealApp.close);
    final now = DateTime(2026, 11, 22, 10);

    testWidgets('written at start and as things change: labels, routes, '
        '30 days of prayer times and dates; prayer redraws scheduled', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      final c = await RealApp.launch(
        tester,
        homeWidgets: bridge,
        overrides: [memorizationClockProvider.overrideWithValue(() => now)],
      );
      await tester.pump(const Duration(seconds: 3));
      await RealApp.settle(tester);
      expect(bridge.published, isNotEmpty, reason: 'written at start');
      var p = bridge.published.last.toJson();
      expect((p['labels']! as Map)['qibla'], 'Qibla');
      expect((p['routes']! as Map)['prayer'], '/prayer');
      expect((p['routes']! as Map)['date'], '/calendar');
      // Duas (owner, 2026-11-23): its own widget and the buttons' group.
      expect((p['labels']! as Map)['duas'], 'Duas');
      expect((p['routes']! as Map)['duas'], '/duas');
      expect(p['prayer'], isNull, reason: 'no place yet');
      expect((p['dates']! as List), hasLength(30));
      final firstDay = (p['dates']! as List).first as Map;
      expect(firstDay['date'], '2026-11-22');
      // As Home's date card: the Hijri day, the date in full.
      expect(firstDay['hijriDay'], 12); // 12 Jumada II 1448
      expect(firstDay['hijri'], contains('1448'));
      expect((p['routes']! as Map)['home'], '/home');

      // A place: its times, 30 days, six a day.
      await c
          .read(savedPlaceProvider.notifier)
          .set(
            const QiblaPlace(
              latitude: 30.0444,
              longitude: 31.2357,
              name: 'Cairo',
              country: 'EG',
            ),
          );
      await tester.pump(const Duration(seconds: 3));
      await RealApp.settle(tester);
      p = jsonDecode(bridge.published.last.encode()) as Map<String, Object?>;
      final prayer = p['prayer']! as Map;
      expect(prayer['place'], 'Cairo, Egypt');
      expect(prayer['order'], [
        'fajr',
        'sunrise',
        'dhuhr',
        'asr',
        'maghrib',
        'isha',
      ]);
      final days = prayer['days']! as List;
      expect(days, hasLength(30));
      expect(((days.first as Map)['at']! as List), hasLength(6));
      // Without AM/PM (owner, 2026-11-22).
      final fajr = ((days.first as Map)['shown']! as List).first as String;
      expect(fajr, isNot(contains('AM')));
      expect(fajr, matches(RegExp(r'^\d{1,2}:\d{2}$')));
      expect(bridge.redraws.last.$1, isNotEmpty, reason: 'at prayer times');
      // 24-hour chosen: the widgets told, the times so.
      await c.read(clockFormatProvider.notifier).set(ClockFormat.h24);
      await tester.pump(const Duration(seconds: 3));
      await RealApp.settle(tester);
      p = jsonDecode(bridge.published.last.encode()) as Map<String, Object?>;
      expect(p['clock'], '24');
      // ʿAsr, always afternoon: 24-hour, no AM/PM.
      final asr =
          ((((p['prayer']! as Map)['days']! as List).first as Map)['shown']!
                  as List)[3]
              as String;
      expect(asr, matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(int.parse(asr.split(':').first), greaterThanOrEqualTo(12));
      expect(
        bridge.redraws.last.$2.where((t) => t.hour == 0),
        hasLength(7),
        reason: 'each midnight',
      );
      expect(
        bridge.redraws.last.$2.map((t) => t.hour).toSet(),
        containsAll([0, 17, 19]),
        reason: "and as the date card's sun or moon changes",
      );
      await RealApp.quit(tester);
    });

    testWidgets('the app started by a widget\'s link ("/?route=/duas", as '
        'Android hands it to the router): Home, no "page not found"', (
      tester,
    ) async {
      await RealApp.launch(tester, route: '/?route=%2Fduas');
      expect(find.textContaining('Page Not Found'), findsNothing);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.byKey(const ValueKey('home-shortcuts')), findsOneWidget);
      await RealApp.quit(tester);
    });

    testWidgets('a widget tapped: its screen (over Home)', (tester) async {
      final bridge = _FakeBridge();
      await RealApp.launch(tester, homeWidgets: bridge);
      bridge.tapped.add(Uri.parse('tahfeezwidget://open?route=/qibla'));
      await tester.pump();
      await RealApp.settle(tester);
      expect(find.byKey(const ValueKey('qibla-place')), findsOneWidget);
      await RealApp.quit(tester);
    });
  });
}
