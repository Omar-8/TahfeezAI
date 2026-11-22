import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/athkar/application/athkar_audio.dart';
import 'package:tahfeez_ai/features/prayer/application/prayer_controller.dart';
import 'package:tahfeez_ai/features/prayer/application/saved_place.dart';
import 'package:tahfeez_ai/features/prayer/data/prayer_sounds.dart';
import 'package:tahfeez_ai/features/prayer/domain/prayer_times.dart';
import 'package:tahfeez_ai/features/qibla/data/city_index.dart';
import 'package:tahfeez_ai/features/qibla/data/qibla_sensors.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_place.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/app_menu.dart';
import '../../test_helpers/fake_qibla_sensors.dart';
import '../../test_helpers/fake_reminder_scheduler.dart';
import '../../test_helpers/real_app.dart';

/// Prayer times (owner, 2026-11-21): a glass card on Home with the five
/// prayers and sunrise, the next one marked; its own screen from there and
/// the side menu — the place found or chosen as the Qibla finder's, the
/// method, ʿAsr, minutes earlier or later, and each prayer's reminder.
class _FakeSounds implements PrayerSounds {
  DeviceSound? next = const DeviceSound('content://media/internal/7', 'Dawn');
  var picks = 0;
  @override
  bool get canPickFromPhone => true;
  @override
  bool get canVibrateOnly => true;
  @override
  Future<ReminderSound> prepare(PrayerSound sound) async =>
      ReminderSound.standard;
  @override
  Future<DeviceSound?> pickFromPhone(DeviceSound? current) async {
    picks++;
    return next;
  }
}

class _FakePlayer implements AthkarPlayer {
  final played = <Uri>[];
  Completer<void>? _playing;
  @override
  Future<void> play(Uri uri) async {
    played.add(uri);
    await (_playing = Completer<void>()).future;
  }

