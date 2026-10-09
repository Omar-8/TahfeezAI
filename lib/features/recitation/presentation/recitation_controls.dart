import 'dart:async' show unawaited;

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_models.dart';
import '../../listen/application/follow_along_controller.dart';
import '../../listen/presentation/follow_along_sheet.dart';
import '../../listen/presentation/listen_sheet.dart';
import '../../listen/application/quran_audio_player.dart';

import '../../../core/core_providers.dart';
import '../../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_providers.dart';
import '../../mushaf/application/mushaf_page_turn.dart';
import '../../../ai/speech/live_quran_recognizer.dart';
import '../application/live_recognition_controller.dart';
import '../application/recitation_providers.dart';
import '../application/mushaf_recitation_target.dart';
import '../application/sajdah_reminder.dart';
import '../../../ai/hifz/hifz_judge.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import '../../../ai/acoustic/quran_acoustic_verifier.dart';
import '../application/acoustic_verification_controller.dart';
import '../application/hifz_controller.dart';
import '../application/local_acoustic_inference_controller.dart';
import '../application/recitation_ai_config.dart';
import '../application/quran_match_controller.dart';
import '../application/recitation_session_controller.dart';
import 'recitation_loop_sheet.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../memorize/presentation/test_summary_sheet.dart';

export '../application/mushaf_recitation_target.dart';
export 'recitation_loop_sheet.dart' show HifzLoopButton;

/// Whether the app shell should replace its Home/Quran/Search navigation
/// with [RecitationBottomBar]: a Mushaf is open, or a session is running.
final recitationBarVisibleProvider = Provider.autoDispose<bool>((ref) {
  if (!ref.watch(recitationSupportedProvider)) return false;
  return ref.watch(mushafRecitationTargetProvider) != null ||
      ref.watch(recitationSessionControllerProvider).isActive;
});

/// Wraps a Mushaf screen's body and reports [location] (the page on
/// screen) to the app shell's recitation bar while it is on screen.
/// Lays out [child] exactly as-is, with a [RecitationProgressBar] drawn over
/// its top edge.
class RecitationMushafAnchor extends ConsumerStatefulWidget {
  const RecitationMushafAnchor({
    super.key,
    required this.location,
    required this.child,
  });

  final QuranLocation? location;
  final Widget child;

  @override
  ConsumerState<RecitationMushafAnchor> createState() =>
      _RecitationMushafAnchorState();
}

class _RecitationMushafAnchorState
    extends ConsumerState<RecitationMushafAnchor> {
  // Captured up front: `ref` is unusable by the time dispose runs.
  late final MushafRecitationTargetNotifier _target = ref.read(
    mushafRecitationTargetProvider.notifier,
  );

  /// Whether this Mushaf is on screen: its tab is the active one and no
  /// screen covers it (`TickerMode`). A Mushaf left open in another tab
  /// must not keep the recitation bar in place of the navigation.
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _report();
    } else {
      Future.microtask(() => _target.clear(this));
    }
  }

  @override
  void didUpdateWidget(RecitationMushafAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location && _visible == true) _report();
  }

  // Providers can't be modified while the widget tree is building.
  void _report() {
    final location = widget.location;
    Future.microtask(() {
      if (mounted && _visible == true) _target.show(this, location);
    });
  }

  @override
  void dispose() {
    final target = _target;
    Future.microtask(() => target.clear(this));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    // The page laid out exactly as without the bar, which is drawn over its
    // top edge.
    fit: StackFit.passthrough,
    children: [
      widget.child,
      PositionedDirectional(
        top: 0,
        start: 0,
        end: 0,
        child: RecitationProgressBar(location: widget.location),
      ),
    ],
  );
}

/// The app shell's bottom bar while a Mushaf is open: replaces the
/// Home/Quran/Settings [navigation] with the live-recitation bar, one row —
/// a start button before a session, stop and pause/resume while one runs
/// (its [RecordingDot] is in the app bar), with the hide-mode controls
/// beside them. Shows [navigation] otherwise.
///
/// Also reports permission-denied/error/saved outcomes as snackbars.
class RecitationBottomBar extends ConsumerWidget {
  const RecitationBottomBar({super.key, required this.navigation});

