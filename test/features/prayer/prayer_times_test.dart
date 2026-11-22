import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/core/storage/browser_storage.dart';
import 'package:tahfeez_ai/core/storage/storage_providers.dart';
import 'package:tahfeez_ai/features/prayer/application/prayer_controller.dart';
import 'package:tahfeez_ai/features/prayer/application/saved_place.dart';
import 'package:tahfeez_ai/features/prayer/domain/prayer_times.dart';
import 'package:tahfeez_ai/features/qibla/data/city_index.dart';
import 'package:tahfeez_ai/features/qibla/domain/qibla_place.dart';
import 'package:tahfeez_ai/memorization/application/memorization_today.dart';

import '../../test_helpers/fake_reminder_scheduler.dart';

class _MemoryStorage implements BrowserStorage {
  @override
  Future<void> clearExcept(Set<String> keep) async {}
  @override
  Future<Map<String, Object?>> readAll() async => const {};
  @override
  Future<void> writeAll(Map<String, Object?> values) async {}

  final values = <String, Object>{};
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
}

const makkah = QiblaPlace(
  latitude: 21.4225,
  longitude: 39.8262,
  name: 'Makkah',
  country: 'SA',
);
const cairo = QiblaPlace(
  latitude: 30.0444,
  longitude: 31.2357,
  name: 'Cairo',
  country: 'EG',
);
const london = QiblaPlace(
  latitude: 51.5072,
  longitude: -0.1276,
  name: 'London',
  country: 'GB',
);