  @override
  Future<void> stop() async {
    if (!(_playing?.isCompleted ?? true)) _playing!.complete();
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  setUpAll(RealApp.prepare);
  tearDownAll(RealApp.close);

  final cities = CityIndex.fromJson(
    jsonDecode(utf8.decode(gzip.decode(File(kCitiesAsset).readAsBytesSync())))
        as Map<String, Object?>,
  );
  // Cairo (as found, rounded), 21 November 2026, a minute after Dhuhr
  // (in this machine's time zone): ʿAsr next.
  final now = prayerTimes(
    const QiblaPlace(latitude: 30.04, longitude: 31.24, country: 'EG'),
    DateTime(2026, 11, 21),
    const PrayerSettings(),
  )[Prayer.dhuhr]!.add(const Duration(minutes: 1));

  late FakeReminderScheduler scheduler;
  late _FakeSounds sounds;
  late _FakePlayer player;
  setUp(() {
    scheduler = FakeReminderScheduler();
    sounds = _FakeSounds();
    player = _FakePlayer();
  });

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String route = '/home',
    LocateResult result = const Located(30.0444, 31.2357), // Cairo
  }) async {
    final c = await RealApp.launch(
      tester,
      route: route,
      qiblaSensors: FakeQiblaSensors(result: result),
      overrides: [
        memorizationClockProvider.overrideWithValue(() => now),
        cityIndexProvider.overrideWith((ref) async => cities),
        dailyReminderSchedulerProvider.overrideWithValue(scheduler),
        prayerSoundsProvider.overrideWithValue(sounds),
        athkarPlayerFactoryProvider.overrideWithValue(() => player),
      ],
    );
    await RealApp.settle(tester);
    return c;
  }

  /// Nothing kept for the next test (kept on the phone between tests).
  Future<void> clear(WidgetTester tester, ProviderContainer c) async {
    final storage = c.read(browserStorageProvider);
    await storage.remove(SavedPlaceController.storageKey);
    await storage.remove(PrayerSettingsController.storageKey);
    await storage.remove('qibla.mode');
    await storage.remove('qibla.city');
    await RealApp.quit(tester);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  /// The prayer screen scrolled to [k] (built only when near).
  Future<void> reveal(WidgetTester tester, String k) async {
    await tester.scrollUntilVisible(
      key(k),
      150,
      scrollable: find
          .descendant(of: key('prayer-list'), matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, Finder f) => tester
      .widgetList<Text>(find.descendant(of: f, matching: find.byType(Text)))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' ');

  testWidgets('Home: no place yet — set it; its screen finds the phone, '
      'then Home shows six times, the next one marked', (tester) async {
    final c = await launch(tester);
    expect(key('home-prayer-set'), findsOneWidget);
    await tester.ensureVisible(key('home-prayer'));
    await tester.tap(key('home-prayer'));
    await RealApp.settle(tester);

    // Found: rounded, named after the nearest city.
    final place = c.read(savedPlaceProvider)!;
    expect((place.latitude, place.longitude), (30.04, 31.24));
    expect(place.country, 'EG');
    expect(text(tester, key('prayer-place')), contains(', Egypt'));
    expect(text(tester, key('prayer-place')), isNot(contains('🇪🇬')));
    await reveal(tester, 'prayer-method');
    expect(
      text(tester, key('prayer-method')),
      contains('By your country: Egyptian General Authority of Survey'),
    );
    for (final p in Prayer.values) {
      expect(key('prayer-time-${p.name}'), findsOneWidget);
    }
    expect(key('prayer-notify-sunrise'), findsNothing);
    expect(
      tester.widget<Text>(key('prayer-next')).data,
      startsWith('ʿAsr in '),
    );

    await tester.pageBack();
    await RealApp.settle(tester);
    expect(key('home-prayer-set'), findsNothing);
    for (final p in [
      Prayer.fajr,
      Prayer.sunrise,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ]) {
      expect(key('home-prayer-${p.name}'), findsOneWidget);
    }
    // Sunrise on Home, not Ḍuḥā (owner, 2026-11-21).
    expect(key('home-prayer-duha'), findsNothing);
    // "City, Country", no flag or icon (owner, 2026-11-21).
    final shown = tester.widget<Text>(key('home-prayer-place')).data!;
    expect(shown, endsWith(', Egypt'));
    expect(shown, isNot(contains('🇪🇬')));
    expect(
      find.descendant(
        of: key('home-prayer'),
        matching: find.byIcon(Icons.mosque_outlined),
      ),
      findsNothing,
    );
    // Under the date card, above the shortcuts.
    expect(
      tester.getTopLeft(key('home-prayer')).dy,
      greaterThan(tester.getBottomLeft(key('home-date')).dy),
    );
    final asr = tester.widget<Container>(key('home-prayer-asr'));
    final dhuhr = tester.widget<Container>(key('home-prayer-dhuhr'));
    final scheme = Theme.of(tester.element(key('home-prayer'))).colorScheme;
    expect((asr.decoration! as BoxDecoration).color, scheme.primaryContainer);
    expect(
      (dhuhr.decoration! as BoxDecoration).color,
      isNot(scheme.primaryContainer),
    );
    expect(
      tester.widget<Text>(key('home-prayer-next')).data,
      startsWith('ʿAsr in '),
    );
    await clear(tester, c);
  });

  testWidgets('the side menu; the method, Ḥanafī ʿAsr, a minute later, a '
      "prayer's reminder — kept", (tester) async {
    final c = await launch(tester);
    await openFromMenu(tester, 'prayer');
    await RealApp.settle(tester);
    expect(key('prayer-day'), findsOneWidget);

    await tester.ensureVisible(key('prayer-notify-fajr'));
    await tester.tap(key('prayer-notify-fajr'));
    await RealApp.settle(tester);
    expect(c.read(prayerSettingsProvider).notify, {Prayer.fajr});
    expect(scheduler.once, isNotEmpty);

    await tester.ensureVisible(key('prayer-method'));
    await tester.tap(key('prayer-method'));
    await tester.pumpAndSettle();
    // Grouped by region: Europe's and Asia's among them.
    expect(key('prayer-region-world'), findsOneWidget);
    expect(find.text('Europe', skipOffstage: false), findsOneWidget);
    await tester.tap(key('prayer-method-muslimWorldLeague'));
    await tester.pumpAndSettle();
    await reveal(tester, 'prayer-method');
    expect(
      c.read(prayerSettingsProvider).method,
      PrayerMethod.muslimWorldLeague,
    );
    expect(text(tester, key('prayer-method')), contains('Muslim World League'));
    // Back to the country's.
    await tester.tap(key('prayer-method'));
    await tester.pumpAndSettle();
    await tester.tap(key('prayer-method-auto'));
    await tester.pumpAndSettle();
    expect(c.read(prayerSettingsProvider).method, isNull);

    await tester.ensureVisible(key('prayer-asr'));
    await tester.tap(find.text('Ḥanafī'));
    await tester.pumpAndSettle();
    expect(c.read(prayerSettingsProvider).asr, AsrMethod.hanafi);

    await tester.ensureVisible(key('prayer-adjust'));
    await tester.tap(key('prayer-adjust'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('prayer-adjust-maghrib-plus'));
    // (Clear of the bottom bar.)
    await tester.drag(key('prayer-list'), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(key('prayer-adjust-maghrib-plus'));
    await tester.pumpAndSettle();
    expect(c.read(prayerSettingsProvider).adjust[Prayer.maghrib], 1);

    await RealApp.quit(tester);

    // Opened again: as left; Settings' notifications show it.
    final again = await launch(tester, route: '/settings');
    expect(again.read(prayerSettingsProvider).asr, AsrMethod.hanafi);
    expect(again.read(prayerSettingsProvider).adjust[Prayer.maghrib], 1);
    await tester.tap(key('settings-group-Notifications'));
    await RealApp.settle(tester);
    await tester.ensureVisible(key('settings-prayer'));
    await tester.drag(key('settings-prayer'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(text(tester, key('settings-prayer')), contains('Fajr'));
    await tester.tap(key('settings-prayer'));
    await RealApp.settle(tester);
    expect(key('prayer-day'), findsOneWidget);
    await clear(tester, again);
  });

  testWidgets('the adhan: heard, chosen; one of the phone\'s sounds; exact '
      'alarms not allowed — said so, and where to allow them', (tester) async {
    scheduler.exact = false;
    final c = await launch(tester, route: '/prayer');
    expect(key('prayer-exact'), findsNothing, reason: 'no reminder yet');
    await tester.ensureVisible(key('prayer-notify-isha'));
    await tester.tap(key('prayer-notify-isha'));
    await RealApp.settle(tester);
    // The bell: off → the adhan → vibrate only → off.
    expect(
      c.read(prayerSettingsProvider).alertOf(Prayer.isha),
      PrayerAlert.sound,
    );
    await tester.tap(key('prayer-notify-isha'));
    await RealApp.settle(tester);
    expect(
      c.read(prayerSettingsProvider).alertOf(Prayer.isha),
      PrayerAlert.vibrate,
    );
    expect(
      find.descendant(
        of: key('prayer-notify-isha'),
        matching: find.byIcon(Icons.vibration_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(key('prayer-notify-isha'));
    await RealApp.settle(tester);
    expect(
      c.read(prayerSettingsProvider).alertOf(Prayer.isha),
      PrayerAlert.off,
    );
    await tester.tap(key('prayer-notify-isha'));
    await RealApp.settle(tester);
    await tester.ensureVisible(key('prayer-exact'));
    await tester.tap(key('prayer-exact-allow'));
    await tester.pump();
    expect(scheduler.exactRequested, 1);

    await tester.ensureVisible(key('prayer-sound'));
    expect(text(tester, key('prayer-sound')), contains('Madinah'));
    await tester.tap(key('prayer-sound'));
    await tester.pumpAndSettle();
    await tester.tap(key('prayer-sound-listen-synagda'));
    await tester.pump();
    expect(
      player.played.single.toString(),
      'asset:///assets/adhan/synagda.mp3',
    );
    expect(
      find.byIcon(Icons.stop_circle_outlined),
      findsOneWidget,
      reason: 'playing: its stop button',
    );
    await tester.tap(key('prayer-sound-synagda'));
    await tester.pumpAndSettle();
    expect(c.read(prayerSettingsProvider).sound, const AdhanSound('synagda'));
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);

    // (Below the adhans.)
    await tester.dragUntilVisible(
      key('prayer-sound-phone'),
      key('prayer-sound-madinah'),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(key('prayer-sound-phone'));
    await tester.pumpAndSettle();
    expect(sounds.picks, 1);
    expect(c.read(prayerSettingsProvider).sound, sounds.next);
    expect(find.text('Dawn'), findsWidgets);
    await clear(tester, c);
  });

  testWidgets('location refused: said so, and a city instead', (tester) async {
    final c = await launch(
      tester,
      route: '/prayer',
      result: const LocationDenied(),
    );
    expect(key('prayer-status-denied'), findsOneWidget);
    await tester.tap(key('prayer-choose-city'));
    await tester.pumpAndSettle();
    await tester.tap(key('qibla-manual'));
    await tester.pumpAndSettle();
    await tester.enterText(key('qibla-city-search'), 'makkah');
    await tester.pumpAndSettle();
    await tester.tap(key('qibla-city-Makkah-SA'));
    await RealApp.settle(tester);
    await reveal(tester, 'prayer-method');
    expect(c.read(savedPlaceProvider)?.name, 'Makkah');
    expect(text(tester, key('prayer-method')), contains('Umm al-Qura'));
    expect(key('prayer-day'), findsOneWidget);
    await clear(tester, c);
  });
}
