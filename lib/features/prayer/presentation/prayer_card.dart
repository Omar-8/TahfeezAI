import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../application/prayer_controller.dart';
import '../../qibla/data/country_names.dart';
import '../../qibla/domain/qibla_place.dart';
import '../application/saved_place.dart';
import '../domain/prayer_times.dart';

/// The times shown on Home (owner, 2026-11-21: the five and sunrise).
const homePrayers = [
  Prayer.fajr,
  Prayer.sunrise,
  Prayer.dhuhr,
  Prayer.asr,
  Prayer.maghrib,
  Prayer.isha,
];

/// "1 h 5 min" / "40 min" until [at].
String untilText(AppLocalizations l10n, DateTime now, DateTime at) {
  final minutes = (at.difference(now).inSeconds / 60).ceil();
  return minutes >= 60
      ? l10n.activityHoursMinutes(minutes ~/ 60, minutes % 60)
      : l10n.activityMinutes(minutes);
}

/// Home's prayer times (owner, 2026-11-21): glass, as the cards and buttons
/// around it — the place, the next prayer and how long until it, the day's
/// six times (the next one marked). A tap opens prayer times; no place yet,
/// it asks for one there.
class PrayerTimesCard extends ConsumerStatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  ConsumerState<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends ConsumerState<PrayerTimesCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _everyMinute();
  }

  void _everyMinute() {
    final now = DateTime.now();
    _tick = Timer(
      Duration(seconds: 60 - now.second, milliseconds: -now.millisecond),
      () {
        if (!mounted) return;
        setState(() {});
        _everyMinute();
      },
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final intl = intlLocaleOf(locale);
    final place = ref.watch(savedPlaceProvider);
    final settings = ref.watch(prayerSettingsProvider);
    final countries = ref.watch(countryNamesProvider).value;
    final now = ref.watch(memorizationClockProvider)();
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final clock = use24 ? DateFormat.Hm(intl) : DateFormat.jm(intl);
    return TahfeezGlassSurface(
      key: const ValueKey('home-prayer'),
      blur: false,
      onTap: () => context.push(AppRoutes.prayer),
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: place == null
            ? Row(
                spacing: TahfeezSpacing.sm,
                children: [
                  Expanded(
                    child: Text(
                      l10n.prayerSetLocation,
                      key: const ValueKey('home-prayer-set'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              )
            : Builder(
                builder: (context) {
                  final times = prayerTimes(place, now, settings);
                  final next = nextPrayer(
                    place,
                    now,
                    settings,
                    among: homePrayers,
                  );
                  Widget cell(Prayer p) {
                    final isNext = p == next.prayer;
                    return Expanded(
                      child: Container(
                        key: ValueKey('home-prayer-${p.name}'),
                        padding: const EdgeInsets.symmetric(
                          vertical: TahfeezSpacing.sm,
                          horizontal: TahfeezSpacing.xs,
                        ),
                        // Each time on a tile of its own, clear on the
                        // light glass too (owner, 2026-11-21): paper, an
                        // edge, a soft shadow; the next one green.
                        decoration: BoxDecoration(
                          color: isNext
                              ? scheme.primaryContainer
                              : dark
                              ? scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.35,
                                )
                              : scheme.surfaceContainerLowest.withValues(
                                  alpha: 0.92,
                                ),
                          borderRadius: BorderRadius.circular(TahfeezRadii.md),
                          border: dark
                              ? null
                              : Border.all(
                                  color: isNext
                                      ? scheme.primary.withValues(alpha: 0.35)
                                      : scheme.outlineVariant.withValues(
                                          alpha: 0.8,
                                        ),
                                ),
                          boxShadow: dark
                              ? null
                              : [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(
                                      alpha: 0.07,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        // (Shrunk to its tile: large text, narrow phones.)
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            spacing: 2,
                            children: [
                              Text(
                                prayerName(l10n, p),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: isNext
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                clock.format(times[p]!),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: isNext
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: TahfeezSpacing.smPlus,
                    children: [
                      Wrap(
                        spacing: TahfeezSpacing.sm,
                        runSpacing: 2,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            placeLabel(place, countries, locale.languageCode) ??
                                l10n.prayerTitle,
                            key: const ValueKey('home-prayer-place'),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            l10n.prayerNextIn(
                              prayerName(l10n, next.prayer),
                              untilText(l10n, now, next.at),
                            ),
                            key: const ValueKey('home-prayer-next'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      // Two rows of three: room for each name and time.
                      for (final row in [
                        homePrayers.sublist(0, 3),
                        homePrayers.sublist(3),
                      ])
                        Row(
                          spacing: TahfeezSpacing.sm,
                          children: [for (final p in row) cell(p)],
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// "Cairo, Egypt": a place's city and country (in [language]); the city
/// alone where the country is unknown; `null` for an unnamed position.
String? placeLabel(QiblaPlace place, CountryNames? countries, String language) {
  final city = place.name;
  if (city == null) return null;
  final country = countries?.of(place.country, language);
  return country == null ? city : '$city, $country';
}

/// A method's name.
String prayerMethodName(AppLocalizations l10n, PrayerMethod m) => switch (m) {
  PrayerMethod.muslimWorldLeague => l10n.prayerMethodMwl,
  PrayerMethod.egyptian => l10n.prayerMethodEgyptian,
  PrayerMethod.karachi => l10n.prayerMethodKarachi,
  PrayerMethod.ummAlQura => l10n.prayerMethodUmmAlQura,
  PrayerMethod.dubai => l10n.prayerMethodDubai,
  PrayerMethod.moonsighting => l10n.prayerMethodMoonsighting,
  PrayerMethod.northAmerica => l10n.prayerMethodNorthAmerica,
  PrayerMethod.kuwait => l10n.prayerMethodKuwait,
  PrayerMethod.qatar => l10n.prayerMethodQatar,
  PrayerMethod.singapore => l10n.prayerMethodSingapore,
  PrayerMethod.turkey => l10n.prayerMethodTurkey,
  PrayerMethod.tehran => l10n.prayerMethodTehran,
  PrayerMethod.gulf => l10n.prayerMethodGulf,
  PrayerMethod.jordan => l10n.prayerMethodJordan,
  PrayerMethod.tunisia => l10n.prayerMethodTunisia,
  PrayerMethod.algeria => l10n.prayerMethodAlgeria,
  PrayerMethod.morocco => l10n.prayerMethodMorocco,
  PrayerMethod.franceUoif => l10n.prayerMethodFranceUoif,
  PrayerMethod.france15 => l10n.prayerMethodFrance15,
  PrayerMethod.france18 => l10n.prayerMethodFrance18,
  PrayerMethod.russia => l10n.prayerMethodRussia,
  PrayerMethod.portugal => l10n.prayerMethodPortugal,
  PrayerMethod.jakim => l10n.prayerMethodJakim,
  PrayerMethod.kemenag => l10n.prayerMethodKemenag,
};

/// A region's heading in the method's list.
String prayerRegionName(AppLocalizations l10n, PrayerRegion r) => switch (r) {
  PrayerRegion.world => l10n.prayerRegionWorld,
  PrayerRegion.middleEast => l10n.prayerRegionMiddleEast,
  PrayerRegion.europe => l10n.prayerRegionEurope,
  PrayerRegion.asia => l10n.prayerRegionAsia,
  PrayerRegion.americas => l10n.prayerRegionAmericas,
};
