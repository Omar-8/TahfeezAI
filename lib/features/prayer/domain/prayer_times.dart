import 'dart:convert';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';

import '../../qibla/domain/qibla_place.dart';

/// The day's times shown (owner, 2026-11-21: the five prayers and Ḍuḥā;
/// sunrise too, where Fajr's time ends).
enum Prayer {
  fajr,
  sunrise,
  duha,
  dhuhr,
  asr,
  maghrib,
  isha;

  /// The five, and Ḍuḥā: those with a reminder of their own.
  bool get remindable => this != sunrise;
}

/// Where a method is used, for the method's list.
enum PrayerRegion { world, middleEast, europe, asia, americas }

/// The calculation methods: the `adhan` package's, and the angles other
/// authorities publish (owner, 2026-11-21: "more, European and Asian").
enum PrayerMethod {
  muslimWorldLeague(PrayerRegion.world),
  moonsighting(PrayerRegion.world),
  ummAlQura(PrayerRegion.middleEast),
  egyptian(PrayerRegion.middleEast),
  dubai(PrayerRegion.middleEast),
  gulf(PrayerRegion.middleEast),
  kuwait(PrayerRegion.middleEast),
  qatar(PrayerRegion.middleEast),
  jordan(PrayerRegion.middleEast),
  tehran(PrayerRegion.middleEast),
  tunisia(PrayerRegion.middleEast),
  algeria(PrayerRegion.middleEast),
  morocco(PrayerRegion.middleEast),
  turkey(PrayerRegion.europe),
  franceUoif(PrayerRegion.europe),
  france15(PrayerRegion.europe),
  france18(PrayerRegion.europe),
  russia(PrayerRegion.europe),
  portugal(PrayerRegion.europe),
  karachi(PrayerRegion.asia),
  singapore(PrayerRegion.asia),
  jakim(PrayerRegion.asia),
  kemenag(PrayerRegion.asia),
  northAmerica(PrayerRegion.americas);

  const PrayerMethod(this.region);

  final PrayerRegion region;

  /// Its parameters: the `adhan` package's own where it has the method,
  /// else the authority's published Fajr and ʿIshāʾ angles (or ʿIshāʾ a
  /// fixed time after Maghrib).
  adhan.CalculationParameters parameters() {
    adhan.CalculationParameters angles(
      double fajr, {
      double? isha,
      int ishaAfter = 0,
    }) => adhan.CalculationParameters(
      fajrAngle: fajr,
      ishaAngle: isha,
      ishaInterval: ishaAfter,
    );
    return switch (this) {
      muslimWorldLeague =>
        adhan.CalculationMethod.muslim_world_league.getParameters(),
      moonsighting =>
        adhan.CalculationMethod.moon_sighting_committee.getParameters(),
      ummAlQura => adhan.CalculationMethod.umm_al_qura.getParameters(),
      egyptian => adhan.CalculationMethod.egyptian.getParameters(),
      dubai => adhan.CalculationMethod.dubai.getParameters(),
      kuwait => adhan.CalculationMethod.kuwait.getParameters(),
      qatar => adhan.CalculationMethod.qatar.getParameters(),
      tehran => adhan.CalculationMethod.tehran.getParameters(),
      turkey => adhan.CalculationMethod.turkey.getParameters(),
      karachi => adhan.CalculationMethod.karachi.getParameters(),
      singapore => adhan.CalculationMethod.singapore.getParameters(),
      northAmerica => adhan.CalculationMethod.north_america.getParameters(),
      gulf => angles(19.5, ishaAfter: 90),
      jordan => angles(18, isha: 18),
      tunisia => angles(18, isha: 18),
      algeria => angles(18, isha: 17),
      morocco => angles(19, isha: 17),
      franceUoif => angles(12, isha: 12),
      france15 => angles(15, isha: 15),
      france18 => angles(18, isha: 18),
      russia => angles(16, isha: 15),
      portugal => angles(18, ishaAfter: 77),
      jakim => angles(20, isha: 18),
      kemenag => angles(20, isha: 18),
    };
  }

  /// The method used where [country] (ISO 3166) is (owner, 2026-11-21:
  /// "by the user's country"); the Muslim World League's elsewhere.
  static PrayerMethod forCountry(String? country) =>
      switch (country?.toUpperCase()) {
        'SA' || 'YE' => ummAlQura,
        'EG' || 'SD' || 'LY' || 'SY' || 'LB' || 'PS' || 'IQ' => egyptian,
        'JO' => jordan,
        'AE' || 'OM' || 'BH' => dubai,
        'KW' => kuwait,
        'QA' => qatar,
        'TN' => tunisia,
        'DZ' => algeria,
        'MA' => morocco,
        'US' || 'CA' => northAmerica,
        'PK' || 'IN' || 'BD' || 'AF' || 'NP' || 'LK' => karachi,
        'TR' => turkey,
        'FR' => franceUoif,
        'RU' => russia,
        'PT' => portugal,
        'MY' => jakim,
        'ID' => kemenag,
        'SG' || 'BN' => singapore,
        'IR' => tehran,
        'GB' || 'IE' => moonsighting,
        _ => muslimWorldLeague,
      };
}