  final Widget navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(recitationBarVisibleProvider)) return navigation;

    ref.listen(recitationSessionControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final message = switch (next.phase) {
        RecitationPhase.permissionDenied => AppLocalizations.of(
          context,
        ).recMicNeeded,
        RecitationPhase.error =>
          next.errorMessage ?? AppLocalizations.of(context).recStopped,
        _ => null,
      };
      if (message == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      if (next.phase == RecitationPhase.permissionDenied ||
          next.phase == RecitationPhase.error) {
        ref.read(recitationSessionControllerProvider.notifier).dismissError();
      }
    });

    // A session over: its results (each ayah's grade and strength) — not
    // between Follow along's turns.
    ref.listen(testSummaryProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      if (ref.read(recitationSessionControllerProvider).isActive) return;
      if (ref.exists(followAlongControllerProvider) &&
          ref.read(followAlongControllerProvider) != null) {
        return;
      }
      showTestSummarySheet(context, next);
    });

    // An ayah of prostration recited: a reminder of Sujood al-Tilawah.
    if (ref.watch(liveRecognitionEnabledProvider)) {
      ref.listen(sajdahReminderProvider, (previous, next) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (next == null || messenger == null) return;
        final l10n = AppLocalizations.of(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const ValueKey('sajdah-reminder'),
              duration: const Duration(seconds: 8),
              content: Text(l10n.sajdahReminderMessage),
              action: SnackBarAction(
                label: l10n.sajdahReminderOff,
                onPressed: () {
                  final settings = ref.read(hifzSettingsProvider.notifier);
                  settings.update(
                    ref
                        .read(hifzSettingsProvider)
                        .copyWith(sajdahReminder: false),
                  );
                },
              ),
            ),
          );
      });
    }

    // Leaving the Mushaf — or opening a different surah or screen — ends
    // the recitation session.
    ref.listen(mushafRecitationTargetProvider, (previous, next) {
      final session = ref.read(recitationSessionControllerProvider);
      if (!session.isActive) return;
      if (next == null || next.owner != previous?.owner) {
        unawaited(
          ref.read(recitationSessionControllerProvider.notifier).stop(),
        );
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(recitationSessionControllerProvider);
    final location = ref.watch(mushafRecitationTargetProvider)?.location;
    final controller = ref.read(recitationSessionControllerProvider.notifier);
    // Watching keeps live recognition running alongside the session.
    final recognition = ref.watch(liveRecognitionEnabledProvider)
        ? ref.watch(liveRecognitionControllerProvider)
        : null;
    // ...and Quran position matching on top of it (Milestone R3), and
    // Hifz mode (R5).
    final quranMatch = recognition != null
        ? ref.watch(quranMatchControllerProvider)
        : null;
    if (recognition != null) ref.watch(hifzControllerProvider);
    // …and acoustic pronunciation checking (Quran Acoustic Verification).
    final acoustic = recognition != null
        ? ref.watch(acousticVerificationControllerProvider)
        : null;
    // …on the device: the one inference pipeline both of those use.
    final aiConfig = ref.watch(recitationAiConfigProvider);
    final inference =
        recognition != null && aiConfig.acoustic == QuranAcousticBackend.local
        ? ref.watch(localAcousticInferenceControllerProvider)
        : null;
    final centered = ref.watch(platformCapabilitiesProvider).isWeb;
    // A run of ayahs playing (not a single word): its controls take the
    // mic's place.
    final playing = ref.watch(quranAudioPlayerProvider);
    final listening = playing != null && !playing.isWord;
    final showDevPanel =
        recognition != null &&
        state.isActive &&
        ref.watch(liveRecognitionDevPanelEnabledProvider);

    return Material(
      key: const ValueKey('recitation-bottom-bar'),
      // Same surface as the navigation bar it replaces (and the system
      // navigation bar the shell already tints to match).
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDevPanel)
              RecognitionDevPanel(
                state: recognition,
                match: quranMatch,
                acoustic: acoustic,
                config: aiConfig,
                inference: inference,
              ),
            if (recognition != null)
              _RecitationAiNotice(config: aiConfig, inference: inference),
            // Whose turn it is, while Follow along runs.
            if (recognition != null) const FollowAlongBanner(),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: state.isActive
                      ? _SessionControls(
                          key: const ValueKey('recitation-session-controls'),
                          state: state,
                        )
                      : listening
                      ? const _ListenControls(key: ValueKey('listen-controls'))
                      : Row(
                          key: const ValueKey('recitation-start'),
                          // Web keeps the buttons together in the middle
                          // of the (usually wide) bar; Android spreads them
                          // to the edges, within thumb reach.
                          mainAxisAlignment: centered
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 8,
                              children: [
                                IconButton.filled(
                                  icon: const Icon(Icons.mic_rounded),
                                  tooltip: AppLocalizations.of(context)
                                      .recStart,
                                  onPressed:
                                      location == null ||
                                          state.phase ==
                                              RecitationPhase.starting
                                      ? null
                                      : () => controller.start(
                                          startLocation: location,
                                        ),
                                ),
                                // Listen: the reciter, from a range.
                                IconButton.filledTonal(
                                  key: const ValueKey('listen-open'),
                                  icon: const Icon(Icons.headphones_rounded),
                                  tooltip: AppLocalizations.of(context)
                                      .listenMenuTitle,
                                  onPressed: location == null
                                      ? null
                                      : () => showListenSheet(context),
                                ),
                                // Follow along: the reciter, then the user.
                                if (recognition != null)
                                  IconButton.filledTonal(
                                    key: const ValueKey('follow-open'),
                                    icon: const Icon(
                                      Icons.record_voice_over_rounded,
                                    ),
                                    tooltip: AppLocalizations.of(context)
                                        .followTitle,
                                    onPressed: location == null
                                        ? null
                                        : () => showFollowAlongSheet(context),
                                  ),
                              ],
                            ),
                            if (centered)
                              const SizedBox(width: _centeredGroupGap),
                            // The reveal/hide buttons scale down rather
                            // than overflow a narrow phone; the eye keeps
                            // its size and place.
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: MushafHideControls(
                                        part: MushafHideControlsPart.steps,
                                      ),
                                    ),
                                  ),
                                  MushafHideControls(
                                    part: MushafHideControlsPart.pinned,
                                  ),
                                ],
                              ),
                            ),
                          ],
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

