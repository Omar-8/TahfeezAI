import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../core/ui/first_run.dart';
import '../listen/application/follow_along_controller.dart';
import '../listen/application/quran_audio_player.dart';
import '../mushaf/application/mushaf_hide_mode.dart';
import '../recitation/application/live_recognition_controller.dart';
import '../recitation/application/recitation_session_controller.dart';

/// The Mushaf's step-by-step guide: the screen dims around one control at a
/// time, with a short card about it. An overview of the modes, then — the
/// mode tapped — a tour of that mode: its menu's options one by one, then a
/// practice run the guide follows. Closable at any step.

/// What moves a step on, besides Next.
enum GuideWait {
  /// The user taps the highlighted control (the tap goes through to it).
  tap,

  /// A practice run is over: the recitation, Follow along or the reciter
  /// stopped (by stop, or by itself).
  practiceOver,
}

class GuideStep {
  const GuideStep(
    this.target,
    this.text, {
    this.wait,
    this.branches,
    this.card = true,
    this.tryIt = false,
  });

  /// A step to try on the page: the page in full view and usable, the card
  /// at the top (the sheets it opens rise from the bottom), with Back and
  /// Next.
  final bool tryIt;

  /// The step's card shown. Off for the practice runs of Recite, Loop and
  /// Follow along: the explanation sheet before the recitation
  /// (showRecitationIntro) is that step, said once, not a card over it.
  final bool card;

  /// A practice run: the page stays in full view (no dimming), the card at
  /// the bottom (no Back / Next) until the run is over.
  bool get practice => wait == GuideWait.practiceOver;

  /// The [GuideTarget] lit; `null`: the card alone.
  final String? target;
  final String Function(AppLocalizations) text;
  final GuideWait? wait;

  /// On the overview's last step: the tour each mode's tap opens, and the
  /// step it starts at (its "tap it" step done by that tap).
  final Map<String, (GuideTour, int)>? branches;
}

enum GuideTour { overview, recite, loop, listen, follow, hide }

List<GuideStep> guideSteps(GuideTour tour) => switch (tour) {
  GuideTour.overview => [
    // First the page itself: a word tapped, then long-pressed.
    GuideStep(null, (l) => l.guideWordTap, tryIt: true),
    GuideStep(null, (l) => l.guideWordLongPress, tryIt: true),
    GuideStep('modes', (l) => l.guideIntro),
    GuideStep('mode-recite', (l) => l.guideRecite),
    GuideStep('mode-loop', (l) => l.guideLoop),
    GuideStep('mode-listen', (l) => l.guideListen),
    GuideStep('mode-follow', (l) => l.guideFollow),
    GuideStep('eye', (l) => l.guideEye),
    GuideStep('hifz-settings', (l) => l.guideHifzSettings),
    GuideStep(
      'bar',
      (l) => l.guideChoose,
      wait: GuideWait.tap,
      branches: {
        'mode-recite': (GuideTour.recite, 3),
        'mode-loop': (GuideTour.loop, 1),
        'mode-listen': (GuideTour.listen, 1),
        'mode-follow': (GuideTour.follow, 1),
        'eye': (GuideTour.hide, 1),
      },
    ),
  ],
  GuideTour.hide => [
    GuideStep('eye', (l) => l.guideHideTap, wait: GuideWait.tap),
    GuideStep('mushaf-reveal-word', (l) => l.guideRevealWord),
    GuideStep('mushaf-reveal-ayah', (l) => l.guideRevealAyah),
    GuideStep('mushaf-hide-word', (l) => l.guideHideWord),
    GuideStep('mushaf-hide-ayah', (l) => l.guideHideAyah),
    GuideStep('eye', (l) => l.guideHideDone, wait: GuideWait.tap),
  ],
  GuideTour.recite => [
    GuideStep('hifz-settings', (l) => l.guideReciteSettings),
    GuideStep('eye', (l) => l.guideReciteEye),
    GuideStep('mode-recite', (l) => l.guideReciteTap, wait: GuideWait.tap),
    GuideStep(
      null,
      (l) => l.guideReciteNow,
      wait: GuideWait.practiceOver,
      card: false,
    ),
  ],
  GuideTour.loop => [
    GuideStep('mode-loop', (l) => l.guideLoopTap, wait: GuideWait.tap),
    GuideStep('loop-order', (l) => l.guideLoopOrder),
    GuideStep('loop-range', (l) => l.guideLoopRange),
    GuideStep('loop-times', (l) => l.guideLoopTimes),
    GuideStep('loop-start', (l) => l.guideLoopStart, wait: GuideWait.tap),
    GuideStep(
      null,
      (l) => l.guideLoopRecite,
      wait: GuideWait.practiceOver,
      card: false,
    ),
  ],
  GuideTour.listen => [
    GuideStep('mode-listen', (l) => l.guideListenTap, wait: GuideWait.tap),
    GuideStep('listen-reciter', (l) => l.guideListenReciter),
    GuideStep('listen-range', (l) => l.guideListenRange),
    GuideStep('listen-repeats', (l) => l.guideListenRepeats),
    GuideStep('listen-options', (l) => l.guideListenOptions),
    GuideStep('listen-play', (l) => l.guideListenPlay, wait: GuideWait.tap),
    GuideStep(null, (l) => l.guideListenPractice, wait: GuideWait.practiceOver),
  ],
  GuideTour.follow => [
    GuideStep('mode-follow', (l) => l.guideFollowTap, wait: GuideWait.tap),
    GuideStep('follow-reciter', (l) => l.guideFollowReciter),
    GuideStep('follow-range', (l) => l.guideFollowRange),
    GuideStep('follow-unit', (l) => l.guideFollowUnit),
    GuideStep('follow-strict', (l) => l.guideFollowStrict),
    GuideStep('follow-speed', (l) => l.guideFollowSpeed),
    GuideStep('follow-start', (l) => l.guideFollowStart, wait: GuideWait.tap),
    GuideStep(
      null,
      (l) => l.guideFollowPractice,
      wait: GuideWait.practiceOver,
      card: false,
    ),
  ],
};

