import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../home/presentation/home_sky.dart';
import '../application/qibla_controller.dart';
import '../data/city_index.dart';
import '../data/qibla_sensors.dart';
import '../domain/qibla_math.dart';
import '../domain/qibla_place.dart';
import 'calibration_hint.dart';
import 'qibla_dial.dart';

/// The Qibla finder (from the side menu and Home): the compass card turning
/// with the phone, the Kaaba on it at the qibla's bearing — worked out on
/// the phone from its location (automatic) or from a city chosen by hand.
/// The sky and glass of the app's other screens.
class QiblaScreen extends ConsumerWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(qiblaControllerProvider);
    return SkyBackdrop(
      child: Scaffold(
        appBar: TahfeezAppBar(title: Text(l10n.qiblaTitle), centerTitle: false),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TahfeezContentWidth.maxReading,
              ),
              child: ListView(
                padding: const EdgeInsets.all(TahfeezSpacing.md),
                children: [
                  _Entrance(
                    child: switch (state.status) {
                      QiblaStatus.ready => _Compass(place: state.place!),
                      _ => _Waiting(state: state),
                    },
                  ),
                  const SizedBox(height: TahfeezSpacing.lg),
                  _Entrance(delay: 1, child: _PlaceCard(state: state)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades and rises in as the screen opens (the app's cards' entrance).
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final total =
        TahfeezMotionDuration.slow + TahfeezMotionDuration.fast * delay;
    final start = delay == 0
        ? 0.0
        : TahfeezMotionDuration.fast.inMilliseconds *
              delay /
              total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: TahfeezMotionCurves.standard),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

({String north, String east, String south, String west}) _labels(
  AppLocalizations l10n,
) => (
  north: l10n.qiblaNorth,
  east: l10n.qiblaEast,
  south: l10n.qiblaSouth,
  west: l10n.qiblaWest,
);

/// The compass for [place]: the dial, how far to turn, the bearing and the
/// distance to Makkah.
class _Compass extends ConsumerStatefulWidget {
  const _Compass({required this.place});

  final QiblaPlace place;

  @override
  ConsumerState<_Compass> createState() => _CompassState();
}

class _CompassState extends ConsumerState<_Compass> {
  StreamSubscription<double?>? _sub;
  double? _heading;
  bool _facing = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_Compass old) {
    super.didUpdateWidget(old);
    if (old.place != widget.place) _listen();
  }

  void _listen() {
    unawaited(_sub?.cancel());
    final sensors = ref.read(qiblaSensorsProvider);
    if (!sensors.hasCompass) return;
    _sub = sensors
        .heading(
          latitude: widget.place.latitude,
          longitude: widget.place.longitude,
        )
        .listen((h) {
          if (!mounted) return;
          final bearing = qiblaBearing(
            widget.place.latitude,
            widget.place.longitude,
          );
          final facing =
              h != null &&
              turnTowards(h, bearing).abs() <= qiblaFacingTolerance;
          // Once as the phone comes round to the qibla.
          if (facing && !_facing) unawaited(HapticFeedback.mediumImpact());
          setState(() {
            _heading = h;
            _facing = facing;
          });
        });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCompass = ref.watch(qiblaSensorsProvider).hasCompass;
    final place = widget.place;
    final bearing = qiblaBearing(place.latitude, place.longitude);
    final km = distanceToKaabaKm(place.latitude, place.longitude);
    // English digits where intl has no data for the language (Hausa,
    // Kurdish, Somali): a missing locale would throw.
    final locale = intlLocaleOf(Localizations.localeOf(context));
    final heading = _heading;
    final turn = heading == null ? null : turnTowards(heading, bearing);

    final String guidance;
    if (!hasCompass) {
      guidance = l10n.qiblaNoCompass;
    } else if (turn == null) {
      // No heading yet: the calibration card below says what to do.
      guidance = '';
    } else if (_facing) {
      guidance = l10n.qiblaFacing;
    } else if (turn > 0) {
      guidance = l10n.qiblaTurnRight(turn.round().abs());
    } else {
      guidance = l10n.qiblaTurnLeft(turn.round().abs());
    }

    return Column(
      children: [
        Semantics(
          label: l10n.qiblaBearing(bearing.round()),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: QiblaDial(
              key: const ValueKey('qibla-dial'),
              bearing: bearing,
              heading: hasCompass ? heading : null,
              facing: _facing,
              labels: _labels(l10n),
            ),
          ),
        ),
        const SizedBox(height: TahfeezSpacing.md),
        AnimatedSwitcher(
          duration: TahfeezMotionDuration.medium,
          child: Text(
            guidance,
            key: ValueKey(
              _facing ? 'facing' : (turn == null ? guidance : 'turn'),
            ),
            textAlign: TextAlign.center,
            style:
                (_facing
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color: _facing ? scheme.primary : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        Text(
          '${l10n.qiblaBearing(bearing.round())} · '
          '${l10n.qiblaDistance(NumberFormat.decimalPattern(locale).format(km.round()))}',
          key: const ValueKey('qibla-bearing'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        // How to sharpen it: the phone traced in a figure 8 (owner,
        // 2026-11-20).
        if (hasCompass) ...[
          const SizedBox(height: TahfeezSpacing.lg),
          CalibrationHint(text: l10n.qiblaCalibrate),
        ],
      ],
    );
  }
}

/// No place yet: a faint dial, and what is happening (finding the
/// location) or what to do (allow it, turn it on, choose a city).
class _Waiting extends ConsumerWidget {
  const _Waiting({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(qiblaControllerProvider.notifier);
    final sensors = ref.read(qiblaSensorsProvider);
    final (message, action, onAction) = switch (state.status) {
      QiblaStatus.locating => (l10n.qiblaLocating, null, null),
      QiblaStatus.needsCity => (
        l10n.qiblaManualSub,
        l10n.qiblaChooseCity,
        () => showQiblaPlaceSheet(context),
      ),
      QiblaStatus.denied => (
        l10n.qiblaDenied,
        l10n.commonRetry,
        controller.locate,
      ),
      QiblaStatus.deniedForever => (
        l10n.qiblaDeniedForever,
        l10n.recMicOpenSettings,
        sensors.openAppSettings,
      ),
      QiblaStatus.locationOff => (
        l10n.qiblaLocationOff,
        l10n.qiblaTurnOnLocation,
        sensors.openLocationSettings,
      ),
      QiblaStatus.failed => (
        l10n.qiblaFailed,
        l10n.commonRetry,
        controller.locate,
      ),
      QiblaStatus.ready => ('', null, null),
    };
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Stack(
            alignment: Alignment.center,
            children: [
              QiblaDial(
                bearing: 0,
                heading: null,
                facing: false,
                labels: _labels(l10n),
                enabled: false,
              ),
              if (state.status == QiblaStatus.locating)
                const CircularProgressIndicator(),
            ],
          ),
        ),
        const SizedBox(height: TahfeezSpacing.md),
        Text(
          message,
          key: ValueKey('qibla-status-${state.status.name}'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        if (action != null) ...[
          const SizedBox(height: TahfeezSpacing.smPlus),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              FilledButton(
                key: const ValueKey('qibla-action'),
                onPressed: () => unawaited(Future.sync(onAction!)),
                child: Text(action),
              ),
              if (state.mode == QiblaMode.automatic)
                OutlinedButton(
                  key: const ValueKey('qibla-choose-city'),
                  onPressed: () => showQiblaPlaceSheet(context),
                  child: Text(l10n.qiblaChooseCity),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Where the qibla is worked out from, and the way to change it.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final place = state.place;
    final title = state.mode == QiblaMode.manual
        ? (place == null
              ? l10n.qiblaChooseCity
              : '${place.flag} ${place.name}'.trim())
        : l10n.qiblaYourLocation;
    final subtitle = state.mode == QiblaMode.manual
        ? l10n.qiblaManual
        : l10n.qiblaAutomatic;
    return TahfeezGlassSurface(
      key: const ValueKey('qibla-place'),
      // No live blur: it scrolls (a blur there flickers).
      blur: false,
      onTap: () => showQiblaPlaceSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: Row(
          spacing: TahfeezSpacing.md,
          children: [
            Icon(
              state.mode == QiblaMode.manual
                  ? Icons.location_city_rounded
                  : Icons.my_location_rounded,
              color: scheme.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
  }
}

/// The place's sheet: the phone's location, or a city found by name
/// ([search] typed in already: the responsive tests' list of cities).
Future<void> showQiblaPlaceSheet(BuildContext context, {String? search}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).qiblaPlaceTitle,
      besideOnWide: true,
      builder: (context) => _PlaceSheet(search: search),
    );

class _PlaceSheet extends ConsumerStatefulWidget {
  const _PlaceSheet({this.search});

  final String? search;

  @override
  ConsumerState<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends ConsumerState<_PlaceSheet> {
  late final _query = TextEditingController(text: widget.search);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(qiblaControllerProvider);
    final controller = ref.read(qiblaControllerProvider.notifier);
    final index = ref.watch(cityIndexProvider).value;
    final results = index?.search(_query.text) ?? const <QiblaPlace>[];

    Widget option({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required bool selected,
      required VoidCallback onTap,
    }) => ListTile(
      key: key,
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: AnimatedSwitcher(
        duration: TahfeezMotionDuration.fast,
        child: selected
            ? Icon(Icons.check_circle_rounded, color: scheme.primary)
            : const SizedBox.square(dimension: 24),
      ),
      onTap: onTap,
    );

    // One scrolling list (the options, the search, the cities): all of it
    // reachable on a short screen at large text.
    return ListView(
      shrinkWrap: true,
      children: [
        option(
          key: const ValueKey('qibla-automatic'),
          icon: Icons.my_location_rounded,
          title: l10n.qiblaAutomatic,
          subtitle: l10n.qiblaAutomaticSub,
          selected: state.mode == QiblaMode.automatic,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(controller.useAutomatic());
          },
        ),
        option(
          key: const ValueKey('qibla-manual'),
          icon: Icons.location_city_rounded,
          title: l10n.qiblaManual,
          subtitle: l10n.qiblaManualSub,
          selected: state.mode == QiblaMode.manual,
          onTap: controller.useManual,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
          ),
          child: TahfeezGlassSurface(
            blur: false,
            borderRadius: BorderRadius.circular(TahfeezRadii.pill),
            child: TextField(
              key: const ValueKey('qibla-city-search'),
              controller: _query,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: l10n.qiblaSearchCity,
                border: InputBorder.none,
                isDense: true,
                constraints: const BoxConstraints(minHeight: 48),
                contentPadding: EdgeInsets.zero,
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        if (_query.text.trim().isNotEmpty && results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(TahfeezSpacing.md),
            child: Text(
              index == null ? l10n.qiblaLocating : l10n.qiblaNoCity,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final city in results)
          ListTile(
            key: ValueKey('qibla-city-${city.name}-${city.country}'),
            leading: Text(city.flag, style: const TextStyle(fontSize: 22)),
            title: Text(city.name!),
            subtitle: Text(
              '${city.country} · '
              '${city.latitude.toStringAsFixed(2)}, '
              '${city.longitude.toStringAsFixed(2)}',
            ),
            onTap: () {
              unawaited(controller.chooseCity(city));
              Navigator.of(context).pop();
            },
          ),
        const SizedBox(height: TahfeezSpacing.sm),
      ],
    );
  }
}