class _SessionControls extends ConsumerWidget {
  const _SessionControls({super.key, required this.state});

  final RecitationSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recitationSessionControllerProvider.notifier);
    final canControl =
        state.phase == RecitationPhase.listening ||
        state.phase == RecitationPhase.paused;
    final centered = ref.watch(platformCapabilitiesProvider).isWeb;
    // Laid out like the bar before a session: stop and pause where the mic
    // was, the eye at the end — so it never moves, recording or not. The
    // reveal-next buttons are gone while reciting (revealing follows the
    // recitation). The web keeps the buttons together in the middle.
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          icon: const Icon(Icons.stop_rounded),
          tooltip: l10n.recStop,
          onPressed: canControl ? controller.stop : null,
        ),
        const SizedBox(width: 8),
        if (state.phase == RecitationPhase.paused)
          IconButton.filledTonal(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: l10n.recResume,
            onPressed: controller.resume,
          )
        else
          IconButton.filledTonal(
            icon: const Icon(Icons.pause_rounded),
            tooltip: l10n.recPause,
            onPressed: canControl ? controller.pause : null,
          ),
        // Revealing follows the recitation: only the eye stays.
        if (centered)
          const SizedBox(width: _centeredGroupGap)
        else
          const Spacer(),
        const MushafHideControls(part: MushafHideControlsPart.pinned),
      ],
    );
  }
}

/// The bar while the reciter plays (the Listen menu, or an ayah from its
/// sheet): stop, pause / resume and the speed where the mic was, the eye
/// where it always is (revealing follows the recitation).
class _ListenControls extends ConsumerWidget {
  const _ListenControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final player = ref.read(quranAudioPlayerProvider.notifier);
    final audio = ref.watch(audioControllerProvider);
    final centered = ref.watch(platformCapabilitiesProvider).isWeb;
    return StreamBuilder<AudioPlaybackState>(
      stream: audio.state,
      initialData: const AudioPlaybackState(isPlaying: true),
      builder: (context, snapshot) {
        final playback = snapshot.data ?? const AudioPlaybackState();
        final speed = playback.speed;
        return Row(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            IconButton.filled(
              key: const ValueKey('listen-stop'),
              style: IconButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              icon: const Icon(Icons.stop_rounded),
              tooltip: l10n.listenStop,
              onPressed: player.stop,
            ),
            const SizedBox(width: 8),
            if (playback.isPlaying)
              IconButton.filledTonal(
                key: const ValueKey('listen-pause'),
                icon: const Icon(Icons.pause_rounded),
                tooltip: l10n.recPause,
                onPressed: player.pause,
              )
            else
              IconButton.filledTonal(
                key: const ValueKey('listen-resume'),
                icon: const Icon(Icons.play_arrow_rounded),
                tooltip: l10n.recResume,
                onPressed: player.resume,
              ),
            const SizedBox(width: 4),
            TextButton(
              key: const ValueKey('listen-speed'),
              onPressed: () => player.cycleSpeed(speed),
              child: Text(
                '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                semanticsLabel: '${l10n.listenSpeed} $speed',
              ),
            ),
            // Revealing follows the recitation: only the eye stays.
            if (centered)
              const SizedBox(width: _centeredGroupGap)
            else
              const Spacer(),
            const MushafHideControls(part: MushafHideControlsPart.pinned),
          ],
        );
      },
    );
  }
}

/// That the microphone is recording, for a Mushaf screen's app bar: a red
/// dot while a session runs — pulsing a few times as recording starts or
/// resumes, then steady (not pulsing on: redrawing all the time would cost
/// the phone work the recognition needs), dimmed while paused, starting or
/// saving. Says so — its tooltip and semantics — in words. Nothing outside
/// a session.
class RecordingDot extends ConsumerStatefulWidget {
  const RecordingDot({super.key});

  @override
  ConsumerState<RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends ConsumerState<RecordingDot>
    with SingleTickerProviderStateMixin {
  static const _pulses = 3;

  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: 1,
  );