/// The guide's place: which tour, which step.
typedef GuideState = ({GuideTour tour, int index});

class GuideController extends Notifier<GuideState?> {
  @override
  GuideState? build() => null;

  GuideStep? get step {
    final s = state;
    if (s == null) return null;
    final steps = guideSteps(s.tour);
    return s.index < steps.length ? steps[s.index] : null;
  }

  int get length => state == null ? 0 : guideSteps(state!.tour).length;

  /// Starts [tour] (the overview with the ayahs shown, so the modes are).
  void start([GuideTour tour = GuideTour.overview, int index = 0]) {
    if (tour == GuideTour.overview &&
        ref.read(mushafHideModeProvider).enabled) {
      ref.read(mushafHideModeProvider.notifier).toggle();
    }
    state = (tour: tour, index: index);
  }

  /// The overview's last step: choosing a mode.
  static final _choose = guideSteps(GuideTour.overview).length - 1;

  void next() {
    final s = state;
    if (s == null) return;
    if (s.index + 1 < length) {
      state = (tour: s.tour, index: s.index + 1);
    } else if (s.tour != GuideTour.overview) {
      // A mode learned: what it started stops (so the modes show again),
      // and back to choosing another.
      _stopModes();
      state = (tour: GuideTour.overview, index: _choose);
    } else {
      state = null;
    }
  }

  /// Stops a practice run — listening, Follow along, reciting — and shows
  /// the ayahs again (hide mode off), so the four modes are back in the
  /// bar.
  void _stopModes() {
    if (ref.read(mushafHideModeProvider).enabled) {
      ref.read(mushafHideModeProvider.notifier).toggle();
    }
    unawaited(ref.read(quranAudioPlayerProvider.notifier).stop());
    if (ref.exists(followAlongControllerProvider)) {
      unawaited(ref.read(followAlongControllerProvider.notifier).stop());
    }
    if (ref.exists(recitationSessionControllerProvider) &&
        ref.read(recitationSessionControllerProvider).isActive) {
      unawaited(ref.read(recitationSessionControllerProvider.notifier).stop());
    }
  }

  void back() {
    final s = state;
    if (s == null || s.index == 0) return;
    state = (tour: s.tour, index: s.index - 1);
  }

  void close() => state = null;

  /// The practice run was not started (its explanation closed): back to the
  /// step that asks for its button.
  void notStarted() {
    if (step?.practice ?? false) back();
  }

  /// A [GuideTarget] was tapped: on a "tap it" step, on (or, on the
  /// overview's last step, into the mode's tour).
  void tapped(String id) {
    final step = this.step;
    if (step == null || step.wait != GuideWait.tap) return;
    final branch = step.branches?[id];
    if (branch != null) {
      state = (tour: branch.$1, index: branch.$2);
    } else if (id == step.target) {
      next();
    }
  }
}

final guideProvider = NotifierProvider<GuideController, GuideState?>(
  GuideController.new,
);

/// The controls the guide can light, by id.
final _targets = <String, GlobalKey>{};

/// Marks [child] as the guide's [id]: found on screen, and its taps seen.
class GuideTarget extends ConsumerStatefulWidget {
  const GuideTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  ConsumerState<GuideTarget> createState() => _GuideTargetState();
}

