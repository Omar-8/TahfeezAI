import 'dart:async';

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../../../quran/application/meaning_defaults.dart' show usesArabicScript;
import '../../qibla/data/country_names.dart';
import '../data/prayer_sounds.dart';
import '../domain/prayer_times.dart';
import 'saved_place.dart';

/// Prayer times' settings (owner, 2026-11-21), kept on the phone.
class PrayerSettingsController extends Notifier<PrayerSettings> {
  static const storageKey = 'prayer.settings';

  @override
  PrayerSettings build() {
    unawaited(_restore());
    return const PrayerSettings();
  }

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    if (raw != null && ref.mounted) state = PrayerSettings.decode(raw);
  }

  Future<void> set(PrayerSettings settings) async {
    state = settings;
    await ref
        .read(browserStorageProvider)
        .setString(storageKey, settings.encode());
  }

  /// [prayer]'s reminder on (asking for permission first) or off. `false`
  /// when refused.
  Future<bool> setNotify(Prayer prayer, bool on) =>
      setAlert(prayer, on ? PrayerAlert.sound : PrayerAlert.off);

  /// [prayer]'s reminder as [alert] (permission asked for first when it
  /// turns on). `false` when refused.
  Future<bool> setAlert(Prayer prayer, PrayerAlert alert) async {
    if (alert != PrayerAlert.off &&
        !state.notify.contains(prayer) &&
        !await ref.read(dailyReminderSchedulerProvider).requestPermission()) {
      return false;
    }
    await set(
      state.copyWith(
        notify: alert == PrayerAlert.off
            ? ({...state.notify}..remove(prayer))
            : {...state.notify, prayer},
        vibrate: alert == PrayerAlert.vibrate
            ? {...state.vibrate, prayer}
            : ({...state.vibrate}..remove(prayer)),
      ),
    );
    return true;
  }
}

final prayerSettingsProvider =
    NotifierProvider<PrayerSettingsController, PrayerSettings>(
      PrayerSettingsController.new,
    );

/// A prayer's name.
String prayerName(AppLocalizations l10n, Prayer p) => switch (p) {
  Prayer.fajr => l10n.prayerFajr,
  Prayer.sunrise => l10n.prayerSunrise,
  Prayer.duha => l10n.prayerDuha,
  Prayer.dhuhr => l10n.prayerDhuhr,
  Prayer.asr => l10n.prayerAsr,
  Prayer.maghrib => l10n.prayerMaghrib,
  Prayer.isha => l10n.prayerIsha,
};

/// The prayers' reminders, at each one's time — times shift day by day,
/// so the next [ahead] days are scheduled one by one, again whenever the
/// place or the settings change and at every start (an iPhone keeps 64
/// pending in all). A tap opens prayer times.
class PrayerRemindersController extends Notifier<void> {
  static const ahead = 5;
  static const firstId = 3000;
  static const payload = 'prayer';

  @override
  void build() {
    ref.listen(prayerSettingsProvider, (_, _) => _queue());
    ref.listen(savedPlaceProvider, (_, _) => _queue(), fireImmediately: true);
  }

  Future<void>? _running;

  void _queue() {
    _running = (_running ?? Future<void>.value()).then((_) => _reschedule());
  }

  static final _ids = [
    for (var d = 0; d < ahead; d++)
      for (var p = 0; p < Prayer.values.length; p++)
        firstId + d * Prayer.values.length + p,
  ];

  Future<void> _reschedule() async {
    if (!ref.mounted) return;
    final scheduler = ref.read(dailyReminderSchedulerProvider);
    if (!scheduler.supported) return;
    scheduler.onOpen(payload, _open);
    await scheduler.initialize();
    await scheduler.cancelIds(_ids);
    final place = ref.read(savedPlaceProvider);
    final settings = ref.read(prayerSettingsProvider);
    if (place == null || settings.notify.isEmpty) return;
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    final now = ref.read(memorizationClockProvider)();
    // The sound (an Android channel's is fixed: a channel for each).
    final sound = await ref.read(prayerSoundsProvider).prepare(settings.sound);
    if (!ref.mounted) return;
    final channelId = prayerChannelId(settings.sound);
    final countries = ref.read(countryNamesProvider).value;
    final channelName =
        '${l10n.prayerReminderChannel} · '
        '${prayerSoundName(l10n, settings.sound, countries: countries)}';
    for (var d = 0; d < ahead; d++) {
      final times = prayerTimes(
        place,
        DateTime(now.year, now.month, now.day + d),
        settings,
      );
      for (final p in Prayer.values) {
        if (!settings.notify.contains(p)) continue;
        final at = times[p]!;
        if (!at.isAfter(now)) continue;
        final name = prayerName(l10n, p);
        // (The bell's third state: a vibration, a channel of its own.)
        final quiet = settings.vibrate.contains(p);
        await scheduler.scheduleOnce(
          id: firstId + d * Prayer.values.length + p.index,
          at: at,
          title: name,
          body: l10n.prayerNotifyBody(name),
          channelId: quiet ? 'prayer_vibrate' : channelId,
          channelName: quiet
              ? '${l10n.prayerReminderChannel} · ${l10n.prayerSoundVibrate}'
              : channelName,
          payload: payload,
          sound: quiet ? ReminderSound.vibrateOnly : sound,
          exact: true,
        );
      }
    }
  }

  void _open() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      final router = ref.read(appRouterProvider)..go('/home');
      unawaited(router.push('/prayer'));
    });
  }
}

/// The Android notification channel for [sound]'s reminders.
String prayerChannelId(PrayerSound sound) => switch (sound) {
  AdhanSound(:final id) => 'prayer_adhan_$id',
  StandardSound() => 'prayer_standard',
  // (Without vibration: a new channel — the old one vibrated.)
  SilentSound() => 'prayer_silent_still',
  // (A channel per sound chosen: its sound can't change.)
  DeviceSound(:final uri) =>
    'prayer_device_${uri.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x3fffffff)}',
};

/// A sound's name, as the list and the phone's notification settings
/// show it ([countries]: an adhan named after its country).
String prayerSoundName(
  AppLocalizations l10n,
  PrayerSound sound, {
  CountryNames? countries,
}) => switch (sound) {
  AdhanSound(:final id) => adhanName(l10n, id, countries: countries),
  StandardSound() => l10n.prayerSoundStandard,
  SilentSound() => l10n.prayerSoundSilent,
  DeviceSound(:final title) => title.isEmpty ? l10n.prayerSoundPhone : title,
};

/// An adhan's name: who calls it (and where), or where it was recorded
/// (Madinah; else its country); the others numbered.
String adhanName(AppLocalizations l10n, String id, {CountryNames? countries}) {
  if (id == 'madinah') return l10n.prayerAdhanMadinah;
  final language = l10n.localeName.split('_').first;
  if (adhanMuezzins[id] case (final en, final ar)) {
    return usesArabicScript(language) ? ar : en;
  }
  final country = countries?.of(adhanCountries[id], language);
  if (country != null) return country;
  final numbered = [
    for (final a in adhanSounds)
      if (a != 'madinah' &&
          !adhanMuezzins.containsKey(a) &&
          !adhanCountries.containsKey(a))
        a,
  ];
  final n = numbered.indexOf(id);
  return l10n.prayerAdhanNumbered(
    n >= 0 ? n + 1 : numbered.length + adhanSounds.indexOf(id),
  );
}

final prayerRemindersProvider =
    NotifierProvider<PrayerRemindersController, void>(
      PrayerRemindersController.new,
    );