/// The adhans the app brings (owner, 2026-11-21): freely licensed
/// recordings (`tool/adhan/build_adhan.py`) — whole on Android, their first
/// 30 s on an iPhone.
const adhanSounds = [
  'mulla',
  'surayhi',
  'harak',
  'aqsa',
  'madinah',
  'azeez',
  'andrewler',
  'synagda',
  'ayodele',
];

/// The muezzins named (owner, 2026-11-22): English, Arabic — and where.
const adhanMuezzins = {
  'mulla': ('Ali Mulla · Makkah', 'علي ملا · مكة'),
  'surayhi': ('Abdul Majeed Al-Surayhi · Quba', 'عبد المجيد السريحي · قباء'),
  'harak': ('Abdulnasser Harak · Egypt', 'عبد الناصر حركة · مصر'),
  'aqsa': ('Naji Qazzaz · Al-Aqsa', 'ناجي قزاز · الأقصى'),
  'azeez': ('Aaqib Azeez', 'عاقب عزيز'),
};

/// Where an adhan was recorded, for its name (the country's, in the
/// app's language); the others are numbered.
const adhanCountries = <String, String>{};

/// The prayers' sound: an adhan of [adhanSounds], the phone's usual
/// notification sound, none, or (Android) a sound chosen on the phone.
sealed class PrayerSound {
  const PrayerSound();

  static PrayerSound decode(Object? raw) => switch (raw) {
    'standard' => const StandardSound(),
    'silent' => const SilentSound(),
    {'uri': final String uri, 'title': final String title} => DeviceSound(
      uri,
      title,
    ),
    final String id when adhanSounds.contains(id) => AdhanSound(id),
    _ => const AdhanSound('madinah'),
  };

  Object encode();
}

class AdhanSound extends PrayerSound {
  const AdhanSound(this.id);
  final String id;
  @override
  Object encode() => id;
  @override
  bool operator ==(Object other) => other is AdhanSound && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class StandardSound extends PrayerSound {
  const StandardSound();
  @override
  Object encode() => 'standard';
  @override
  bool operator ==(Object other) => other is StandardSound;
  @override
  int get hashCode => 1;
}

class SilentSound extends PrayerSound {
  const SilentSound();
  @override
  Object encode() => 'silent';
  @override
  bool operator ==(Object other) => other is SilentSound;
  @override
  int get hashCode => 2;
}

/// A sound on the phone ([uri], its [title] as the picker named it).
class DeviceSound extends PrayerSound {
  const DeviceSound(this.uri, this.title);
  final String uri, title;
  @override
  Object encode() => {'uri': uri, 'title': title};
  @override
  bool operator ==(Object other) => other is DeviceSound && other.uri == uri;
  @override
  int get hashCode => uri.hashCode;
}

/// A prayer's reminder, as its bell cycles: off, the sound, a vibration.
enum PrayerAlert {
  off,
  sound,
  vibrate;

  /// The bell's next state.
  PrayerAlert get next => values[(index + 1) % values.length];
}

/// How ʿAsr is worked out.
enum AsrMethod { standard, hanafi }

/// Where the night is short (far from the equator).
enum HighLatitude {
  middleOfTheNight(adhan.HighLatitudeRule.middle_of_the_night),
  seventhOfTheNight(adhan.HighLatitudeRule.seventh_of_the_night),
  twilightAngle(adhan.HighLatitudeRule.twilight_angle);

  const HighLatitude(this.rule);

  final adhan.HighLatitudeRule rule;
}

/// The calculation's settings: its method (`null`: by the country), ʿAsr,
/// high latitudes, minutes added to each time, and the prayers notified.
@immutable
class PrayerSettings {
  const PrayerSettings({
    this.method,
    this.asr = AsrMethod.standard,
    this.highLatitude = HighLatitude.middleOfTheNight,
    this.adjust = const {},
    this.notify = const {},
    this.vibrate = const {},
    this.sound = const AdhanSound('madinah'),
  });

  factory PrayerSettings.decode(String? raw) {
    if (raw == null) return const PrayerSettings();
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return PrayerSettings(
        method: j['method'] == null
            ? null
            : PrayerMethod.values.byName(j['method']! as String),
        asr: AsrMethod.values.byName(j['asr'] as String? ?? 'standard'),
        highLatitude: HighLatitude.values.byName(
          j['highLatitude'] as String? ?? 'middleOfTheNight',
        ),
        adjust: {
          for (final e in (j['adjust'] as Map<String, Object?>? ?? {}).entries)
            Prayer.values.byName(e.key): e.value! as int,
        },
        notify: {
          for (final p in j['notify'] as List<Object?>? ?? const [])
            Prayer.values.byName(p! as String),
        },
        vibrate: {
          for (final p in j['vibrate'] as List<Object?>? ?? const [])
            Prayer.values.byName(p! as String),
        },
        sound: PrayerSound.decode(j['sound']),
      );
    } on Object {
      return const PrayerSettings();
    }
  }

