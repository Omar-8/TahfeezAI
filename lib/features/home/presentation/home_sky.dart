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
            : (const Color(0xFFF1BFAE), const Color(0xFFD3C7EE)),
      morning =>
        dark
            ? (const Color(0xFF163029), const Color(0xFF14262D))
            : (const Color(0xFFB4E1CE), const Color(0xFFC3DDF0)),
      afternoon =>
        dark
            ? (const Color(0xFF1A2D24), const Color(0xFF2A291E))
            : (const Color(0xFFBFE1CB), const Color(0xFFEBDCB0)),
      golden =>
        dark
            ? (const Color(0xFF3A2C17), const Color(0xFF33231D))
            : (const Color(0xFFF0C886), const Color(0xFFEDB89A)),
      sunset =>
        dark
            ? (const Color(0xFF3B2421), const Color(0xFF2A2238))
            : (const Color(0xFFEAA48C), const Color(0xFFC6B2E3)),
      night =>
        dark
            ? (const Color(0xFF141B33), const Color(0xFF1B1832))
            : (const Color(0xFFA9B9E4), const Color(0xFFC4B9E6)),
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

/// The sky's colours at any moment: the parts of the day as keyframes
/// (night until 3:30, dawn at 5:30, morning at 8, afternoon at 12:30, the
/// golden hour at 4:30 pm, sunset at 6:45, night again from 8:30), blended
/// in between — the sky shifts through the day rather than in steps.
abstract final class SkyBlend {
  static const _keys = [
    (3 * 60 + 30, DayPart.night),
    (5 * 60 + 30, DayPart.dawn),
    (8 * 60, DayPart.morning),
    (12 * 60 + 30, DayPart.afternoon),
    (16 * 60 + 30, DayPart.golden),
    (18 * 60 + 45, DayPart.sunset),
    (20 * 60 + 30, DayPart.night),
  ];

  /// The sky's two colours and the glow's at [t], for [brightness].
  static ({Color a, Color b, Color glow}) at(
    DateTime t,
    Brightness brightness,
  ) {
    final m = t.hour * 60 + t.minute + t.second / 60;
    // The keyframes around [m] (the night wraps past midnight).
    var (fromM, from) = (_keys.last.$1 - 24 * 60, _keys.last.$2);
    var (toM, to) = _keys.first;
    for (var i = 0; i < _keys.length; i++) {
      if (m < _keys[i].$1) {
        (toM, to) = _keys[i];
        if (i > 0) (fromM, from) = _keys[i - 1];
        break;
      }
      if (i == _keys.length - 1) {
        (fromM, from) = _keys[i];
        (toM, to) = (_keys.first.$1 + 24 * 60, _keys.first.$2);
      }
    }
    final k = ((m - fromM) / (toM - fromM)).clamp(0.0, 1.0);
    final (a0, b0) = from.colors(brightness);
    final (a1, b1) = to.colors(brightness);
    return (
      a: Color.lerp(a0, a1, k)!,
      b: Color.lerp(b0, b1, k)!,
      glow: Color.lerp(from.glow(brightness), to.glow(brightness), k)!,
    );
  }
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
    final now = ref.watch(homeSkyClockProvider)();
    final sky = SkyBlend.at(now, scheme.brightness);
    return DaySky(
      part: DayPart.at(now),
      brightness: scheme.brightness,
      colors: (sky.a, sky.b),
      glowColor: sky.glow,
      paper: scheme.surface,
      ink: scheme.onSurface,
      height: widget.height,
    );
  }
}

/// The sky itself, [height] tall (else as tall as it is given): [part]'s
/// colours for [brightness] — leaning a little towards a light [paper] —
/// the sun's or moon's glow, and the star lattice in [ink], fading out
/// towards the bottom. Needs no providers: the splash draws it too.
class DaySky extends StatelessWidget {
  const DaySky({
    super.key,
    required this.part,
    required this.brightness,
    required this.paper,
    required this.ink,
    this.height,
    this.lattice,
    this.colors,
    this.glowColor,
  });

  final DayPart part;
  final Brightness brightness;
  final Color paper, ink;
  final double? height;

  /// The star lattice's opacity (else the screens' own).
  final double? lattice;

  /// The sky's two colours, in place of [part]'s for [brightness].
  final (Color, Color)? colors;

  /// The glow's colour, in place of [part]'s.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    // Light papers (standard, warm, sepia): the sky leans a little towards
    // the paper, so each keeps its character.
    var (a, b) = colors ?? part.colors(brightness);
    final glow = glowColor ?? part.glow(brightness);
    if (brightness == Brightness.light && paper != Colors.transparent) {
      a = Color.lerp(a, paper, 0.12)!;
      b = Color.lerp(b, paper, 0.12)!;
    }
    final direction = Directionality.of(context);
    final rtl = direction == TextDirection.rtl;
    return IgnorePointer(
      child: SizedBox(
        key: ValueKey('home-sky-${part.name}'),
        height: height,
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
                    begin: AlignmentDirectional.topStart.resolve(direction),
                    end: AlignmentDirectional.bottomEnd.resolve(direction),
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
                    // Softly: a hint of light, not a reflection.
                    gradient: RadialGradient(
                      colors: [
                        glow.withValues(alpha: glow.a * 0.65),
                        glow.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              TahfeezGeometricPattern(
                color: ink.withValues(
                  alpha:
                      lattice ?? (brightness == Brightness.light ? 0.15 : 0.12),
                ),
                spacing: 52,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A screen over the time-of-day sky, as Home is: the sky behind its top —
/// its app bar's too, made see-through — and its cards frosted glass
/// ([TahfeezGlass]). The Quran tab, Memorize, Progress, Settings.
class SkyBackdrop extends StatelessWidget {
  const SkyBackdrop({super.key, required this.child});

  /// The screen's [Scaffold].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          const Positioned(top: 0, left: 0, right: 0, child: HomeSky()),
          TahfeezGlass(
            child: Theme(
              data: theme.copyWith(
                scaffoldBackgroundColor: Colors.transparent,
                appBarTheme: theme.appBarTheme.copyWith(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                ),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
