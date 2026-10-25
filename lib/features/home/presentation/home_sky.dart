import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../../../core/theme/components/components.dart';

/// The part of the day Home's sky shows.
enum DayPart {
  dawn,
  morning,
  afternoon,
  golden,
  sunset,
  night;

  /// By the clock (a fixed approximation of the prayer times' day: dawn
  /// from 4, the golden hour from 4 pm, sunset from 6:30, night from 8).
  static DayPart at(DateTime t) {
    final m = t.hour * 60 + t.minute;
    if (m < 4 * 60) return night;
    if (m < 7 * 60) return dawn;
    if (m < 12 * 60) return morning;
    if (m < 16 * 60) return afternoon;
    if (m < 18 * 60 + 30) return golden;
    if (m < 20 * 60) return sunset;
    return night;
  }

  /// The sky's two colours, light and dark, each designed for its mode.
  (Color, Color) colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (this) {
      dawn =>
        dark
            ? (const Color(0xFF3A2A33), const Color(0xFF272538))
            : (const Color(0xFFF6D9D0), const Color(0xFFE4DEF3)),
      morning =>
        dark
            ? (const Color(0xFF163029), const Color(0xFF14262D))
            : (const Color(0xFFD6EFE5), const Color(0xFFE3F0F6)),
      afternoon =>
        dark
            ? (const Color(0xFF1A2D24), const Color(0xFF2A291E))
            : (const Color(0xFFDCEEE2), const Color(0xFFF3EDD9)),
      golden =>
        dark
            ? (const Color(0xFF3A2C17), const Color(0xFF33231D))
            : (const Color(0xFFF6E1BC), const Color(0xFFF4D8C6)),
      sunset =>
        dark
            ? (const Color(0xFF3B2421), const Color(0xFF2A2238))
            : (const Color(0xFFF2CBB9), const Color(0xFFDACEEA)),
      night =>
        dark
            ? (const Color(0xFF141B33), const Color(0xFF1B1832))
            : (const Color(0xFFCFD8EE), const Color(0xFFDDD8EE)),
    };
  }

  /// The sun's (or the moon's) glow.
  Color glow(Brightness brightness) => switch (this) {
    night =>
      brightness == Brightness.dark
          ? const Color(0x55C9D4FF)
          : const Color(0x88FFFFFF),
    dawn || sunset || golden => const Color(0x66FFE2B0),
    _ => const Color(0x55FFF6D6),
  };
}

/// Home's sky by the time of day — on unless turned off in Settings.
class HomeSkyController extends Notifier<bool> {
  static const storageKey = 'home.time_of_day_sky';

  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getBool(storageKey);
    if (ref.mounted && stored != null) state = stored;
  }

  Future<void> setEnabled(bool on) async {
    state = on;
    await ref.read(browserStorageProvider).setBool(storageKey, on);
  }
}

final homeSkyProvider = NotifierProvider<HomeSkyController, bool>(
  HomeSkyController.new,
);

/// The clock for Home's sky; overridden in tests.
final homeSkyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Behind the top of Home: a soft sky in the colours of the time of day —
/// dawn, morning, afternoon, the golden hour, sunset, night — with the
/// sun's or moon's glow and the faint star lattice, fading into the page.
/// Looked at again every few minutes.
class HomeSky extends ConsumerStatefulWidget {
  const HomeSky({super.key, this.height = 460});

  final double height;

  @override
  ConsumerState<HomeSky> createState() => _HomeSkyState();
}

class _HomeSkyState extends ConsumerState<HomeSky> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(homeSkyProvider)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final part = DayPart.at(ref.watch(homeSkyClockProvider)());
    final (a, b) = part.colors(scheme.brightness);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return IgnorePointer(
      child: SizedBox(
        key: ValueKey('home-sky-${part.name}'),
        height: widget.height,
        child: ShaderMask(
          // Fading into the page towards the bottom.
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.5, 1],
          ).createShader(rect),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart.resolve(
                      Directionality.of(context),
                    ),
                    end: AlignmentDirectional.bottomEnd.resolve(
                      Directionality.of(context),
                    ),
                    colors: [a, b],
                  ),
                ),
              ),
              // The sun's or moon's glow, high on the far side.
              Align(
                alignment: Alignment(rtl ? -0.85 : 0.85, -0.9),
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        part.glow(scheme.brightness),
                        part.glow(scheme.brightness).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              TahfeezGeometricPattern(
                color: scheme.onSurface.withValues(alpha: 0.05),
                spacing: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