  /// Fades out and back [_pulses] times, ending lit.
  Future<void> _start() async {
    for (var i = 0; i < _pulses && mounted; i++) {
      try {
        await _pulse.reverse(from: 1).orCancel;
        await _pulse.forward().orCancel;
      } on TickerCanceled {
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(recitationSessionControllerProvider).phase ==
        RecitationPhase.listening) {
      _start();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recitationSessionControllerProvider, (previous, next) {
      final listening = next.phase == RecitationPhase.listening;
      if (listening && previous?.phase != RecitationPhase.listening) {
        _start();
      } else if (!listening) {
        _pulse
          ..stop()
          ..value = 1;
      }
    });
    final session = ref.watch(recitationSessionControllerProvider);
    if (!session.isActive) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (session.phase) {
      RecitationPhase.starting => l10n.recStarting,
      RecitationPhase.paused => l10n.recPaused,
      RecitationPhase.stopping => l10n.recSaving,
      _ => l10n.recListening,
    };
    final listening = session.phase == RecitationPhase.listening;
    return Tooltip(
      message: label,
      child: Semantics(
        key: const ValueKey('recording-dot'),
        label: label,
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FadeTransition(
            opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening
                    ? scheme.error
                    : scheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Hifz feedback settings, for a Mushaf screen's app bar (only where
/// live recognition, and so Hifz mode, is available).
class HifzSettingsButton extends ConsumerWidget {
  const HifzSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(liveRecognitionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('hifz-settings'),
      icon: const Icon(Icons.settings_outlined),
      tooltip: AppLocalizations.of(context).recHifzSettings,
      onPressed: () => showHifzSettingsSheet(context),
    );
  }
}

/// Gap between button groups when the bar's controls are centered (web).
const _centeredGroupGap = 24.0;

/// Memorization hide mode for the open Mushaf: an eye toggle that hides
/// every word (ayah markers and numbers stay), and — while hiding —
/// buttons that uncover the next ayah or the next single word, in reading
/// order from the first word on the page.
class MushafHideControls extends ConsumerWidget {
  const MushafHideControls({super.key, this.part = MushafHideControlsPart.all});

  /// Which of the controls to build: the bar places the eye
  /// ([MushafHideControlsPart.pinned]) where it never moves, and
  /// the reveal/hide buttons that come and go with hide mode
  /// ([MushafHideControlsPart.steps]) beside them.
  final MushafHideControlsPart part;

  static const _hideControlsGap = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return const SizedBox.shrink();
    final hide = ref.watch(mushafHideModeProvider);
    final spread = ref.watch(fullBleedContentProvider);
    final notifier = ref.read(mushafHideModeProvider.notifier);
    final page = firstVisiblePage(location.pageNumber, spread: spread);
    final canReveal = hide.nextRevealPage(page, spread: spread) != null;
    final canHide = hide.previousHidePage(page, spread: spread) != null;
    final turns = ref.read(mushafPageTurnRequestsProvider.notifier);

    // Once everything on screen is uncovered, the reveal buttons turn to
    // the next page — until the Mushaf's last page.
    final lastOnScreen = page + (spread ? 1 : 0);
    final pageCount = ref
        .watch(mushafByIdProvider(location.mushafId))
        .value
        ?.pageCount;
    final hasNextPage = pageCount == null || lastOnScreen < pageCount;
    VoidCallback? revealOrTurn(void Function() reveal) {
      if (canReveal) return reveal;
      return hasNextPage ? turns.next : null;
    }

    // The mirror image: once everything on screen is hidden, the hide
    // buttons go back to the previous page (or spread), which arrives fully
    // uncovered so hiding continues from its end — until page 1.
    final firstOnScreen = page;
    final previousPages = [
      for (var p = firstOnScreen - (spread ? 2 : 1); p < firstOnScreen; p++)
        if (p >= 1) p,
    ];
    VoidCallback? hideOrTurnBack(void Function() hideBack) {
      if (canHide) return hideBack;
      if (previousPages.isEmpty) return null;
      return () {
        notifier.revealPagesFully(previousPages);
        turns.previous();
      };
    }

    // Compact, so the bar still fits a phone next to the recording controls.
    const density = VisualDensity.compact;
    const gap = SizedBox(width: MushafHideControls._hideControlsGap);
    Widget tonal(String key, IconData icon, String tip, VoidCallback? onTap) =>
        IconButton.filledTonal(
          key: ValueKey(key),
          visualDensity: density,
          icon: Icon(icon),
          tooltip: tip,
          onPressed: onTap,
        );

    // Hifz mode (every recitation is a test) needs live recognition. While
    // a test runs the reveal/hide buttons drive it: revealing without
    // reciting counts as skipped, hiding back expects the words again.
    final hifzAvailable = ref.watch(liveRecognitionEnabledProvider);
    final hifz = hifzAvailable ? ref.watch(hifzControllerProvider) : null;
    final testing = hifz != null && hifz.active;
    final hifzController = hifzAvailable
        ? ref.read(hifzControllerProvider.notifier)
        : null;
    final testCanHide =
        testing &&
        (hifz.completed || compareWordRefs(hifz.expected!, hifz.first!) > 0);
    final onRevealAyah = testing
        ? (hifz.completed
              ? null
              : () => hifzController!.revealNext(wholeAyah: true))
        : revealOrTurn(() => notifier.revealNextAyah(page, spread: spread));
    final onRevealWord = testing
        ? (hifz.completed ? null : () => hifzController!.revealNext())
        : revealOrTurn(() => notifier.revealNextWord(page, spread: spread));
    final onHideWord = testing
        ? (testCanHide ? () => hifzController!.hideBack() : null)
        : hideOrTurnBack(() => notifier.hideLastWord(page, spread: spread));
    final onHideAyah = testing
        ? (testCanHide ? () => hifzController!.hideBack(wholeAyah: true) : null)
        : hideOrTurnBack(() => notifier.hideLastAyah(page, spread: spread));

    // Forward on the left, backward on the right — reading runs right to
    // left, so "next" points left — and the eye at the end: turning hide
    // mode on or off adds the reveal/hide buttons on the far side, never
    // moving the eye.
    final eye = IconButton(
      key: const ValueKey('mushaf-hide-toggle'),
      visualDensity: density,
      isSelected: hide.enabled,
      icon: const Icon(Icons.visibility_outlined),
      selectedIcon: const Icon(Icons.visibility_off_outlined),
      tooltip: hide.enabled
          ? AppLocalizations.of(context).recShowAyahs
          : AppLocalizations.of(context).recHideAyahs,
      style: hide.enabled
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            )
          : null,
      onPressed: notifier.toggle,
    );
    final steps = part == MushafHideControlsPart.pinned
        ? const <Widget>[]
        : [
            if (hide.enabled) ...[
              tonal(
                'mushaf-reveal-ayah',
                Icons.first_page_rounded,
                AppLocalizations.of(context).recRevealAyah,
                onRevealAyah,
              ),
              gap,
              tonal(
                'mushaf-reveal-word',
                Icons.keyboard_double_arrow_left_rounded,
                AppLocalizations.of(context).recRevealWord,
                onRevealWord,
              ),
              gap,
              tonal(
                'mushaf-hide-word',
                Icons.keyboard_double_arrow_right_rounded,
                AppLocalizations.of(context).recHideWord,
                onHideWord,
              ),
              gap,
              tonal(
                'mushaf-hide-ayah',
                Icons.last_page_rounded,
                AppLocalizations.of(context).recHideAyah,
                onHideAyah,
              ),
              gap,
            ],
          ];
    final pinned = part == MushafHideControlsPart.steps
        ? const <Widget>[]
        : [eye];
    return Row(mainAxisSize: MainAxisSize.min, children: [...steps, ...pinned]);
  }
}

/// The parts of [MushafHideControls].
enum MushafHideControlsPart {
  /// Everything: the reveal/hide buttons and the eye.
  all,

  /// The reveal/hide buttons (shown only in hide mode).
  steps,

  /// The eye.
  pinned,
}

/// Hifz progress and live feedback, above the recording controls.
class HifzStatusStrip extends StatelessWidget {
  const HifzStatusStrip({super.key, required this.state, this.acoustic});

  final HifzState state;
  final AcousticVerificationState? acoustic;

  /// A pronunciation mistake in plain words, in the UI language.
  static String describe(RecitationError e, AppLocalizations l10n) {
    String vowel(String? v) => switch (v) {
      'FATHA' => l10n.recFatha,
      'DAMMA' => l10n.recDamma,
      'KASRA' => l10n.recKasra,
      'SUKUN' => l10n.recSukunName,
      _ => (v ?? '').toLowerCase(),
    };
    final expected = e.expected.split(' ').first;
    final vowelName = switch (expected) {
      'َ' => l10n.recFatha,
      'ُ' => l10n.recDamma,
      'ِ' => l10n.recKasra,
      _ => expected,
    };
    // Idgham: a nūn (sākinah or a tanween's) merged into the next letter,
    // that letter doubled — heard as a nūn, or the letter single.
    final source = RegExp(r'\((.+)\)').firstMatch(e.expected)?.group(1);
    final fromNun =
        source != null &&
        ('ًٌٍ'.contains(source) || (source == 'ن' && expected != 'ن'));
    // A hidden nūn / mīm said plainly: ikhfāʾ «ں», iqlāb or ikhfāʾ
    // shafawī «۾».
    if (e.type == RecitationErrorType.wrongLetter) {
      if (expected == 'ں' && e.observed == 'ن') return l10n.recIkhfa;
      if (expected == '۾' && e.observed == 'م') return l10n.recIkhfaShafawi;
      if (expected == '۾' && e.observed == 'ن') return l10n.recIqlab;
    }
    if (fromNun &&
        ((e.type == RecitationErrorType.wrongLetter && e.observed == 'ن') ||
            (e.type == RecitationErrorType.shaddaError &&
                e.observed == 'NO_SHADDA'))) {
      return l10n.recIdgham(expected);
    }
    if (e.type == RecitationErrorType.wrongWord) {
      return l10n.recSaidOtherWord(e.observed ?? '');
    }
    if (e.type == RecitationErrorType.maddShort) {
      final sign = e.expected.split(' ').first;
      return l10n.recMaddShort(const {'ۦ': 'ي', 'ۥ': 'و'}[sign] ?? sign);
    }
    if (e.type == RecitationErrorType.qalqalaMissing) {
      // The echo's mark is listed on its letter (in its source).
      return l10n.recQalqala(source ?? expected);
    }
    return switch (e.type) {
      RecitationErrorType.wrongVowel => l10n.recExpectedHeard(
        vowelName,
        vowel(e.observed),
      ),
      RecitationErrorType.missingVowel => l10n.recNotHeard(vowelName),
      RecitationErrorType.sukunError => l10n.recSukunExpected(
        expected,
        vowel(e.observed),
      ),
      RecitationErrorType.shaddaError =>
        e.observed == 'NO_SHADDA'
            ? l10n.recShaddaMissing(expected)
            : l10n.recShaddaExtra(expected),
      RecitationErrorType.wrongLetter => l10n.recExpectedHeard(
        expected,
        e.observed ?? '',
      ),
      _ => l10n.recUnclear,
    };
  }

  static String _word(WordRef r) =>
      '${r.ayahId ~/ 1000}:${r.ayahId % 1000}:${r.wordIndex + 1}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = state.counts;
    int n(HifzVerdict v) => c[v] ?? 0;
    final correct = n(HifzVerdict.correct) + n(HifzVerdict.selfCorrected);
    final mistakes = n(HifzVerdict.wrong) + n(HifzVerdict.skipped);
    final (message, color) = switch (state) {
      HifzState(completed: true) => (
        AppLocalizations.of(context).recRangeComplete,
        scheme.primary,
      ),
      HifzState(pending: HifzVerdict.wrong) => (
        AppLocalizations.of(context).recWrongWord,
        scheme.error,
      ),
      HifzState(pending: HifzVerdict.skipped) => (
        AppLocalizations.of(context).recSkippedWord,
        scheme.error,
      ),
      HifzState(running: true)
          when acoustic?.lastMistake != null &&
              state.revealed.contains(acoustic!.lastMistake!.word) =>
        (
          AppLocalizations.of(context).recPronunciation(
            _word(acoustic!.lastMistake!.word),
            describe(acoustic!.lastMistake!, AppLocalizations.of(context)),
          ),
          const Color(0xFFEF6C00),
        ),
      HifzState(running: true, reviewing: final r?) => (
        AppLocalizations.of(context).recGoingBack(_word(r)),
        scheme.onSurfaceVariant,
      ),
      HifzState(running: true, expected: final e?) => (
        AppLocalizations.of(context).recNext(_word(e)),
        scheme.onSurfaceVariant,
      ),
      _ => (
        AppLocalizations.of(context).recStoppedShort,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      key: const ValueKey('hifz-status'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.school, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              key: const ValueKey('hifz-message'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '✓ $correct  ✗ $mistakes  ↺ ${n(HifzVerdict.selfCorrected)}'
            '  ? ${n(HifzVerdict.uncertain)}',
            key: const ValueKey('hifz-counts'),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hifz feedback settings and the memorization range.
Future<void> showHifzSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // As tall as its settings (not capped at half the screen), below the
    // app bar.
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: sheetBelowAppBar(context),
    builder: (context) => const _HifzSettingsSheet(),
  );
}

class _HifzSettingsSheet extends ConsumerWidget {
  const _HifzSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hifzSettingsProvider);
    final controller = ref.read(hifzSettingsProvider.notifier);
    final android = ref.watch(platformCapabilitiesProvider).isAndroid;
    final hifz = ref.watch(hifzControllerProvider);
    final corpus = ref.watch(quranWordCorpusProvider).value;
    final location = ref.watch(mushafRecitationTargetProvider)?.location;
    final spread = ref.watch(fullBleedContentProvider);
    final spans = ref.watch(mushafPageVersesProvider);
    final page = location is QuranLocationPage
        ? firstVisiblePage(location.pageNumber, spread: spread)
        : null;
    final chapter = hifz.range?.from.chapterNo ?? spans[page]?.first.chapterNo;
    var ayahCount = 0;
    if (corpus != null && chapter != null) {
      final start = corpus.verseStartPosition((chapterNo: chapter, verseNo: 1));
      if (start != null) {
        var p = start;
        while (p + 1 < corpus.length &&
            corpus.words[p + 1].verse.chapterNo == chapter) {
          p++;
        }
        ayahCount = corpus.words[p].verse.verseNo;
      }
    }

    Widget toggle(
      String title,
      String subtitle,
      bool value,
      HifzSettings Function(bool) apply,
    ) {
      return SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (v) => controller.update(apply(v)),
      );
    }

    final range = hifz.range;
    Widget ayahPicker(
      String id,
      String label,
      int? value,
      void Function(int) onPick,
    ) {
      return Row(
        children: [
          Text(label),
          const SizedBox(width: 12),
          DropdownButton<int>(
            key: ValueKey('hifz-range-$id'),
            value: value,
            hint: const Text('—'),
            items: [
              for (var v = 1; v <= ayahCount; v++)
                DropdownMenuItem(value: v, child: Text('$chapter:$v')),
            ],
            onChanged: hifz.running || chapter == null
                ? null
                : (v) {
                    if (v != null) onPick(v);
                  },
          ),
        ],
      );
    }

    final hifzController = ref.read(hifzControllerProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppLocalizations.of(context).recHifzMode,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            toggle(
              AppLocalizations.of(context).recStrict,
              AppLocalizations.of(context).recStrictSub,
              settings.strict,
              (v) => settings.copyWith(strict: v),
            ),
            toggle(
              AppLocalizations.of(context).recHighlight,
              AppLocalizations.of(context).recHighlightSub,
              settings.highlightCurrent,
              (v) => settings.copyWith(highlightCurrent: v),
            ),
            toggle(
              AppLocalizations.of(context).recColour,
              AppLocalizations.of(context).recColourSub,
              settings.colorWords,
              (v) => settings.copyWith(colorWords: v),
            ),
            toggle(
              AppLocalizations.of(context).recTajweed,
              AppLocalizations.of(context).recTajweedSub,
              settings.tajweed,
              (v) => settings.copyWith(tajweed: v),
            ),
            toggle(
              AppLocalizations.of(context).recShowMistakes,
              AppLocalizations.of(context).recShowMistakesSub,
              settings.showMistakes,
              (v) => settings.copyWith(showMistakes: v),
            ),
            toggle(
              AppLocalizations.of(context).sajdahReminder,
              AppLocalizations.of(context).sajdahReminderSub,
              settings.sajdahReminder,
              (v) => settings.copyWith(sajdahReminder: v),
            ),
            if (android)
              ListTile(
                key: const ValueKey('hifz-mistake-alert'),
                title: Text(AppLocalizations.of(context).recAlert),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // Vibrate and sound, each on or off: both, one, or none.
                  child: SegmentedButton<MistakeAlert>(
                    multiSelectionEnabled: true,
                    emptySelectionAllowed: true,
                    segments: [
                      ButtonSegment(
                        value: MistakeAlert.vibrate,
                        icon: const Icon(Icons.vibration),
                        label: Text(
                          AppLocalizations.of(context).recAlertVibrate,
                        ),
                      ),
                      ButtonSegment(
                        value: MistakeAlert.sound,
                        icon: const Icon(Icons.volume_up_outlined),
                        label: Text(AppLocalizations.of(context).recAlertSound),
                      ),
                    ],
                    selected: {
                      if (settings.alert.vibrates) MistakeAlert.vibrate,
                      if (settings.alert.beeps) MistakeAlert.sound,
                    },
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => controller.update(
                      settings.copyWith(
                        alert: MistakeAlert.of(
                          vibrate: s.contains(MistakeAlert.vibrate),
                          sound: s.contains(MistakeAlert.sound),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                range == null
                    ? AppLocalizations.of(context).recRangeDefault
                    : AppLocalizations.of(context).recRange(
                        '${range.from.chapterNo}:${range.from.verseNo}',
                        '${range.to.chapterNo}:${range.to.verseNo}',
                      ),
                key: const ValueKey('hifz-range-label'),
              ),
            ),
            if (chapter != null && ayahCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 24,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ayahPicker(
                      'From',
                      AppLocalizations.of(context).recFrom,
                      range?.from.verseNo,
                      (v) {
                        final to = range?.to.verseNo ?? ayahCount;
                        hifzController.setRange((
                          from: (chapterNo: chapter, verseNo: v),
                          to: (chapterNo: chapter, verseNo: to < v ? v : to),
                        ));
                      },
                    ),
                    ayahPicker(
                      'To',
                      AppLocalizations.of(context).recTo,
                      range?.to.verseNo,
                      (v) {
                        final from = range?.from.verseNo ?? 1;
                        hifzController.setRange((
                          from: (
                            chapterNo: chapter,
                            verseNo: from > v ? v : from,
                          ),
                          to: (chapterNo: chapter, verseNo: v),
                        ));
                      },
                    ),
                    if (range != null)
                      TextButton(
                        onPressed: hifz.running
                            ? null
                            : () => hifzController.setRange(null),
                        child: Text(AppLocalizations.of(context).recUseVisible),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Development-only live recognition diagnostics: engine status, the
/// latest partial and final transcripts, measured latency, and — with
/// [match] — the matched Quran position.
/// Says plainly when recitation can't be followed on this device: the
/// on-device model is missing or unusable, or offline mode refused part of
/// the configuration.
class _RecitationAiNotice extends StatelessWidget {
  const _RecitationAiNotice({required this.config, this.inference});

  final RecitationAiConfig config;
  final LocalAcousticInferenceState? inference;

  @override
  Widget build(BuildContext context) {
    final model = inference?.model;
    final message =
        config.violation ??
        inference?.error ??
        (model != null && !model.usable ? '$model' : null);
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('recitation-ai-notice'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
      ),
    );
  }
}

class RecognitionDevPanel extends StatelessWidget {
  const RecognitionDevPanel({
    super.key,
    required this.state,
    this.match,
    this.acoustic,
    this.config,
    this.inference,
  });

  final AcousticVerificationState? acoustic;
  final RecitationAiConfig? config;
  final LocalAcousticInferenceState? inference;

  final LiveRecognitionState state;
  final QuranMatchState? match;

  static String _word(WordRef r) =>
      '${r.ayahId ~/ 1000}:${r.ayahId % 1000}:${r.wordIndex + 1}';

  static String _ms(Duration? d) => d == null ? '–' : '${d.inMilliseconds} ms';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    final statusColor = switch (state.status) {
      LiveRecognizerStatus.listening => Colors.green.shade600,
      LiveRecognizerStatus.error ||
      LiveRecognizerStatus.unavailable => scheme.error,
      _ => scheme.onSurfaceVariant,
    };

    Widget transcript(String label, String? text, {bool strong = false}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(label, style: small)),
          Expanded(
            child: Text(
              text == null || text.isEmpty ? '…' : text,
              key: ValueKey('asr-$label'),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      key: const ValueKey('recognition-dev-panel'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('DEV', style: small.copyWith(fontSize: 9)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.circle, size: 8, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${state.recognizerName} · ${state.status.name}'
                  '${state.statusDetail == null ? '' : ' · ${state.statusDetail}'}',
                  key: const ValueKey('asr-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
              ),
            ],
          ),
          if (config case final c?)
            Text(
              'AI · ${c.label}',
              key: const ValueKey('asr-config'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
          if (inference case final i?)
            Text(
              'On-device · ${i.load == null ? (i.loading ? 'loading…' : '${i.model ?? 'checking…'}') : '${i.model?.manifest?.id} · ${i.load!.provider.name} · load ${_ms(i.load!.loadTime)}'}'
              ' · RTF ${i.rtf?.toStringAsFixed(2) ?? '–'} · window '
              '${_ms(i.lastWindow)} in ${_ms(i.lastRun)} · lag ${_ms(i.lag)}'
              ' · follow ${_ms(i.followLatency)} · locate ${_ms(i.locateLatency)}'
              '${i.peakPssKb == null ? '' : ' · peak ${i.peakPssKb! ~/ 1024} MB'}'
              '${i.droppedSeconds > 0 ? ' · dropped ${i.droppedSeconds.toStringAsFixed(1)} s' : ''}',
              key: const ValueKey('asr-local'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(
                color: i.error == null ? scheme.onSurface : scheme.error,
              ),
            ),
          const SizedBox(height: 2),
          transcript('Partial', state.latestPartial),
          transcript('Final', state.latestFinal, strong: true),
          Text(
            'Latency · first partial ${_ms(state.firstPartialLatency)} '
            '(avg ${_ms(state.averageFirstPartialLatency)}) · final '
            '${_ms(state.finalLatency)} (avg ${_ms(state.averageFinalLatency)})'
            ' · ${state.partialCount}P/${state.finalCount}F',
            key: const ValueKey('asr-latency'),
            style: small,
          ),
          if (match case final m?)
            Text(
              !m.ready
                  ? 'Quran · loading words…'
                  : 'Quran · ${m.current == null ? 'locating…' : _word(m.current!)}'
                        ' · confidence ${m.confidence.toStringAsFixed(2)}'
                        '${m.recentEvents.isEmpty ? '' : ' · ${m.recentEvents.last}'}',
              key: const ValueKey('asr-quran'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(color: scheme.onSurface),
            ),
          if (acoustic case final a? when a.active || a.error != null)
            Text(
              'Acoustic · ${a.utterances} utterances · '
              '${a.words.values.where((w) => w.isMistake).length} mistakes · '
              'latency ${_ms(a.lastLatency)} (model ${_ms(a.lastModelTime)})'
              ' · queue ${a.pending}'
              '${a.lastQuality == null ? '' : ' · ${a.lastQuality}'}'
              '${a.error == null ? '' : ' · ${a.error}'}',
              key: const ValueKey('asr-acoustic'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(
                color: a.error == null ? scheme.onSurface : scheme.error,
              ),
            ),
          if (state.lastError != null)
            Text(
              'Last error: ${state.lastError}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small.copyWith(color: scheme.error),
            ),
        ],
      ),
    );
  }
}

/// `m:ss`, or `h:mm:ss` from one hour.
String formatRecitationDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final seconds = two(d.inSeconds % 60);
  if (d.inHours > 0) {
    return '${d.inHours}:${two(d.inMinutes % 60)}:$seconds';
  }
  return '${d.inMinutes}:$seconds';
}
