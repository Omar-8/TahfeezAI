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
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        // The app drawn as it is, the splash fading out over it — not the
        // two cross-faded: the app's first frames inside a fading layer
        // (its glass navigation bar's blur among them) showed as a black
        // screen for a moment on Android 11 (OpenGL), seconds on a slow
        // phone.
        return Stack(
          fit: StackFit.expand,
          textDirection: TextDirection.ltr,
          children: [
            if (ready) const TahfeezApp(),
            _FadeOut(visible: !ready, child: const _BootstrapSplash()),
          ],
        );
      },
    );
  }
}

/// [child] until [visible] turns false, then faded out and gone.
class _FadeOut extends StatefulWidget {
  const _FadeOut({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  State<_FadeOut> createState() => _FadeOutState();
}

class _FadeOutState extends State<_FadeOut>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(covariant _FadeOut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && oldWidget.visible) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isDismissed) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !widget.visible,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// The splash: the launcher icon's emblem where the system splash draws it
/// (centred, 288 dp across), on its colour, with the app's name below.
class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  static const _background = Color(0xFF03100C);

  static Widget _sky(DayPart part) {
    final sky = SkyBlend.at(DateTime.now(), Brightness.light);
    final (a, b) = (sky.a, sky.b);
    return DaySky(
      part: part,
      brightness: Brightness.dark,
      paper: _background,
      ink: const Color(0xFFE8F2EC),
      colors: (
        Color.lerp(a, _background, 0.55)!,
        Color.lerp(b, _background, 0.6)!,
      ),
      glowColor: SkyBlend.at(DateTime.now(), Brightness.dark).glow,
      lattice: 0.16,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The whole screen (whatever is around it could let it shrink to the
    // emblem: a dark square on black).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox.expand(
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
              // The emblem alone (cut out of the launcher icon's dark square,
              // which would show as a box on the sky).
              Image.asset(
                'assets/branding/splash_emblem.png',
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
              // Setting up takes a while (the first start): a quiet bar
              // under the name says it's working.
              Transform.translate(
                offset: const Offset(0, 172),
                child: const _FadeIn(
                  delay: Duration(milliseconds: 600),
                  child: SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      child: LinearProgressIndicator(
                        key: ValueKey('splash-progress'),
                        minHeight: 3,
                        color: TahfeezExplorationPalette.darkPrimary,
                        backgroundColor: Color(0x33E8F2EC),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fades [child] in (rising a little) after [delay] — by default just past
/// the first frames, which are the slowest of a cold start: begun at once,
/// the fade stutters through them.
class _FadeIn extends StatefulWidget {
  const _FadeIn({
    required this.child,
    this.delay = const Duration(milliseconds: 120),
  });

  final Widget child;
  final Duration delay;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _t = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // (Transitions: composited, not rebuilt every frame.)
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _t,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(_t),
      child: widget.child,
    ),
  );
}
