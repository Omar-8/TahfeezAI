import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/bar_space.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../../habits/application/habits_controller.dart';
import '../../habits/domain/hijri.dart';
import '../../habits/presentation/habit_parts.dart';
import '../../qibla/application/qibla_controller.dart';
import '../../qibla/data/country_names.dart';
import '../../qibla/data/qibla_sensors.dart';
import '../../qibla/domain/qibla_place.dart';
import '../../qibla/presentation/qibla_screen.dart' show showQiblaPlaceSheet;
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper;
import '../application/prayer_controller.dart';
import '../application/prayer_sound_preview.dart';
import '../application/saved_place.dart';
import '../data/prayer_sounds.dart';
import '../domain/prayer_times.dart';
import 'prayer_card.dart';

/// Prayer times (owner, 2026-11-21: from the side menu and Home): where
/// they are for — the phone's location or a city, as the Qibla finder's —
/// the day's times (another day's too), each prayer's reminder, and how
/// they are worked out: the method (by the country unless chosen), ʿAsr,
/// high latitudes, minutes earlier or later.
class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  /// Days from today shown.
  var _offset = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final intl = intlLocaleOf(locale);
    // (Its place found — or chosen — as the Qibla finder's; kept.)
    final qibla = ref.watch(qiblaControllerProvider);
    // (The place just found shown at once, while it is kept.)
    final place =
        ref.watch(savedPlaceProvider) ??
        (qibla.status == QiblaStatus.ready ? qibla.place : null);
    final settings = ref.watch(prayerSettingsProvider);
    final now = ref.watch(memorizationClockProvider)();
    final day = DateTime(now.year, now.month, now.day + _offset);
    final adjust = ref.watch(habitsProvider.select((s) => s.hijriAdjust));
    final clock = MediaQuery.alwaysUse24HourFormatOf(context)
        ? DateFormat.Hm(intl)
        : DateFormat.jm(intl);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final placeCard = TahfeezGlassSurface(
      key: const ValueKey('prayer-place'),
      blur: false,
      onTap: () => showQiblaPlaceSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Row(
          spacing: TahfeezSpacing.smPlus,
          children: [
            Icon(Icons.location_city_rounded, color: scheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.qiblaPlaceTitle, style: muted),
                  Text(
                    place == null
                        ? l10n.qiblaLocating
                        : placeLabel(
                                place,
                                ref.watch(countryNamesProvider).value,
                                locale.languageCode,
                              ) ??
                              l10n.qiblaYourLocation,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    qibla.mode == QiblaMode.manual
                        ? l10n.qiblaManual
                        : l10n.qiblaAutomatic,
                    style: muted,
                  ),
                ],
              ),
            ),
            Text(
              l10n.qiblaChangePlace,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );

    // No place yet, and none to be had: why, and what to do.
    final Widget? problem = place != null
        ? null
        : switch (qibla.status) {
            QiblaStatus.locating || QiblaStatus.ready => const Center(
              child: Padding(
                padding: EdgeInsets.all(TahfeezSpacing.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            final status => TahfeezCard(
              key: ValueKey('prayer-status-${status.name}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TahfeezSpacing.sm,
                children: [
                  Text(switch (status) {
                    QiblaStatus.denied => l10n.qiblaDenied,
                    QiblaStatus.deniedForever => l10n.qiblaDeniedForever,
                    QiblaStatus.locationOff => l10n.qiblaLocationOff,
                    QiblaStatus.needsCity => l10n.prayerSetLocation,
                    _ => l10n.qiblaFailed,
                  }),
                  Wrap(
                    spacing: TahfeezSpacing.sm,
                    children: [
                      if (status == QiblaStatus.locationOff)
                        FilledButton(
                          onPressed: () => unawaited(
                            ref
                                .read(qiblaSensorsProvider)
                                .openLocationSettings(),
                          ),
                          child: Text(l10n.qiblaTurnOnLocation),
                        ),
                      FilledButton.tonal(
                        key: const ValueKey('prayer-choose-city'),
                        onPressed: () => showQiblaPlaceSheet(context),
                        child: Text(l10n.qiblaChooseCity),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          };

    return HabitsScaffold(
      title: l10n.prayerTitle,
      body: ListView(
        key: const ValueKey('prayer-list'),
        padding: withBarSpace(context, const EdgeInsets.all(TahfeezSpacing.md)),
        children: [
          placeCard,
          const SizedBox(height: TahfeezSpacing.md),
          if (problem != null)
            problem
          else
            _DayTimes(
              times: prayerTimes(place!, day, settings),
              next: _offset == 0 ? nextPrayer(place, now, settings) : null,
              now: now,
              title: DateFormat.yMMMMEEEEd(intl).format(day),
              hijri: formatHijri(
                hijriOf(day, adjust: adjust),
                locale.languageCode,
              ),
              clock: clock,
              alertOf: settings.alertOf,
              vibrates: ref.watch(prayerSoundsProvider).canVibrateOnly,
              onDay: (by) => setState(() => _offset += by),
              onToday: _offset == 0 ? null : () => setState(() => _offset = 0),
              onNotify: (p, alert) async {
                final messenger = ScaffoldMessenger.of(context);
                final done = await ref
                    .read(prayerSettingsProvider.notifier)
                    .setAlert(p, alert);
                if (!done) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.memReminderDenied)),
                  );
                }
              },
            ),
          const SizedBox(height: TahfeezSpacing.sm),
          _SoundRow(sound: settings.sound),
          if (settings.notify.isNotEmpty) const _ExactAlarmTip(),
          const SizedBox(height: TahfeezSpacing.md),
          Text(l10n.prayerSettings, style: theme.textTheme.titleMedium),
          const SizedBox(height: TahfeezSpacing.sm),
          _Calculation(settings: settings, place: place),
          const SizedBox(height: TahfeezSpacing.sm),
          Text('${l10n.prayerDuhaNote} ${l10n.prayerClockNote}', style: muted),
        ],
      ),
    );
  }
}

/// A day's times: its date (Gregorian and Hijri, with the days before and
/// after), each time with its reminder's bell, the next prayer marked.
class _DayTimes extends StatelessWidget {
  const _DayTimes({
    required this.times,
    required this.next,
    required this.now,
    required this.title,
    required this.hijri,
    required this.clock,
    required this.alertOf,
    required this.vibrates,
    required this.onDay,
    required this.onToday,
    required this.onNotify,
  });

  final Map<Prayer, DateTime> times;
  final ({Prayer prayer, DateTime at})? next;
  final DateTime now;
  final String title, hijri;
  final DateFormat clock;
  final PrayerAlert Function(Prayer) alertOf;

  /// Whether the phone can vibrate without a sound (else the bell's third
  /// state is silent).
  final bool vibrates;
  final ValueChanged<int> onDay;
  final VoidCallback? onToday;
  final void Function(Prayer, PrayerAlert) onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TahfeezCard(
      key: const ValueKey('prayer-day'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('prayer-previous-day'),
                tooltip: l10n.commonPrevious,
                icon: Icon(
                  rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                ),
                onPressed: () => onDay(-1),
              ),
              Expanded(
                child: InkWell(
                  onTap: onToday,
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        hijri,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('prayer-next-day'),
                tooltip: l10n.commonNext,
                icon: Icon(
                  rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                ),
                onPressed: () => onDay(1),
              ),
            ],
          ),
          if (next case final n?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TahfeezSpacing.xs),
              child: Text(
                l10n.prayerNextIn(
                  prayerName(l10n, n.prayer),
                  untilText(l10n, now, n.at),
                ),
                key: const ValueKey('prayer-next'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (final p in Prayer.values)
            Container(
              key: ValueKey('prayer-time-${p.name}'),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: next?.prayer == p ? scheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(TahfeezRadii.md),
              ),
              child: ListTile(
                dense: p == Prayer.sunrise,
                leading: Icon(
                  switch (p) {
                    Prayer.fajr => Icons.wb_twilight_rounded,
                    Prayer.sunrise => Icons.wb_sunny_outlined,
                    Prayer.duha => Icons.light_mode_outlined,
                    Prayer.dhuhr => Icons.wb_sunny_rounded,
                    Prayer.asr => Icons.sunny_snowing,
                    Prayer.maghrib => Icons.wb_twilight_rounded,
                    Prayer.isha => Icons.nightlight_round,
                  },
                  color: p == Prayer.sunrise
                      ? scheme.onSurfaceVariant
                      : scheme.primary,
                ),
                title: Text(
                  prayerName(l10n, p),
                  style: p == Prayer.sunrise
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )
                      : theme.textTheme.titleSmall,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      clock.format(times[p]!),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    // The bell (owner, 2026-11-22): off → the adhan → a
                    // vibration only (silent on an iPhone) → off.
                    if (p.remindable)
                      IconButton(
                        key: ValueKey('prayer-notify-${p.name}'),
                        tooltip: switch (alertOf(p)) {
                          PrayerAlert.off => l10n.prayerNotifyTip,
                          PrayerAlert.sound => l10n.prayerSound,
                          PrayerAlert.vibrate =>
                            vibrates
                                ? l10n.prayerSoundVibrate
                                : l10n.prayerSoundSilent,
                        },
                        icon: Icon(
                          switch (alertOf(p)) {
                            PrayerAlert.off => Icons.notifications_none_rounded,
                            PrayerAlert.sound =>
                              Icons.notifications_active_rounded,
                            PrayerAlert.vibrate =>
                              vibrates
                                  ? Icons.vibration_rounded
                                  : Icons.notifications_paused_outlined,
                          },
                          color: alertOf(p) == PrayerAlert.off
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                        onPressed: () => onNotify(p, alertOf(p).next),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How the times are worked out: the method, ʿAsr, high latitudes, and
/// minutes earlier or later, prayer by prayer.
class _Calculation extends ConsumerWidget {
  const _Calculation({required this.settings, required this.place});

  final PrayerSettings settings;
  final QiblaPlace? place;

  /// "By your country" chosen in the method's sheet.
  static const _byCountry = 'byCountry';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(prayerSettingsProvider.notifier);
    final byCountry = PrayerMethod.forCountry(place?.country);
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            key: const ValueKey('prayer-method'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calculate_outlined),
            title: Text(l10n.prayerMethod),
            subtitle: Text(
              settings.method == null
                  ? l10n.prayerMethodAuto(prayerMethodName(l10n, byCountry))
                  : prayerMethodName(l10n, settings.method!),
            ),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: () async {
              // (The app's sheet: below the status bar and the camera,
              // as wide as its others.)
              final picked = await showTahfeezModalBottomSheet<Object>(
                context: context,
                title: l10n.prayerMethod,
                builder: (context) => SafeArea(
                  top: false,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        key: const ValueKey('prayer-method-auto'),
                        leading: Icon(
                          settings.method == null
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(
                          l10n.prayerMethodAuto(
                            prayerMethodName(l10n, byCountry),
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(_byCountry),
                      ),
                      for (final r in PrayerRegion.values) ...[
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            TahfeezSpacing.md,
                            TahfeezSpacing.md,
                            TahfeezSpacing.md,
                            TahfeezSpacing.xs,
                          ),
                          child: Text(
                            prayerRegionName(l10n, r),
                            key: ValueKey('prayer-region-${r.name}'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        for (final m in PrayerMethod.values)
                          if (m.region == r)
                            ListTile(
                              key: ValueKey('prayer-method-${m.name}'),
                              leading: Icon(
                                settings.method == m
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                              ),
                              title: Text(prayerMethodName(l10n, m)),
                              onTap: () => Navigator.of(context).pop(m),
                            ),
                      ],
                    ],
                  ),
                ),
              );
              // (Closed by a swipe: as it was.)
              if (picked == null || !context.mounted) return;
              unawaited(
                controller.set(
                  settings.copyWith(
                    method: () => picked is PrayerMethod ? picked : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: TahfeezSpacing.sm),
          Text(l10n.prayerAsrMethod, style: theme.textTheme.titleSmall),
          const SizedBox(height: TahfeezSpacing.xs),
          SegmentedButton<AsrMethod>(
            key: const ValueKey('prayer-asr'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: AsrMethod.standard,
                label: Text(l10n.prayerAsrStandard),
              ),
              ButtonSegment(
                value: AsrMethod.hanafi,
                label: Text(l10n.prayerAsrHanafi),
              ),
            ],
            selected: {settings.asr},
            onSelectionChanged: (s) =>
                unawaited(controller.set(settings.copyWith(asr: s.first))),
          ),
          const SizedBox(height: TahfeezSpacing.md),
          Text(l10n.prayerHighLatitude, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 4,
            children: [
              for (final (h, label) in [
                (HighLatitude.middleOfTheNight, l10n.prayerHighMiddle),
                (HighLatitude.seventhOfTheNight, l10n.prayerHighSeventh),
                (HighLatitude.twilightAngle, l10n.prayerHighAngle),
              ])
                ChoiceChip(
                  key: ValueKey('prayer-high-${h.name}'),
                  label: Text(label),
                  selected: settings.highLatitude == h,
                  onSelected: (_) => unawaited(
                    controller.set(settings.copyWith(highLatitude: h)),
                  ),
                ),
            ],
          ),
          ExpansionTile(
            key: const ValueKey('prayer-adjust'),
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.prayerAdjust),
            subtitle: Text(l10n.prayerAdjustSub),
            children: [
              for (final p in Prayer.values)
                Row(
                  children: [
                    Expanded(child: Text(prayerName(l10n, p))),
                    Text(
                      l10n.prayerAdjustMinutes(settings.adjust[p] ?? 0),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: TahfeezSpacing.sm),
                    CountStepper(
                      id: 'prayer-adjust-${p.name}',
                      value: settings.adjust[p] ?? 0,
                      min: -60,
                      max: 60,
                      onChanged: (v) => unawaited(
                        controller.set(
                          settings.copyWith(adjust: {...settings.adjust, p: v}),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The reminders' sound (owner, 2026-11-21): an adhan (heard first), the
/// phone's notification sound, none, or (Android) one of the phone's.
class _SoundRow extends ConsumerWidget {
  const _SoundRow({required this.sound});

  final PrayerSound sound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TahfeezCard(
      child: ListTile(
        key: const ValueKey('prayer-sound'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.campaign_outlined),
        title: Text(l10n.prayerSound),
        subtitle: Text(
          prayerSoundName(
            l10n,
            sound,
            countries: ref.watch(countryNamesProvider).value,
          ),
        ),
        trailing: const Icon(Icons.expand_more_rounded),
        onTap: () => showTahfeezModalBottomSheet<void>(
          context: context,
          title: l10n.prayerSound,
          builder: (context) => const _SoundSheet(),
        ),
      ),
    );
  }
}

class _SoundSheet extends ConsumerWidget {
  const _SoundSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(prayerSettingsProvider);
    final playing = ref.watch(prayerSoundPreviewProvider);
    final sounds = ref.watch(prayerSoundsProvider);
    final countries = ref.watch(countryNamesProvider).value;
    final controller = ref.read(prayerSettingsProvider.notifier);
    void choose(PrayerSound s) {
      unawaited(ref.read(prayerSoundPreviewProvider.notifier).stop());
      unawaited(controller.set(settings.copyWith(sound: s)));
    }

    Widget radio(bool on) => Icon(
      on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: on ? theme.colorScheme.primary : null,
    );
    final device = settings.sound is DeviceSound
        ? settings.sound as DeviceSound
        : null;
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final id in adhanSounds)
            ListTile(
              key: ValueKey('prayer-sound-$id'),
              leading: radio(settings.sound == AdhanSound(id)),
              title: Text(adhanName(l10n, id, countries: countries)),
              trailing: IconButton(
                key: ValueKey('prayer-sound-listen-$id'),
                tooltip: playing == id
                    ? l10n.prayerSoundStop
                    : l10n.prayerSoundListen,
                icon: Icon(
                  playing == id
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                ),
                onPressed: () => unawaited(
                  ref.read(prayerSoundPreviewProvider.notifier).toggle(id),
                ),
              ),
              onTap: () => choose(AdhanSound(id)),
            ),
          const Divider(),
          if (sounds.canPickFromPhone)
            ListTile(
              key: const ValueKey('prayer-sound-phone'),
              leading: radio(device != null),
              title: Text(l10n.prayerSoundPhone),
              subtitle: device == null || device.title.isEmpty
                  ? null
                  : Text(device.title),
              trailing: const Icon(Icons.phone_android_outlined),
              onTap: () async {
                unawaited(ref.read(prayerSoundPreviewProvider.notifier).stop());
                final picked = await sounds.pickFromPhone(device);
                if (picked != null) choose(picked);
              },
            ),
          ListTile(
            key: const ValueKey('prayer-sound-standard'),
            leading: radio(settings.sound is StandardSound),
            title: Text(l10n.prayerSoundStandard),
            onTap: () => choose(const StandardSound()),
          ),
          ListTile(
            key: const ValueKey('prayer-sound-silent'),
            leading: radio(settings.sound is SilentSound),
            title: Text(l10n.prayerSoundSilent),
            onTap: () => choose(const SilentSound()),
          ),
          Padding(
            padding: const EdgeInsets.all(TahfeezSpacing.md),
            child: Text(
              l10n.prayerSoundNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android without "Alarms & reminders" allowed: the adhan may come a few
/// minutes late — said so, and where to allow it. Checked again whenever
/// the app comes back (from that setting).
class _ExactAlarmTip extends ConsumerStatefulWidget {
  const _ExactAlarmTip();

  @override
  ConsumerState<_ExactAlarmTip> createState() => _ExactAlarmTipState();
}

class _ExactAlarmTipState extends ConsumerState<_ExactAlarmTip>
    with WidgetsBindingObserver {
  var _allowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    final scheduler = ref.read(dailyReminderSchedulerProvider);
    final allowed = !scheduler.supported || await scheduler.exactAllowed();
    if (!mounted || allowed == _allowed) return;
    setState(() => _allowed = allowed);
    // Allowed now: the reminders again, at the minute.
    if (allowed) ref.invalidate(prayerRemindersProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
      child: TahfeezCard(
        key: const ValueKey('prayer-exact'),
        child: Row(
          spacing: TahfeezSpacing.sm,
          children: [
            const Icon(Icons.alarm_rounded),
            Expanded(child: Text(l10n.prayerExactSub)),
            TextButton(
              key: const ValueKey('prayer-exact-allow'),
              onPressed: () => unawaited(
                ref.read(dailyReminderSchedulerProvider).requestExact(),
              ),
              child: Text(l10n.prayerExactAllow),
            ),
          ],
        ),
      ),
    );
  }
}
