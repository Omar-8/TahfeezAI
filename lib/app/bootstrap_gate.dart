import 'package:flutter/material.dart';

import 'app.dart';
import '../core/theme/app_colors.dart';
import '../core/ui/app_name_text.dart';
import '../features/home/presentation/home_sky.dart';

/// Shown for the (typically brief, but real on a cold/first launch — see
/// `bootstrap.dart`'s own doc comment) window while [BundledDatasetSeeder]
/// verifies/imports the bundled Quran dataset, before [TahfeezApp] itself
/// ever builds.
///
/// A real, measured cost this exists to stop from blocking the very first
/// Flutter frame: a cold seed (first launch, or a bundled-dataset version
/// bump) took ~1.3s for the canonical Quran alone and ~2.6s with the
/// (dev/profile-only) Mushaf dataset also included, timed against the real
/// bundled assets. Previously `bootstrap()` awaited this *before*
/// `runApp()`, so the OS's own native launch screen simply stayed up for
/// that whole window — on native that's an acceptable, if slow, "splash"
/// experience, but on Web (no native splash to lean on, and a real
/// possibility of paying the cold-seed cost on more than just the very
/// first visit, since browser storage/OPFS can be cleared) it read as a
/// blank/frozen tab. This shows *something* immediately instead, then
/// swaps to the real app the instant seeding finishes — never delaying it
/// further than the seeding itself already does.
class TahfeezBootstrapGate extends StatefulWidget {
  const TahfeezBootstrapGate({super.key, required this.seeding});

  final Future<void> seeding;

  @override
  State<TahfeezBootstrapGate> createState() => _TahfeezBootstrapGateState();
}

class _TahfeezBootstrapGateState extends State<TahfeezBootstrapGate> {
  /// At least this long, so the name is seen rather than flashed.
  static const _minimum = Duration(milliseconds: 900);

  late final Future<void> _ready = Future.wait([
    widget.seeding.then((_) {}, onError: (_) {}),
    Future<void>.delayed(_minimum),
  ]);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: snapshot.connectionState == ConnectionState.done
            ? const TahfeezApp()
            : const _BootstrapSplash(),
      ),
    );
  }
}

/// The splash: the launcher icon's emblem where the system splash draws it
/// (centred, 288 dp across), on its colour, with the app's name below.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  static const _background = Color(0xFF03100C);

  static Widget _sky(DayPart part) {
    final (a, b) = part.colors(Brightness.light);
    return DaySky(
      part: part,
      brightness: Brightness.dark,
      paper: _background,
      ink: const Color(0xFFE8F2EC),
      colors: (
        Color.lerp(a, _background, 0.55)!,
        Color.lerp(b, _background, 0.6)!,
      ),
      lattice: 0.16,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: _background,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Home's sky for the time of day behind the emblem, at once
            // (the splash shows for about a second): its light colours
            // toned down into the launch screen's green, so they read on
            // it, and the star lattice clearly.
            Positioned.fill(child: _sky(DayPart.at(DateTime.now()))),
            Image.asset(
              'assets/branding/splash_icon.png',
              width: 288,
              height: 288,
            ),
            // Below the emblem (its visible part is ~192 dp across).
            Transform.translate(
              offset: const Offset(0, 120),
              child: const _FadeIn(
                child: AppNameText(
                  'TahfeezAI',
                  // On the splash's dark green: the mint.
                  aiColor: TahfeezExplorationPalette.darkPrimary,
                  style: TextStyle(
                    fontFamily: 'Noto Sans',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFFE8F2EC),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeOut,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
    ),
    child: child,
  );
}