class _GuideTargetState extends ConsumerState<GuideTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targets[widget.id] = _key;
  }

  @override
  void dispose() {
    if (_targets[widget.id] == _key) _targets.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: _key,
    behavior: HitTestBehavior.translucent,
    // After the control's own tap.
    onPointerUp: (_) => Future.microtask(() {
      if (ref.exists(guideProvider)) {
        ref.read(guideProvider.notifier).tapped(widget.id);
      }
    }),
    child: widget.child,
  );
}

/// The Mushaf top bar's "?": starts the guide's overview (where the modes
/// are: with live recognition) — and, the first time the reader opens (the
/// printed page or Ayah mode), starts it by itself.
class GuideButton extends ConsumerStatefulWidget {
  const GuideButton({super.key});

  @override
  ConsumerState<GuideButton> createState() => _GuideButtonState();
}

class _GuideButtonState extends ConsumerState<GuideButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !ref.read(liveRecognitionEnabledProvider)) return;
      if (!await firstRunDue(ref, 'guide')) return;
      // The page and its bar in place first.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted || ref.read(guideProvider) != null) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      ref.read(guideProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(liveRecognitionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('guide-open'),
      icon: const Icon(Icons.help_outline_rounded),
      tooltip: AppLocalizations.of(context).guideTooltip,
      onPressed: () => ref.read(guideProvider.notifier).start(),
    );
  }
}

/// Above everything (MaterialApp's builder): while the guide runs, dims the
/// screen around its step's control, with the step's card.
class GuideLayer extends ConsumerWidget {
  const GuideLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guide = ref.watch(guideProvider);
    return Stack(
      children: [
        child,
        // Its own Overlay: above the app's navigator, tooltips need one.
        if (guide != null)
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(builder: (_) => const _GuideOverlay()),
              ],
            ),
          ),
      ],
    );
  }
}

class _GuideOverlay extends ConsumerStatefulWidget {
  const _GuideOverlay();

