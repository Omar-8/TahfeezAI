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
import '../../habits/application/habits_controller.dart';
import '../../habits/domain/hijri.dart';

/// The Hijri year's days the card counts down to (from 2 days before).
enum HijriEvent {
  newYear(1, 1),
  ashura(1, 10),
  ramadan(9, 1),
  lastTen(9, 21),
  eidFitr(10, 1),
  dhulHijjahTen(12, 1),
  arafah(12, 9),
  eidAdha(12, 10);

  const HijriEvent(this.month, this.day);

  final int month, day;

  String title(AppLocalizations l10n) => switch (this) {
    newYear => l10n.eventNewYear,
    ashura => l10n.eventAshura,
    ramadan => l10n.eventRamadan,
    lastTen => l10n.eventLastTen,
    eidFitr => l10n.eventEidFitr,
    dhulHijjahTen => l10n.eventDhulHijjahTen,
    arafah => l10n.eventArafah,
    eidAdha => l10n.eventEidAdha,
  };
}

/// The next event within [ahead] days of [today] (0: today), if any.
({HijriEvent event, int inDays})? nextHijriEvent(
  DateTime today, {
  int adjust = 0,
  int ahead = 2,
}) {
  for (var i = 0; i <= ahead; i++) {
    final h = hijriOf(
      DateTime(today.year, today.month, today.day + i),
      adjust: adjust,
    );
    for (final e in HijriEvent.values) {
      if (e.month == h.month && e.day == h.day) return (event: e, inDays: i);
    }
  }
  return null;
}

/// The time of day: the card's sun or moon.
enum SkyTime {
  sunrise,
  day,
  sunset,
  night;

  static SkyTime of(DateTime t) {
    final h = t.hour + t.minute / 60;
    if (h >= 5 && h < 7) return sunrise;
    if (h >= 7 && h < 17) return day;
    if (h >= 17 && h < 19) return sunset;
    return night;
  }

  IconData get icon => switch (this) {
    sunrise || sunset => Icons.wb_twilight_rounded,
    day => Icons.wb_sunny_rounded,
    night => Icons.nightlight_round,
  };
}

/// Home's date (owner, 2026-11-21, the owner's choice of four): the Hijri
/// day on a glass tile, the Hijri date
/// in full, today's date, the time, and a Hijri event coming within two
/// days ("ʿArafah in 2 days"); the sun or the moon rising into place as
/// Home opens. A tap opens the Hijri calendar.
class HomeDateCard extends ConsumerStatefulWidget {
  const HomeDateCard({super.key});

  /// How long its sun or moon takes to rise as it appears.
  static const play = Duration(milliseconds: 1200);

  @override
  ConsumerState<HomeDateCard> createState() => _HomeDateCardState();
}

class _HomeDateCardState extends ConsumerState<HomeDateCard>
    with SingleTickerProviderStateMixin {
  late final _rise = AnimationController(
    vsync: this,
    duration: HomeDateCard.play,
  );
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _everyMinute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _rise.value = 1;
    } else if (_rise.value == 0 && !_rise.isAnimating) {
      _rise.forward();
    }
  }

  /// Again on the next minute (the time shown), and every minute on.
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
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode;
    final intl = intlLocaleOf(locale);
    final now = ref.watch(memorizationClockProvider)();
    final adjust = ref.watch(habitsProvider.select((s) => s.hijriAdjust));
    final hijri = hijriOf(now, adjust: adjust);
    final event = nextHijriEvent(now, adjust: adjust);
    final time = SkyTime.of(now);
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return TahfeezGlassSurface(
      key: const ValueKey('home-date'),
      blur: false,
      onTap: () => context.push(AppRoutes.hijriCalendar),
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.smPlus),
        child: Row(
          spacing: TahfeezSpacing.smPlus,
          children: [
            _TimeTile(now: now, intl: intl, use24: use24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  // Today's date first, the Hijri date under it (owner,
                  // 2026-11-22: as the widgets; the time on the square).
                  Text(
                    DateFormat.MMMMEEEEd(intl).format(now),
                    key: const ValueKey('home-date-today'),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    formatHijri(hijri, language),
                    key: const ValueKey('home-date-hijri'),
                    style: muted,
                  ),
                  if (event != null)
                    Container(
                      key: ValueKey('home-event-${event.event.name}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: TahfeezSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: scheme.onPrimaryContainer,
                          ),
                          Flexible(
                            child: Text(
                              switch (event.inDays) {
                                0 => l10n.homeEventToday(
                                  event.event.title(l10n),
                                ),
                                1 => l10n.homeEventTomorrow(
                                  event.event.title(l10n),
                                ),
                                final n => l10n.homeEventInDays(
                                  event.event.title(l10n),
                                  n,
                                ),
                              },
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Column(
              spacing: 2,
              children: [
                // The sun or the moon, rising into place.
                AnimatedBuilder(
                  animation: _rise,
                  builder: (context, child) {
                    final t = Curves.easeOutBack.transform(_rise.value);
                    return Transform.translate(
                      offset: Offset(0, 10 * (1 - t)),
                      child: Opacity(opacity: _rise.value, child: child),
                    );
                  },
                  child: Icon(
                    time.icon,
                    key: ValueKey('home-sky-${time.name}'),
                    color: const Color(0xFFE0A526),
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The time on a glass square, its digits in the app's green — as the
/// Qibla, Athkar and Habits buttons below it (owner, 2026-11-22: the time
/// here, not the day): hours and minutes, AM/PM under them on a 12-hour
/// phone.
class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.now, required this.intl, required this.use24});

  final DateTime now;
  final String intl;
  final bool use24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final digits = DateFormat(use24 ? 'HH:mm' : 'h:mm', intl).format(now);
    final period = use24 ? null : DateFormat('a', intl).format(now);
    return TahfeezGlassSurface(
      key: const ValueKey('home-date-time'),
      blur: false,
      borderRadius: BorderRadius.circular(TahfeezRadii.md),
      child: SizedBox(
        width: 60,
        height: 56,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                digits,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (period != null)
                Text(
                  period,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