/// Prayer times (owner, 2026-11-21): worked out on the phone (adhan), the
/// method by the place's country unless chosen, ʿAsr, minutes earlier or
/// later; the place kept; the reminders.
void main() {
  String utc(DateTime t) => t.toUtc().toIso8601String().substring(11, 16);

  group('the times', () {
    // Published timetables for 21 November 2026 (UTC; Makkah UTC+3,
    // Cairo UTC+2), each by its country's method.
    for (final (place, want) in [
      (
        makkah,
        {
          Prayer.fajr: '02:15',
          Prayer.sunrise: '03:35',
          Prayer.dhuhr: '09:07',
          Prayer.asr: '12:15',
          Prayer.maghrib: '14:38',
          Prayer.isha: '16:08',
        },
      ),
      (
        cairo,
        {
          Prayer.fajr: '02:54',
          Prayer.sunrise: '04:25',
          Prayer.dhuhr: '09:42',
          Prayer.asr: '12:36',
          Prayer.maghrib: '14:57',
          Prayer.isha: '16:18',
        },
      ),
    ]) {
      test('${place.name}: in order, Ḍuḥā 20 minutes after sunrise', () {
        final t = prayerTimes(
          place,
          DateTime(2026, 11, 21),
          const PrayerSettings(),
        );
        for (final e in want.entries) {
          expect(utc(t[e.key]!), e.value, reason: e.key.name);
        }
        expect(t[Prayer.duha], t[Prayer.sunrise]!.add(duhaAfterSunrise));
        final order = [for (final p in Prayer.values) t[p]!];
        for (var i = 1; i < order.length; i++) {
          expect(order[i].isAfter(order[i - 1]), isTrue);
        }
      });
    }

    test("the method: the country's, else the Muslim World League; chosen "
        'one kept', () {
      expect(PrayerMethod.forCountry('SA'), PrayerMethod.ummAlQura);
      expect(PrayerMethod.forCountry('EG'), PrayerMethod.egyptian);
      expect(PrayerMethod.forCountry('PK'), PrayerMethod.karachi);
      expect(PrayerMethod.forCountry('US'), PrayerMethod.northAmerica);
      expect(PrayerMethod.forCountry('TR'), PrayerMethod.turkey);
      expect(PrayerMethod.forCountry('FR'), PrayerMethod.franceUoif);
      expect(PrayerMethod.forCountry('MY'), PrayerMethod.jakim);
      expect(PrayerMethod.forCountry('ID'), PrayerMethod.kemenag);
      expect(PrayerMethod.forCountry('JO'), PrayerMethod.jordan);
      expect(PrayerMethod.forCountry('MA'), PrayerMethod.morocco);
      expect(PrayerMethod.forCountry('DE'), PrayerMethod.muslimWorldLeague);
      expect(PrayerMethod.forCountry(null), PrayerMethod.muslimWorldLeague);
      const chosen = PrayerSettings(method: PrayerMethod.egyptian);
      expect(chosen.methodAt(makkah), PrayerMethod.egyptian);
      expect(const PrayerSettings().methodAt(makkah), PrayerMethod.ummAlQura);
    });

    test("the authorities' own angles: a lower angle, a later Fajr; ʿIshāʾ "
        'a fixed time after Maghrib; every method gives the day in order', () {
      final day = DateTime(2026, 11, 21);
      Map<Prayer, DateTime> by(PrayerMethod m) =>
          prayerTimes(london, day, PrayerSettings(method: m));
      final uoif = by(PrayerMethod.franceUoif);
      final f18 = by(PrayerMethod.france18);
      expect(uoif[Prayer.fajr]!.isAfter(f18[Prayer.fajr]!), isTrue);
      expect(uoif[Prayer.isha]!.isBefore(f18[Prayer.isha]!), isTrue);
      final lisbon = by(PrayerMethod.portugal);
      expect(
        lisbon[Prayer.isha]!.difference(lisbon[Prayer.maghrib]!),
        const Duration(minutes: 77),
      );
      for (final m in PrayerMethod.values) {
        final t = by(m);
        final order = [for (final p in Prayer.values) t[p]!];
        for (var i = 1; i < order.length; i++) {
          expect(order[i].isAfter(order[i - 1]), isTrue, reason: m.name);
        }
      }
    });

    test('Ḥanafī ʿAsr later; minutes earlier or later; kept and read back', () {
      final day = DateTime(2026, 11, 21);
      final base = prayerTimes(cairo, day, const PrayerSettings());
      final hanafi = prayerTimes(
        cairo,
        day,
        const PrayerSettings(asr: AsrMethod.hanafi),
      );
      expect(hanafi[Prayer.asr]!.isAfter(base[Prayer.asr]!), isTrue);
      expect(hanafi[Prayer.dhuhr], base[Prayer.dhuhr]);

      const s = PrayerSettings(
        method: PrayerMethod.karachi,
        asr: AsrMethod.hanafi,
        highLatitude: HighLatitude.seventhOfTheNight,
        adjust: {Prayer.maghrib: 3, Prayer.fajr: -2},
        notify: {Prayer.fajr, Prayer.isha},
      );
      final moved = prayerTimes(
        cairo,
        day,
        const PrayerSettings(adjust: {Prayer.maghrib: 3, Prayer.fajr: -2}),
      );
      expect(
        moved[Prayer.maghrib]!.difference(base[Prayer.maghrib]!),
        const Duration(minutes: 3),
      );
      expect(
        moved[Prayer.fajr]!.difference(base[Prayer.fajr]!),
        const Duration(minutes: -2),
      );
      expect(PrayerSettings.decode(s.encode()), s);
      expect(PrayerSettings.decode('nonsense'), const PrayerSettings());
      expect(PrayerSettings.decode(null), const PrayerSettings());
    });

    test('the next prayer: Ḍuḥā counted, sunrise not; after ʿIshāʾ, '
        "tomorrow's Fajr", () {
      const s = PrayerSettings();
      final t = prayerTimes(london, DateTime(2026, 11, 21), s);
      final atSunrise = t[Prayer.sunrise]!;
      expect(nextPrayer(london, atSunrise, s).prayer, Prayer.duha);
      final afterFajr = t[Prayer.fajr]!.add(const Duration(minutes: 1));
      expect(nextPrayer(london, afterFajr, s).prayer, Prayer.duha);
      // Home's: sunrise counted, Ḍuḥā not.
      const home = [
        Prayer.fajr,
        Prayer.sunrise,
        Prayer.dhuhr,
        Prayer.asr,
        Prayer.maghrib,
        Prayer.isha,
      ];
      expect(
        nextPrayer(london, afterFajr, s, among: home).prayer,
        Prayer.sunrise,
      );
      expect(
        nextPrayer(london, atSunrise, s, among: home).prayer,
        Prayer.dhuhr,
      );
      final late = t[Prayer.isha]!.add(const Duration(minutes: 1));
      final next = nextPrayer(london, late, s);
      expect(next.prayer, Prayer.fajr);
      expect(
        next.at,
        prayerTimes(london, DateTime(2026, 11, 22), s)[Prayer.fajr],
      );
    });
  });

  group('kept on the phone', () {
    late _MemoryStorage storage;
    late FakeReminderScheduler scheduler;
    late DateTime now;
    final cities = CityIndex.fromJson({
      'cities': [
        ['London', 'GB', 51.5072, -0.1276, ''],
        ['Cairo', 'EG', 30.0626, 31.2497, ''],
      ],
    });

    ProviderContainer launch() {
      final c = ProviderContainer(
        overrides: [
          browserStorageProvider.overrideWithValue(storage),
          memorizationClockProvider.overrideWithValue(() => now),
          dailyReminderSchedulerProvider.overrideWithValue(scheduler),
          cityIndexProvider.overrideWith((ref) async => cities),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      storage = _MemoryStorage();
      scheduler = FakeReminderScheduler();
      now = DateTime(2026, 11, 21, 10);
    });

    test("the phone's position: rounded to about a kilometre, named after "
        'the nearest city, there next time', () async {
      final c = launch();
      await c
          .read(savedPlaceProvider.notifier)
          .set(const QiblaPlace(latitude: 30.04123, longitude: 31.23789));
      final p = c.read(savedPlaceProvider)!;
      expect((p.latitude, p.longitude), (30.04, 31.24));
      expect((p.name, p.country), ('Cairo', 'EG'));
      expect(
        storage.values[SavedPlaceController.storageKey],
        isNot(contains('30.041')),
      );

      final again = launch();
      again.read(savedPlaceProvider);
      await pumpEventQueue();
      expect(again.read(savedPlaceProvider), p);
    });

    test('reminders: each chosen prayer, five days ahead, the ones still '
        'to come; none without a place; gone when turned off', () async {
      final c = launch();
      c.read(prayerRemindersProvider);
      await pumpEventQueue();
      expect(
        await c
            .read(prayerSettingsProvider.notifier)
            .setNotify(Prayer.fajr, true),
        isTrue,
      );
      await c
          .read(prayerSettingsProvider.notifier)
          .setNotify(Prayer.maghrib, true);
      await pumpEventQueue();
      expect(scheduler.once, isEmpty, reason: 'no place yet');

      await c.read(savedPlaceProvider.notifier).set(cairo);
      await pumpEventQueue();
      // 10:00 local: today's Fajr is past, today's Maghrib to come.
      final times = [
        for (var d = 0; d < 5; d++)
          prayerTimes(
            cairo,
            DateTime(2026, 11, 21 + d),
            c.read(prayerSettingsProvider),
          ),
      ];
      final want = {
        for (var d = 0; d < 5; d++)
          for (final p in [Prayer.fajr, Prayer.maghrib])
            if (times[d][p]!.isAfter(now)) times[d][p]!,
      };
      expect(scheduler.once.values.map((e) => e.at).toSet(), want);
      expect(
        scheduler.once.keys.every((id) => id >= 3000 && id < 3035),
        isTrue,
      );
      final maghrib = scheduler.once.values.firstWhere(
        (e) => e.at == times[0][Prayer.maghrib],
      );
      expect(maghrib.title, 'Maghrib');
      expect(maghrib.body, 'It is time for Maghrib.');
      expect(scheduler.handlers, contains('prayer'));

      await c
          .read(prayerSettingsProvider.notifier)
          .setNotify(Prayer.fajr, false);
      await c
          .read(prayerSettingsProvider.notifier)
          .setNotify(Prayer.maghrib, false);
      await pumpEventQueue();
      expect(scheduler.once, isEmpty);
    });

    test("the sound: an adhan by default — its own channel, at the minute; "
        'silent, the phone\'s or one of the phone\'s; kept', () async {
      final c = launch();
      c.read(prayerRemindersProvider);
      await c.read(savedPlaceProvider.notifier).set(cairo);
      await c
          .read(prayerSettingsProvider.notifier)
          .setNotify(Prayer.maghrib, true);
      await pumpEventQueue();
      var sent = scheduler.onceSound.values.first;
      expect(sent.sound.bundled, 'adhan_madinah');
      expect(sent.channelId, 'prayer_adhan_madinah');
      expect(sent.exact, isTrue);

      final n = c.read(prayerSettingsProvider.notifier);
      await n.set(
        c.read(prayerSettingsProvider).copyWith(sound: const SilentSound()),
      );
      await pumpEventQueue();
      sent = scheduler.onceSound.values.first;
      expect(sent.sound.silent, isTrue);
      expect(sent.channelId, 'prayer_silent_still');
      expect(sent.sound.vibrate, isFalse, reason: 'silent: no vibration');

      // The bell's third state: that prayer only vibrates.
      await n.setAlert(Prayer.maghrib, PrayerAlert.vibrate);
      await pumpEventQueue();
      sent = scheduler.onceSound.values.first;
      expect((sent.sound.silent, sent.sound.vibrate), (true, true));
      expect(sent.channelId, 'prayer_vibrate');
      final bells = PrayerSettings.decode(
        c.read(prayerSettingsProvider).encode(),
      );
      expect(bells.alertOf(Prayer.maghrib), PrayerAlert.vibrate);
      expect(bells.alertOf(Prayer.fajr), PrayerAlert.off);
      await n.setAlert(Prayer.maghrib, PrayerAlert.sound);
      await pumpEventQueue();
      expect(scheduler.onceSound.values.first.channelId, 'prayer_silent_still');

      const phone = DeviceSound(
        'content://media/internal/audio/media/7',
        'Dawn',
      );
      await n.set(c.read(prayerSettingsProvider).copyWith(sound: phone));
      await pumpEventQueue();
      sent = scheduler.onceSound.values.first;
      expect(sent.sound.uri, phone.uri);
      expect(sent.channelId, startsWith('prayer_device_'));

      final kept = PrayerSettings.decode(
        c.read(prayerSettingsProvider).encode(),
      );
      expect(kept.sound, phone);
      expect((kept.sound as DeviceSound).title, 'Dawn');
      expect(PrayerSettings.decode('{}').sound, const AdhanSound('madinah'));
      expect(
        PrayerSettings.decode('{"sound":"synagda"}').sound,
        const AdhanSound('synagda'),
      );
    });

    test('notifications refused: not turned on', () async {
      scheduler = FakeReminderScheduler(granted: false);
      final c = launch();
      expect(
        await c
            .read(prayerSettingsProvider.notifier)
            .setNotify(Prayer.isha, true),
        isFalse,
      );
      expect(c.read(prayerSettingsProvider).notify, isEmpty);
    });
  });
}