  @override
  ConsumerState<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends ConsumerState<_GuideOverlay> {
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    // The lit control moves (sheets slide in, pages turn): measured after
    // every frame drawn while the guide is up — no frames of its own.
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  @override
  void dispose() {
    sheetTopFloor = 0;
    super.dispose();
  }

  void _afterFrame(Duration _) {
    if (!mounted) return;
    _scrollIntoView();
    _measure();
    _keepSheetsBelowCard();
    WidgetsBinding.instance.addPostFrameCallback(_afterFrame);
  }

  /// The card of a step to try on the page.
  final _tryItCard = GlobalKey();

  /// On a step to try on the page, the sheets its word opens (the word's,
  /// the ayah's) rise only up to below its card: their handles not under
  /// it, still pulled down to close.
  void _keepSheetsBelowCard() {
    final box = _tryItCard.currentContext?.findRenderObject() as RenderBox?;
    sheetTopFloor = box != null && box.attached && box.hasSize
        ? box.localToGlobal(box.size.bottomLeft(Offset.zero)).dy + 8
        : 0;
  }

  /// Back or Next on a step to try on the page: the sheet its word opened
  /// closed first, so the next step's control is in view.
  void _closeSheetsThen(VoidCallback move) {
    for (final key in _targets.values) {
      final context = key.currentContext;
      if (context == null || !context.mounted) continue;
      Navigator.maybeOf(
        context,
        rootNavigator: true,
      )?.popUntil((route) => route is! PopupRoute);
      break;
    }
    move();
  }

  /// The step whose control was last scrolled into view.
  GuideState? _scrolledFor;

  /// A new step's control in a scrolling list (a menu): scrolled into view.
  void _scrollIntoView() {
    final guide = ref.read(guideProvider);
    if (guide == null || guide == _scrolledFor) return;
    final id = ref.read(guideProvider.notifier).step?.target;
    final target = id == null ? null : _targets[id]?.currentContext;
    if (target == null) return;
    _scrolledFor = guide;
    if (Scrollable.maybeOf(target) != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        ),
      );
    }
  }

  void _measure() {
    final id = ref.read(guideProvider.notifier).step?.target;
    final box = id == null
        ? null
        : _targets[id]?.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    Rect? hole;
    if (box != null && box.attached && box.hasSize && me != null) {
      final topLeft = me.globalToLocal(box.localToGlobal(Offset.zero));
      hole = (topLeft & box.size).inflate(6);
    }
    if (hole != _hole) setState(() => _hole = hole);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(guideProvider.notifier);
    final guide = ref.watch(guideProvider)!;
    final step = controller.step;
    if (step == null) return const SizedBox.shrink();
    _listenFor(step.wait);
    // Its explanation is a sheet: nothing over it, the page usable.
    if (!step.card) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    if (step.tryIt) {
      return Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: KeyedSubtree(
                  key: _tryItCard,
                  child: _GuideCard(
                    key: const ValueKey('guide-try-it'),
                    text: step.text(l10n),
                    index: guide.index,
                    length: controller.length,
                    waiting: false,
                    tapToContinue: false,
                    onBack: guide.index == 0
                        ? null
                        : () => _closeSheetsThen(controller.back),
                    onNext: () => _closeSheetsThen(controller.next),
                    onClose: controller.close,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (step.practice) {
      // The page in full view and usable; the hint at the bottom, above
      // the recitation bar, until the run is over.
      return Stack(
        children: [
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 72 + 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _GuideCard(
                  text: step.text(l10n),
                  index: guide.index,
                  length: controller.length,
                  waiting: true,
                  tapToContinue: false,
                  onBack: null,
                  onNext: null,
                  onClose: controller.close,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final size = MediaQuery.sizeOf(context);
    final hole = _hole;
    final passThrough = step.wait == GuideWait.tap && hole != null;
    // Taps outside the hole stop here; inside it, on a "tap it" step, they
    // reach the control.
    Widget blocker(Rect r) => Positioned.fromRect(
      rect: r,
      child: const AbsorbPointer(child: SizedBox.expand()),
    );
    final blockers = hole == null || !passThrough
        ? [blocker(Offset.zero & size)]
        : [
            blocker(Rect.fromLTRB(0, 0, size.width, hole.top)),
            blocker(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
            blocker(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
            blocker(
              Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom),
            ),
          ];
    final cardAbove = hole != null && hole.center.dy > size.height / 2;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DimPainter(hole: hole)),
          ),
        ),
        ...blockers,
        Positioned(
          left: 16,
          right: 16,
          top: hole == null
              ? null
              : cardAbove
              ? null
              : hole.bottom + 12,
          bottom: hole == null
              ? size.height / 2 - 80
              : cardAbove
              ? size.height - hole.top + 12
              : null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _GuideCard(
                text: step.text(l10n),
                index: guide.index,
                length: controller.length,
                waiting: step.wait != null,
                tapToContinue: step.wait == GuideWait.tap,
                onBack: guide.index == 0 ? null : controller.back,
                onNext: step.wait == null || step.wait == GuideWait.tap
                    ? controller.next
                    : null,
                onClose: controller.close,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// A practice step: on when its run is over — the recitation, Follow
  /// along or the reciter stopped (by stop, or by itself).
  void _listenFor(GuideWait? wait) {
    if (wait != GuideWait.practiceOver) return;
    final controller = ref.read(guideProvider.notifier);
    void over() {
      if (controller.step?.wait == GuideWait.practiceOver) controller.next();
    }

    ref.listen(recitationSessionControllerProvider, (previous, next) {
      if ((previous?.isActive ?? false) && !next.isActive) over();
    });
    ref.listen(followAlongControllerProvider, (previous, next) {
      if (previous != null && next == null) over();
    });
    ref.listen(quranAudioPlayerProvider, (previous, next) {
      if (previous != null && !previous.isWord && next == null) over();
    });
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter({required this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole != null) {
      dim
        ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(dim, Paint()..color = const Color(0xB3000000));
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(16)),
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.hole != hole;
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    super.key,
    required this.text,
    required this.index,
    required this.length,
    required this.waiting,
    required this.tapToContinue,
    required this.onBack,
    required this.onNext,
    required this.onClose,
  });

  final String text;
  final int index, length;
  final bool waiting, tapToContinue;
  final VoidCallback? onBack, onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = index + 1 >= length;
    return Material(
      key: const ValueKey('guide-card'),
      elevation: 6,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(TahfeezRadii.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${index + 1}/$length',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const ValueKey('guide-close'),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.guideClose,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
            if (tapToContinue)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.guideTapToContinue,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onBack != null)
                  TextButton(
                    key: const ValueKey('guide-back'),
                    onPressed: onBack,
                    child: Text(l10n.guideBack),
                  ),
                if (onNext != null && !tapToContinue)
                  FilledButton(
                    key: const ValueKey('guide-next'),
                    onPressed: onNext,
                    child: Text(last ? l10n.guideDone : l10n.guideNext),
                  ),
                if (tapToContinue && last)
                  TextButton(
                    key: const ValueKey('guide-finish'),
                    onPressed: onNext ?? onClose,
                    child: Text(l10n.guideDone),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