  final PrayerMethod? method;
  final AsrMethod asr;
  final HighLatitude highLatitude;
  final Map<Prayer, int> adjust;
  final Set<Prayer> notify;

  /// The prayers (of [notify]) whose reminder only vibrates — the bell's
  /// third state (owner, 2026-11-22); silent on an iPhone, which can't
  /// vibrate without a sound.
  final Set<Prayer> vibrate;

  /// [prayer]'s reminder: off, with [sound], or vibrating only.
  PrayerAlert alertOf(Prayer prayer) => !notify.contains(prayer)
      ? PrayerAlert.off
      : vibrate.contains(prayer)
      ? PrayerAlert.vibrate
      : PrayerAlert.sound;

  /// The reminders' sound (an adhan by default: owner, 2026-11-21).
  final PrayerSound sound;

  /// The method used at [place].
  PrayerMethod methodAt(QiblaPlace? place) =>
      method ?? PrayerMethod.forCountry(place?.country);

  PrayerSettings copyWith({
    PrayerMethod? Function()? method,
    AsrMethod? asr,
    HighLatitude? highLatitude,
    Map<Prayer, int>? adjust,
    Set<Prayer>? notify,
    Set<Prayer>? vibrate,
    PrayerSound? sound,
  }) => PrayerSettings(
    method: method != null ? method() : this.method,
    asr: asr ?? this.asr,
    highLatitude: highLatitude ?? this.highLatitude,
    adjust: adjust ?? this.adjust,
    notify: notify ?? this.notify,
    vibrate: vibrate ?? this.vibrate,
    sound: sound ?? this.sound,
  );

  String encode() => jsonEncode({
    'method': method?.name,
    'asr': asr.name,
    'highLatitude': highLatitude.name,
    'adjust': {for (final e in adjust.entries) e.key.name: e.value},
    'notify': [for (final p in notify) p.name],
    'vibrate': [for (final p in vibrate) p.name],
    'sound': sound.encode(),
  });

  @override
  bool operator ==(Object other) =>
      other is PrayerSettings && other.encode() == encode();
  @override
  int get hashCode => encode().hashCode;
}

/// Ḍuḥā begins once the sun is a spear's length up: this long after
/// sunrise.
const duhaAfterSunrise = Duration(minutes: 20);

/// [date]'s times at [place] (in the phone's own time zone).
Map<Prayer, DateTime> prayerTimes(
  QiblaPlace place,
  DateTime date,
  PrayerSettings settings,
) {
  final params = settings.methodAt(place).parameters()
    ..madhab = settings.asr == AsrMethod.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi
    ..highLatitudeRule = settings.highLatitude.rule;
  final t = adhan.PrayerTimes(
    adhan.Coordinates(place.latitude, place.longitude),
    adhan.DateComponents(date.year, date.month, date.day),
    params,
  );
  DateTime at(Prayer p, DateTime base) =>
      base.add(Duration(minutes: settings.adjust[p] ?? 0));
  return {
    Prayer.fajr: at(Prayer.fajr, t.fajr),
    Prayer.sunrise: at(Prayer.sunrise, t.sunrise),
    Prayer.duha: at(Prayer.duha, t.sunrise.add(duhaAfterSunrise)),
    Prayer.dhuhr: at(Prayer.dhuhr, t.dhuhr),
    Prayer.asr: at(Prayer.asr, t.asr),
    Prayer.maghrib: at(Prayer.maghrib, t.maghrib),
    Prayer.isha: at(Prayer.isha, t.isha),
  };
}

/// The next of the day's times among [among] (by default the prayers,
/// Ḍuḥā included, not sunrise) after [now] — tomorrow's Fajr once ʿIshāʾ
/// is past.
({Prayer prayer, DateTime at}) nextPrayer(
  QiblaPlace place,
  DateTime now,
  PrayerSettings settings, {
  Iterable<Prayer>? among,
}) {
  final today = prayerTimes(place, now, settings);
  final shown = among?.toSet();
  for (final p in Prayer.values) {
    if (shown == null ? p == Prayer.sunrise : !shown.contains(p)) continue;
    if (today[p]!.isAfter(now)) return (prayer: p, at: today[p]!);
  }
  final tomorrow = prayerTimes(
    place,
    DateTime(now.year, now.month, now.day + 1),
    settings,
  );
  return (prayer: Prayer.fajr, at: tomorrow[Prayer.fajr]!);
}
