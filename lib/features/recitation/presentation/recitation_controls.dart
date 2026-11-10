import 'dart:math' as math;
import 'dart:async' show Timer, unawaited;

import '../../../core/sharing/image_sharer.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../ai/acoustic/local_quran_acoustic_model.dart';

import 'package:flutter/foundation.dart'
    show ValueListenable, kReleaseMode, listEquals;
import 'package:flutter/material.dart';

import '../../../core/platform/app_settings_opener.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_models.dart';
import '../../listen/presentation/sleep_timer_choices.dart';
import '../../listen/application/follow_along_controller.dart';
import '../../listen/presentation/follow_along_sheet.dart';
import '../../listen/application/quran_audio_player.dart';

import '../../../core/app_store/app_store_service.dart';
import '../../../core/core_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/tahfeez_bottom_sheet.dart';
import '../../../core/theme/components/tahfeez_collapsible_section.dart';
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
import '../application/recitation_hints.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../ai/acoustic/acoustic_model_download.dart';
import '../../guide/app_tips.dart';
import '../../mushaf/presentation/mushaf_pager.dart'
    show ayahModeIsContinuous, webSpreadPages, webSpreadWidth;
import '../../guide/app_tips_host.dart';
import '../../guide/guide.dart';
import '../../../memorization/application/activity_stats.dart';
import '../../../ai/hifz/hifz_judge.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../mushaf/application/mushaf_word_overlay.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../../../ai/acoustic/quran_acoustic_verifier.dart';
import '../application/acoustic_verification_controller.dart';
import '../application/hifz_controller.dart';
import '../application/local_acoustic_inference_controller.dart';
import '../application/mic_level.dart';
import '../application/recitation_ai_config.dart';
import '../application/quran_match_controller.dart';
import '../application/recitation_session_controller.dart';
import '../../listen/presentation/listen_sheet.dart';
import 'quick_start.dart';
import 'recitation_loop_sheet.dart';
import '../../mushaf/presentation/mushaf_appearance_sheet.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../memorize/presentation/test_summary_sheet.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/ui/motion.dart';

export '../application/mushaf_recitation_target.dart';

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

  /// Times how long a Mushaf is on screen (Progress → activity).
  late final ActivityStatsController _activity = ref.read(
    activityStatsProvider.notifier,
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
    _activity.mushafShown(visible);
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
    _activity.mushafShown(false);
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
/// (the stop button's ring showing the microphone hears), with the
/// hide-mode controls beside them. Shows [navigation] otherwise.
///
/// Also reports permission-denied/error/saved outcomes as snackbars.
/// A row of the bar's buttons as one rounded group, thin dividers between
/// them (mic · Listen · Follow along; stop · pause; the reveal/hide steps).
class BarButtonGroup extends StatelessWidget {
  const BarButtonGroup({
    super.key,
    required this.children,
    this.groupHeight = height,
    this.expand = false,
    this.flex,
  });

  final List<Widget> children;

  /// Fills the width it is given, the buttons sharing it evenly — or by
  /// [flex], a share each.
  final bool expand;
  final List<int>? flex;

  /// Its height ([height]; [labelledHeight] with labels under the icons).
  final double groupHeight;

  static const height = 40.0;
  static const labelledHeight = 48.0;

  /// A button inside the group: plain (the group is its background).
  static final buttonStyle = IconButton.styleFrom(
    fixedSize: const Size(42, height),
    minimumSize: const Size(42, height),
    padding: EdgeInsets.zero,
    iconSize: 20,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: groupHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(groupHeight / 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                indent: 10,
                endIndent: 10,
                color: scheme.outlineVariant,
              ),
            if (expand)
              Expanded(flex: flex?[i] ?? 1, child: children[i])
            else
              children[i],
          ],
        ],
      ),
    );
  }
}

/// The Sujood al-Tilawah reminder while it is up (a session's results wait
/// for it).
Future<void>? _sajdahPopup;

/// The Sujood al-Tilawah reminder: a small popup (above anything the
/// session's end opens), with a way to turn it off.
Future<void> showSajdahReminder(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (context) => AlertDialog(
      key: const ValueKey('sajdah-reminder'),
      icon: const Icon(Icons.mosque_outlined),
      title: Text(l10n.sajdahReminderTitle),
      content: Text(l10n.sajdahReminderMessage),
      actions: [
        TextButton(
          onPressed: () {
            ref
                .read(hifzSettingsProvider.notifier)
                .update(
                  ref
                      .read(hifzSettingsProvider)
                      .copyWith(sajdahReminder: false),
                );
            Navigator.of(context).pop();
          },
          child: Text(l10n.sajdahReminderOff),
        ),
        FilledButton(
          key: const ValueKey('sajdah-reminder-ok'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    ),
  );
}

/// After one of the first recitations: the tip it calls for, if any, when
/// the check marked much of it — tajweed checking off, or lenient
/// strictness (see [recitationHintAfter]). Not the guide's practice, nor
/// between Follow along's turns.
Future<RecitationHint?> _recitationHint(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(appTipsEnabledProvider)) return null;
  if (!ref.read(liveRecognitionEnabledProvider)) return null;
  if (ref.read(guideProvider) != null) return null;
  if (ref.exists(followAlongControllerProvider) &&
      ref.read(followAlongControllerProvider) != null) {
    return null;
  }
  final storage = ref.read(browserStorageProvider);
  // (Tips turned off: none, and none counted as given.)
  if (!await appTipOn(storage, AppTip.tajweedOff)) return null;
  // The last words' checks still arriving: a few seconds at most.
  for (var i = 0; i < 25; i++) {
    if (ref.read(acousticVerificationControllerProvider).pending == 0) break;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!context.mounted) return null;
  }
  return recitationHintAfter(
    storage,
    ref.read(hifzSettingsProvider),
    ref.read(hifzControllerProvider.notifier).lastPronunciation(),
  );
}

/// The results last shown (a Follow along run's not shown twice).
TestSummary? _shownSummary;

/// The last session's tip ([_recitationHint]), worked out as it ended.
Future<RecitationHint?>? _sessionHint;

/// Over a session's results: its tip, if it called for one. Close: the
/// results stay; "Show me": the Hifz settings over them.
Future<void> _offerSessionTip(BuildContext context, WidgetRef ref) async {
  final pending = _sessionHint;
  _sessionHint = null;
  final hint = await pending;
  if (!context.mounted) return;
  if (hint == null) return _offerMistakeTip(context, ref);
  // The results up first.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (!context.mounted || ref.read(guideProvider) != null) return;
  if (await answerAppTip(context, ref, appTipFor(hint)) && context.mounted) {
    await showHifzSettingsSheet(context);
  }
}

/// Once, over the results of the first session with mistakes: a marked
/// word opens its sheet. "Show me": the first mistake's sheet over the
/// results (closed, back to them).
Future<void> _offerMistakeTip(BuildContext context, WidgetRef ref) async {
  if (!appTipsAllowed(ref)) return;
  final first = firstMarkedMistake(ref.read(mushafWordOverlayProvider));
  if (first == null) return;
  final storage = ref.read(browserStorageProvider);
  if (!await appTipOn(storage, AppTip.tapMistake)) return;
  // The results up first.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  if (!context.mounted || !appTipsAllowed(ref)) return;
  final showMe = await answerAppTip(context, ref, AppTip.tapMistake);
  // Once, whatever the answer.
  await appTipOff(storage, AppTip.tapMistake);
  if (!showMe || !context.mounted) return;
  showWordDetailSheet(context, wordRef: first);
}

class RecitationBottomBar extends ConsumerWidget {
  const RecitationBottomBar({super.key, required this.navigation});

  final Widget navigation;

  /// The navigation and the recitation bar take each other's place by a
  /// fade, at the new one's height at once — not grown frame by frame,
  /// which would lay the Mushaf page out again on every frame (owner,
  /// 2026-11-09: the bar jumped as a reader opened). The old bar stays
  /// whole for the first third — while the reader's first frames are
  /// built, which would otherwise be a jump in the fade — then the two
  /// cross.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(recitationBarVisibleProvider);
    return AnimatedSwitcher(
      duration: motion(context, TahfeezMotionDuration.slow),
      // In: from a third of the way. Out (run backwards): whole until then.
      switchInCurve: const Interval(
        _barWait,
        1,
        curve: TahfeezMotionCurves.standard,
      ),
      switchOutCurve: const Interval(
        0,
        1 - _barWait,
        curve: TahfeezMotionCurves.standard,
      ),
      // The new bar's height at once, both ways: the old one fading out
      // over the page's edge (not holding the old height until it is gone,
      // then snapping to the new).
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          for (final old in previous)
            Positioned(left: 0, right: 0, bottom: 0, child: old),
          ?current,
        ],
      ),
      child: shown
          ? const _LiveRecitationBar(key: ValueKey('recitation-bar-shown'))
          : KeyedSubtree(
              key: const ValueKey('navigation-bar-shown'),
              child: navigation,
            ),
    );
  }
}

/// The share of the bars' cross-fade spent waiting (see
/// [RecitationBottomBar.build]).
const _barWait = 0.35;

/// The recitation bar itself, while a Mushaf is open (or a session runs).
class _LiveRecitationBar extends ConsumerWidget {
  const _LiveRecitationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      final l10n = AppLocalizations.of(context);
      final denied = next.phase == RecitationPhase.permissionDenied;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            // Refused: how to allow it — the app's settings page, or (in a
            // browser) the site's microphone setting.
            content: Text(
              denied && !AppSettingsOpener.supported
                  ? '$message ${l10n.recMicAllowBrowser}'
                  : message,
            ),
            duration: denied
                ? const Duration(seconds: 8)
                : const Duration(seconds: 4),
            action: denied && AppSettingsOpener.supported
                ? SnackBarAction(
                    key: const ValueKey('mic-open-settings'),
                    label: l10n.recMicOpenSettings,
                    onPressed: () =>
                        unawaited(const AppSettingsOpener().open()),
                  )
                : null,
          ),
        );
      if (next.phase == RecitationPhase.permissionDenied ||
          next.phase == RecitationPhase.error) {
        ref.read(recitationSessionControllerProvider.notifier).dismissError();
      }
    });

    // One of the first recitations over, much of it marked: a tip, over
    // its results.
    ref.listen(recitationSessionControllerProvider, (previous, next) {
      if (previous?.isActive != true || next.isActive) return;
      _sessionHint = _recitationHint(context, ref);
      ref.read(freshResultsProvider.notifier).set(true);
    });
    // (Kept while the bar is: gone, and reset, with the reader.)
    ref.listen(freshResultsProvider, (_, _) {});

    // A session over: its results (each ayah's grade and strength) — not
    // between Follow along's turns.
    ref.listen(testSummaryProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      // (Logged outside release builds: why a summary was not shown.)
      void skipped(String why) {
        if (!kReleaseMode) {
          debugPrint('Summary: ${next.rows.length} rows not shown: $why');
        }
      }

      if (ref.read(recitationSessionControllerProvider).isActive) {
        return skipped('session active');
      }
      // Started again with new settings: not the cut-short run's.
      if (restartedJustNow) return skipped('restarted');
      // Not while the guide runs: practice ends back at its choice of modes.
      if (ref.read(guideProvider) != null) return skipped('guide');
      if (ref.exists(followAlongControllerProvider) &&
          ref.read(followAlongControllerProvider) != null) {
        return skipped('follow along');
      }
      if (!kReleaseMode) {
        debugPrint('Summary: ${next.rows.length} rows shown');
      }
      _shownSummary = next;
      // After the Sujood al-Tilawah reminder, if it is up.
      final reminder = _sajdahPopup;
      if (reminder == null) {
        showTestSummarySheet(context, next);
        unawaited(_offerSessionTip(context, ref));
      } else {
        reminder.whenComplete(() {
          if (!context.mounted) return;
          showTestSummarySheet(context, next);
          unawaited(_offerSessionTip(context, ref));
        });
      }
    });

    // A Follow along run over: its results, all its turns together — shown
    // as its last turn's arrive (above), or, with none still to come (it
    // was stopped while the reciter recited), a moment later.
    ref.listen(followAlongControllerProvider, (previous, next) {
      if (previous == null || next != null) return;
      final summaries = ref.read(testSummaryProvider.notifier);
      Future<void>.delayed(const Duration(milliseconds: 2500), () {
        summaries.endRun();
        final summary = ref.read(testSummaryProvider);
        if (!context.mounted ||
            summary == null ||
            summary.rows.isEmpty ||
            identical(summary, _shownSummary) ||
            restartedJustNow ||
            ref.read(followAlongControllerProvider) != null ||
            ref.read(recitationSessionControllerProvider).isActive ||
            ref.read(guideProvider) != null) {
          return;
        }
        _shownSummary = summary;
        showTestSummarySheet(context, summary);
      });
    });

    // An ayah of prostration recited: a reminder of Sujood al-Tilawah.
    if (ref.watch(liveRecognitionEnabledProvider)) {
      ref.listen(sajdahReminderProvider, (previous, next) {
        if (next == null || _sajdahPopup != null) return;
        _sajdahPopup = showSajdahReminder(
          context,
          ref,
        ).whenComplete(() => _sajdahPopup = null);
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
    // A wide browser window: the bar's controls three quarters as wide as
    // the Mushaf's two-page spread, the modes never folded into one button.
    final barWidth = wideWebBarWidth(context, ref);
    final starting = state.phase == RecitationPhase.starting;
    final hidden = ref.watch(mushafHideModeProvider.select((h) => h.enabled));
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
      // Follow along's turn hint sits on the bar's top border, over the page.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SafeArea(
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
                if (inference != null) const _ModelDownload(),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 12,
                    ),
                    child: _BarWidth(
                      width: barWidth,
                      child: AnimatedSwitcher(
                        duration: TahfeezMotionDuration.medium,
                        child: state.isActive
                            ? _SessionControls(
                                key: const ValueKey(
                                  'recitation-session-controls',
                                ),
                                state: state,
                              )
                            : listening
                            ? const _ListenControls(
                                key: ValueKey('listen-controls'),
                              )
                            : GuideTarget(
                                id: 'bar',
                                child: _UnderPages(
                                  key: const ValueKey('recitation-start'),
                                  wide: barWidth != null,
                                  left: _ModeButtons(
                                    location: location,
                                    starting: starting,
                                    recognition: recognition != null,
                                    collapsed: false,
                                    expand: true,
                                  ),
                                  right: _RevealUnderPage(hidden: hidden),
                                  otherwise: Row(
                                    // Spread to the edges, within thumb reach.
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ..._idleRow(
                                        location: location,
                                        starting: starting,
                                        recognition: recognition != null,
                                        hidden: hidden,
                                        roomy: barWidth != null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (recognition != null ||
              ref.watch(coloursOffNoticeProvider) != null)
            const Positioned(
              top: -FollowAlongHint.height / 2 + 4,
              left: 16,
              right: 16,
              child: _BarHints(),
            ),
        ],
      ),
    );
  }
}

/// Whether a recitation has finished since the reader opened: its
/// "Mistakes found" shown — not the kept colours' of an earlier visit
/// (owner, 2026-11-08). Gone with the reader.
class FreshResults extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool fresh) => state = fresh;
}

final freshResultsProvider = NotifierProvider.autoDispose<FreshResults, bool>(
  FreshResults.new,
);

/// Whether the eye's "colours off" notice is showing: for 5 s after the
/// colours are turned off (or until two words are heard). Turned off again
/// while it shows, it is neither queued nor started over (owner,
/// 2026-11-08).
///
/// Each of the eye's states is said so (owner, 2026-11-08): colours shown,
/// colours off, ayahs hidden — each its own 5 s: switched to another state
/// while one shows, the new one replaces it and its 5 s start; the same
/// one again is not started over.
class ColoursOffNotice extends Notifier<EyeNotice?> {
  static const duration = Duration(seconds: 5);

  Timer? _timer;

  @override
  EyeNotice? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show([EyeNotice kind = EyeNotice.coloursOff]) {
    if (state == kind) return;
    state = kind;
    _timer?.cancel();
    _timer = Timer(duration, hide);
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (ref.mounted && state != null) state = null;
  }
}

/// What the eye was just set to, said on the bar.
enum EyeNotice { colours, coloursOff, hidden }

final coloursOffNoticeProvider = NotifierProvider<ColoursOffNotice, EyeNotice?>(
  ColoursOffNotice.new,
);

/// Follow along's hint and a strict loop's, on the bar's top border: taps
/// go through them — but "Mistakes found" opens the first mistake's word
/// sheet (what was expected, what was heard; on from it to the others).
/// It shows too after a recitation, while its mistakes are on the page in
/// view (nothing recording, following or playing).
class _BarHints extends ConsumerWidget {
  const _BarHints();

  /// The mistakes marked on the page(s) in view, in reading order.
  static List<WordRef> _onScreen(WidgetRef ref) {
    final location = ref.watch(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return const [];
    final spread = ref.watch(fullBleedContentProvider);
    final first = firstVisiblePage(location.pageNumber, spread: spread);
    final ranges = ref.watch(mushafPageWordRangesProvider);
    final shown = [
      for (final page in [first, if (spread) first + 1]) ?ranges[page],
    ];
    return [
      for (final word in markedMistakes(ref.watch(mushafWordOverlayProvider)))
        if (shown.any(
          (r) =>
              compareWordRefs(r.first, word) <= 0 &&
              compareWordRefs(r.last, word) >= 0,
        ))
          word,
    ];
  }

  /// The recitation whose listening hint has gone (its first words heard):
  /// not back for its later passes.
  static Object? _listenedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follow = ref.watch(followAlongControllerProvider);
    final review =
        follow?.phase == FollowAlongPhase.review ||
        ref.watch(hifzControllerProvider.select((h) => h.loopReview));
    final session = ref.watch(recitationSessionControllerProvider);
    // Recite or Loop listening: "Listening — start reciting", until two
    // words are heard.
    final heard = ref.watch(
      hifzControllerProvider.select(
        (h) => [
          HifzVerdict.correct,
          HifzVerdict.uncertain,
          HifzVerdict.wrong,
          HifzVerdict.selfCorrected,
          HifzVerdict.repeated,
        ].fold<int>(0, (n, v) => n + (h.counts[v] ?? 0)),
      ),
    );
    final id = session.session?.id;
    if (id != null && heard >= 2) _listenedIn = id;
    final listening =
        !review &&
        follow == null &&
        id != null &&
        _listenedIn != id &&
        session.phase == RecitationPhase.listening &&
        ref.watch(guideProvider) == null;
    // After a recitation, its mistakes on the page in view — until one of
    // them has been looked at.
    // (Only a recitation finished since the reader opened: not the colours
    // kept from before — owner, 2026-11-08.)
    final idle =
        !review &&
        follow == null &&
        !session.isActive &&
        ref.watch(freshResultsProvider) &&
        ref.watch(quranAudioPlayerProvider) == null &&
        ref.watch(guideProvider) == null;
    final overlay = ref.watch(mushafWordOverlayProvider);
    final onScreen =
        idle &&
            !listEquals(
              ref.watch(mistakesSeenProvider),
              markedMistakes(overlay),
            )
        ? _onScreen(ref)
        : const <WordRef>[];
    // Colours just turned off: said for 5 s, or until two words are heard.
    final eyeNotice = ref.watch(coloursOffNoticeProvider);
    if (eyeNotice != null && id != null && heard >= 2) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(coloursOffNoticeProvider.notifier).hide(),
      );
    }
    final loopLeft = follow == null && !review
        ? loopTimesLeft(
            ref.watch(hifzControllerProvider),
            AppLocalizations.of(context),
          )
        : null;
    final Widget child;
    if (eyeNotice != null && !review) {
      child = IgnorePointer(
        key: ValueKey('eye-notice-${eyeNotice.name}'),
        child: _HintPill.eye(
          eyeNotice,
          key: ValueKey(
            eyeNotice == EyeNotice.coloursOff
                ? 'colours-off-hint'
                : 'eye-notice-hint',
          ),
        ),
      );
    } else if (review || onScreen.isNotEmpty) {
      child = MouseRegion(
        key: ValueKey(review ? 'mistakes-review' : 'mistakes-found'),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const ValueKey('mistakes-hint'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final word = onScreen.isNotEmpty
                ? onScreen.first
                : firstMarkedMistake(ref.read(mushafWordOverlayProvider));
            if (word != null) showWordDetailSheet(context, wordRef: word);
          },
          child: review
              ? const Stack(
                  alignment: Alignment.center,
                  children: [FollowAlongHint(), _LoopReviewHint()],
                )
              : const _MistakesPill(key: ValueKey('mistakes-found-hint')),
        ),
      );
    } else if (listening) {
      child = const IgnorePointer(
        key: ValueKey('listening'),
        child: _HintPill.listening(key: ValueKey('listening-hint')),
      );
    } else if (session.isActive && loopLeft != null) {
      // A loop under way: the times left of the ayah being recited.
      child = IgnorePointer(
        key: const ValueKey('loop-left'),
        child: _HintPill.loop(loopLeft, key: const ValueKey('loop-left-hint')),
      );
    } else {
      child = const IgnorePointer(
        key: ValueKey('hints'),
        child: Stack(
          alignment: Alignment.center,
          children: [FollowAlongHint(), _LoopReviewHint()],
        ),
      );
    }
    // Each comes and goes in a fade.
    return Center(
      child: AnimatedSwitcher(
        duration: TahfeezMotionDuration.slow,
        child: child,
      ),
    );
  }
}

/// A strict loop's pass with mistakes, on the bar's top border like
/// Follow along's hint: look them over, then try again or skip.
class _LoopReviewHint extends ConsumerWidget {
  const _LoopReviewHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hifzControllerProvider.select((h) => h.loopReview))) {
      return const SizedBox.shrink();
    }
    return const _HintPill.review(key: ValueKey('loop-review-hint'));
  }
}

/// "Mistakes found — tap to see them", as a pill on the bar's top border.
class _MistakesPill extends StatelessWidget {
  const _MistakesPill({super.key});

  @override
  Widget build(BuildContext context) => const _HintPill.mistakes();
}

/// A hint as a pill on the bar's top border: mistakes found, or the
/// microphone listening.
class _HintPill extends StatelessWidget {
  const _HintPill.mistakes()
    : kind = _Hint.mistakes,
      loopText = null,
      eye = null;

  /// A loop's last time with mistakes: what Try again and Skip do.
  const _HintPill.review({super.key})
    : kind = _Hint.review,
      loopText = null,
      eye = null;
  const _HintPill.listening({super.key})
    : kind = _Hint.listening,
      loopText = null,
      eye = null;
  const _HintPill.eye(EyeNotice this.eye, {super.key})
    : kind = _Hint.coloursOff,
      loopText = null;
  const _HintPill.loop(String this.loopText, {super.key})
    : kind = _Hint.loop,
      eye = null;

  final _Hint kind;

  /// The eye's state just set.
  final EyeNotice? eye;

  /// A loop's: the ayah, and how many times are left.
  final String? loopText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final (background, foreground) = switch (kind) {
      _Hint.mistakes ||
      _Hint.review => (scheme.errorContainer, scheme.onErrorContainer),
      _Hint.loop => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ => (scheme.primary, scheme.onPrimary),
    };
    final style = theme.textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );
    // (Colours off: wrapped to two lines where one is too short.)
    final wraps = kind == _Hint.coloursOff || kind == _Hint.review;
    return Container(
      height: wraps ? null : FollowAlongHint.height,
      constraints: const BoxConstraints(minHeight: FollowAlongHint.height),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: wraps ? 4 : 0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(
            switch (kind) {
              _Hint.mistakes || _Hint.review => Icons.error_outline_rounded,
              _Hint.coloursOff => switch (eye) {
                EyeNotice.hidden => Icons.visibility_off_outlined,
                _ => Icons.visibility_outlined,
              },
              _Hint.loop => Icons.repeat_rounded,
              _Hint.listening => Icons.mic_rounded,
            },
            color: foreground,
            size: 16,
          ),
          Flexible(
            child: Text(
              switch (kind) {
                _Hint.mistakes => l10n.followMistakesFound,
                _Hint.review => l10n.recReviewHint,
                _Hint.coloursOff => switch (eye) {
                  EyeNotice.colours => l10n.recColoursOnHint,
                  EyeNotice.hidden => l10n.recAyahsHiddenHint,
                  _ => l10n.recColoursOffHint,
                },
                _Hint.loop => loopText!,
                _Hint.listening => l10n.recListeningHint,
              },
              maxLines: wraps ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: wraps ? TextAlign.center : null,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Hint { mistakes, review, listening, coloursOff, loop }

/// A running loop, in words for the bar: the ayah being recited and how
/// many times are left of it, this one included (owner, 2026-11-08) — a
/// whole-range loop's passes left, without its ayahs one by one; `null`
/// without a loop under way.
String? loopTimesLeft(HifzState hifz, AppLocalizations l10n) {
  final loop = hifz.loop;
  if (loop == null || hifz.repetition == 0 || hifz.completed) return null;
  final ayah = hifz.loopAyah;
  final left = switch (loop.mode) {
    HifzLoopMode.eachAyah => loop.count - hifz.repetition + 1,
    HifzLoopMode.range when loop.byAyah =>
      loop.perAyah - hifz.ayahRepetition + 1,
    HifzLoopMode.range => loop.count - hifz.repetition + 1,
  };
  if (left < 1) return null;
  return [
    if (ayah != null && loop.byAyah) '${ayah.chapterNo}:${ayah.verseNo}',
    l10n.recLoopLeft(left),
  ].join(' · ');
}

/// The idle bar's row: the modes, then the reveal/hide buttons and the eye.
/// With the ayahs shown (no reveal buttons) the modes' labelled group takes
/// all the room up to the eye (on a phone); with hide mode on it collapses
/// to one button and the reveal buttons take that room, as tall as the
/// modes were (on a wider screen, centred, they scale down rather than
/// overflow). The eye keeps its place.
List<Widget> _idleRow({
  required QuranLocation? location,
  required bool starting,
  required bool recognition,
  required bool hidden,
  required bool roomy,
}) {
  // Folded into one button with hide mode on — unless there is room (a
  // wide browser window): then the modes and the reveal buttons share it.
  final collapsed = hidden && !roomy;
  final modes = _ModeButtons(
    location: location,
    starting: starting,
    recognition: recognition,
    collapsed: collapsed,
    expand: !collapsed,
  );
  return [
    if (hidden) ...[
      if (collapsed) modes else Expanded(child: modes),
      const SizedBox(width: 12),
      const Expanded(
        child: MushafHideControls(
          part: MushafHideControlsPart.steps,
          expand: true,
        ),
      ),
    ] else ...[
      Expanded(child: modes),
      const SizedBox(width: 12),
    ],
    const MushafHideControls(part: MushafHideControlsPart.pinned),
  ];
}

/// In a wide browser window, the bar's controls' width: three quarters of
/// the Mushaf's two-page spread (its pages as tall as the window allows,
/// their gutter and frames), at most the window less its margins; `null` on a
/// phone, a tablet's app, or a phone-sized browser window — the bar as it
/// is there.
double? wideWebBarWidth(BuildContext context, WidgetRef ref) {
  if (!ref.watch(platformCapabilitiesProvider).isWeb) return null;
  final size = MediaQuery.sizeOf(context);
  if (size.width < webWideFrom) return null;
  // Three quarters of the spread's width.
  return math.min(size.width - 32, math.max(560, 0.75 * webSpreadWidth(size)));
}

/// [child] centred at [width] (a wide browser window), else as it is.
class _BarWidth extends StatelessWidget {
  const _BarWidth({required this.width, required this.child});

  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = this.width;
    if (width == null) return child;
    return ValueListenableBuilder(
      valueListenable: webSpreadPages,
      builder: (context, spread, child) => Center(
        child: ConstrainedBox(
          // Under a two-page spread: as wide as both pages and their gutter
          // (the controls split between them, [_UnderPages]).
          constraints: BoxConstraints(
            maxWidth: spread == null
                ? width
                : 2 * spread.pageWidth + spread.gutter,
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// In a wide browser window showing two pages ([webSpreadPages]): [left]
/// under the left page and [right] under the right one, each as wide as
/// its page (mirrored in a right-to-left language); else [otherwise].
class _UnderPages extends StatelessWidget {
  const _UnderPages({
    super.key,
    required this.wide,
    required this.left,
    required this.right,
    required this.otherwise,
  });

  final bool wide;
  final Widget left, right, otherwise;

  @override
  Widget build(BuildContext context) {
    if (!wide) return otherwise;
    return ValueListenableBuilder(
      valueListenable: webSpreadPages,
      builder: (context, spread, _) {
        if (spread == null) return otherwise;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: spread.pageWidth, child: left),
            SizedBox(width: spread.gutter),
            SizedBox(width: spread.pageWidth, child: right),
          ],
        );
      },
    );
  }
}

/// Under the right page (a wide browser window): the reveal buttons over
/// its width when the ayahs are hidden ([short]: as tall as stop and
/// pause), and the eye at its end.
class _RevealUnderPage extends StatelessWidget {
  const _RevealUnderPage({required this.hidden, this.short = false});

  final bool hidden, short;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (hidden)
        Expanded(
          child: MushafHideControls(
            part: MushafHideControlsPart.steps,
            expand: true,
            short: short,
          ),
        )
      else
        const Spacer(),
      const SizedBox(width: 12),
      const MushafHideControls(part: MushafHideControlsPart.pinned),
    ],
  );
}

/// The recitation bar's modes before one starts: recite (the mic), loop,
/// listen and follow along, as one group — or, [collapsed] (hide mode on,
/// its reveal buttons beside), one button opening them as a menu. Fades in
/// as either.
class _ModeButtons extends ConsumerWidget {
  const _ModeButtons({
    required this.location,
    required this.starting,
    required this.recognition,
    required this.collapsed,
    this.expand = false,
  });

  final QuranLocation? location;
  final bool starting, recognition, collapsed;

  /// Stretched over the room it is given, the buttons sharing it evenly.
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final location = this.location;
    final controller = ref.read(recitationSessionControllerProvider.notifier);
    // In the guide a tap opens a mode's menu: its tours go through it.
    final guided = ref.watch(guideProvider) != null;
    final modes = [
      (
        key: 'recite',
        icon: Icons.mic_rounded,
        label: l10n.recStart,
        short: l10n.modeRecite,
        settings: null,
        onPressed: location == null || starting
            ? null
            : () async {
                // How the check works, before it listens (the first time,
                // and in the guide).
                if (!await showRecitationIntro(
                  context,
                  RecitationIntroMode.recite,
                )) {
                  return;
                }
                await controller.start(startLocation: location);
              },
      ),
      if (recognition)
        (
          key: 'hifz-loop',
          icon: Icons.repeat_rounded,
          label: l10n.recLoop,
          short: l10n.modeLoop,
          // A tap starts it as last set; its ⋮ (or a long press) sets it.
          settings: location == null
              ? null
              : () => showRecitationLoopSheet(context),
          onPressed: location == null
              ? null
              : guided
              ? () => showRecitationLoopSheet(context)
              : () => quickLoop(context, ref),
        ),
      (
        key: 'listen-open',
        icon: Icons.headphones_rounded,
        label: l10n.listenMenuTitle,
        short: l10n.modeListen,
        settings: location == null ? null : () => showListenSheet(context),
        onPressed: location == null
            ? null
            : guided
            ? () => showListenSheet(context)
            : () => quickListen(context, ref),
      ),
      if (recognition)
        (
          key: 'follow-open',
          icon: Icons.record_voice_over_rounded,
          label: l10n.followTitle,
          short: l10n.modeFollow,
          settings: location == null
              ? null
              : () => showFollowAlongSheet(context),
          onPressed: location == null
              ? null
              : guided
              ? () => showFollowAlongSheet(context)
              : () => quickFollow(context, ref),
        ),
    ];
    // A small phone: the ⋮ narrower, closer.
    final compact = MediaQuery.sizeOf(context).width < 420;
    final Widget child;
    if (collapsed) {
      child = BarButtonGroup(
        key: const ValueKey('modes-collapsed'),
        // As tall as the reveal buttons beside it (and the modes were).
        groupHeight: BarButtonGroup.labelledHeight,
        children: [
          MenuAnchor(
            alignmentOffset: const Offset(0, 4),
            menuChildren: [
              for (final m in modes)
                MenuItemButton(
                  key: ValueKey('modes-menu-${m.key}'),
                  leadingIcon: Icon(
                    m.icon,
                    color: m.key == 'recite' ? scheme.primary : null,
                  ),
                  // Its settings, at the item's end (the menu closed first).
                  trailingIcon: m.settings == null
                      ? null
                      : Builder(
                          builder: (context) => IconButton(
                            key: ValueKey('modes-menu-${m.key}-settings'),
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.arrow_drop_up_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: l10n.recModeSettings(m.label),
                            onPressed: () {
                              MenuController.maybeOf(context)?.close();
                              m.settings!();
                            },
                          ),
                        ),
                  onPressed: m.onPressed,
                  child: Text(m.label),
                ),
            ],
            builder: (context, menu, _) => IconButton(
              key: const ValueKey('modes-open'),
              style: BarButtonGroup.buttonStyle.copyWith(
                fixedSize: const WidgetStatePropertyAll(
                  Size(56, BarButtonGroup.labelledHeight),
                ),
              ),
              tooltip: l10n.recModes,
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_rounded, color: scheme.primary),
                  const Icon(Icons.arrow_drop_up_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // Each with a short name under its icon (the full one as its
      // tooltip and in the collapsed menu).
      child = GuideTarget(
        id: 'modes',
        child: BarButtonGroup(
          key: const ValueKey('modes-group'),
          groupHeight: BarButtonGroup.labelledHeight,
          expand: expand,
          // Recite (no ⋮) a smaller share: the room to the modes with one.
          flex: [for (final m in modes) m.settings == null ? 4 : 5],
          children: [
            for (final m in modes)
              _withSettings(
                expand: expand,
                compact: compact,
                settings: m.settings == null
                    ? null
                    : GuideTarget(
                        // (The guide shows the first, Loop's or Listen's.)
                        id: m == modes[1]
                            ? 'mode-settings'
                            : 'settings-${m.key}',
                        child: _ModeSettingsButton(
                          compact: compact,
                          key: ValueKey('${m.key}-settings'),
                          tooltip: l10n.recModeSettings(m.label),
                          onPressed: m.settings!,
                        ),
                      ),
                button: GuideTarget(
                  id:
                      'mode-${m.key == 'recite'
                          ? 'recite'
                          : m.key == 'hifz-loop'
                          ? 'loop'
                          : m.key == 'listen-open'
                          ? 'listen'
                          : 'follow'}',
                  child: _LabelledModeButton(
                    key: m.key == 'recite' ? null : ValueKey(m.key),
                    icon: m.icon,
                    label: m.short,
                    tooltip: m.label,
                    color: m.key == 'recite' ? scheme.primary : null,
                    onPressed: m.onPressed,
                    onLongPress: m.settings,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    // The layout changes at once — so the reveal buttons have their room
    // (and full size) from the start; the new group fades and grows in.
    return FadeScaleIn(key: ValueKey(collapsed), child: child);
  }
}

/// A running mode's slim ⋮ (its settings), in the session's group.
/// (The modes' arrow as in the idle bar: its size, the green.)
final _runningSettingsStyle = BarButtonGroup.buttonStyle.copyWith(
  fixedSize: const WidgetStatePropertyAll(Size(32, BarButtonGroup.height)),
  minimumSize: const WidgetStatePropertyAll(Size(32, BarButtonGroup.height)),
  iconSize: const WidgetStatePropertyAll(_arrowBox),
);

/// A mode's button with its [settings] button (a slim ⋮) right after it,
/// one item of the group (no divider between them).
Widget _withSettings({
  required bool expand,
  required Widget button,
  required Widget? settings,
  bool compact = false,
}) {
  if (settings == null) return button;
  if (!expand) {
    return Row(mainAxisSize: MainAxisSize.min, children: [button, settings]);
  }
  // The mode's share in thirds: the mode in the first two (its icon
  // centred a third in), its arrow in the last, as far from the next
  // divider as the icon is from the one before — the two evenly spaced.
  return LayoutBuilder(
    builder: (context, box) {
      final zone = box.maxWidth / 3;
      final inset = (box.maxWidth - zone) / 2 - _modeIconSize / 2;
      return Row(
        children: [
          SizedBox(width: box.maxWidth - zone, child: button),
          SizedBox(
            width: zone,
            child: _ArrowInset(
              inset: inset.clamp(0, zone - _arrowGlyph),
              child: settings,
            ),
          ),
        ],
      );
    },
  );
}

/// A mode's settings in the bar: a chevron up at its end, by the divider
/// (a tap on the mode starts it as last set).
class _ModeSettingsButton extends StatelessWidget {
  const _ModeSettingsButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final String tooltip;
  final VoidCallback onPressed;

  /// Narrower on a small phone: the modes' labels the room.
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      customBorder: const StadiumBorder(),
      child: SizedBox(
        width: _ArrowInset.of(context) == null ? 16 : double.infinity,
        height: BarButtonGroup.labelledHeight,
        // The arrow: centred, or its triangle [_ArrowInset] from the
        // share's end (the icon's box wider than the triangle in it).
        child: Align(
          alignment: _ArrowInset.of(context) == null
              ? Alignment.center
              : AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: math.max(
                0,
                (_ArrowInset.of(context) ?? 0) - (_arrowBox - _arrowGlyph) / 2,
              ),
            ),
            child: Icon(
              Icons.arrow_drop_up_rounded,
              size: _arrowBox,
              // Recite's green: something more here (its settings), the
              // modes themselves left plain beside Recite.
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The modes' icon size (their place in their share).
const _modeIconSize = 20.0;

/// How far the arrow's chevron stands from its share's end (the divider).
class _ArrowInset extends InheritedWidget {
  const _ArrowInset({required this.inset, required super.child});

  final double inset;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ArrowInset>()?.inset;

  @override
  bool updateShouldNotify(_ArrowInset old) => old.inset != inset;
}

/// The modes' arrow (Material's "arrow drop up"): its icon's size, and the
/// width of the triangle drawn in it.
const _arrowBox = 26.0;
const _arrowGlyph = 12.0;

/// Fades and scales [child] in when first shown (a new key shows it anew).
class FadeScaleIn extends StatelessWidget {
  const FadeScaleIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: TahfeezMotionDuration.medium,
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
    ),
    child: child,
  );
}

/// A mode in the idle bar's group: its icon, its short name below.
class _LabelledModeButton extends StatelessWidget {
  const _LabelledModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    this.color,
  });

  final IconData icon;
  final String label, tooltip;
  final VoidCallback? onPressed;

  /// Also on a right-click (a browser's long press).
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;
    final ink = enabled
        ? color ?? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: BarButtonGroup.labelledHeight,
          ),
          child: Padding(
            // (Close to the dividers: the labels the room.)
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: ink),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ink,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionControls extends ConsumerWidget {
  const _SessionControls({super.key, required this.state});

  final RecitationSessionState state;

  /// The reveal/hide buttons' own width (four buttons, the dividers, the
  /// group's padding and the gap before the eye).
  static const _stepsWidth = 4 * 42.0 + 3 + 4 + 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(recitationSessionControllerProvider.notifier);
    final canControl =
        state.phase == RecitationPhase.listening ||
        state.phase == RecitationPhase.paused;
    // Follow along, strict: a turn with mistakes, its marks in view — try
    // again or skip on (the hint above says so).
    // …or a strict loop's pass, the same way.
    final follow = ref.watch(followAlongControllerProvider);
    final loopReview = ref.watch(
      hifzControllerProvider.select((h) => h.loopReview),
    );
    final looping = ref.watch(
      hifzControllerProvider.select((h) => h.loop != null),
    );
    if (follow?.phase == FollowAlongPhase.review || loopReview) {
      final run = ref.read(followAlongControllerProvider.notifier);
      final hifz = ref.read(hifzControllerProvider.notifier);
      final inFollow = follow?.phase == FollowAlongPhase.review;
      return Row(
        key: const ValueKey('follow-review'),
        children: [
          BarButtonGroup(
            children: [
              GuideTarget(
                id: 'session-stop',
                child: IconButton(
                  style: BarButtonGroup.buttonStyle,
                  color: scheme.error,
                  icon: const Icon(Icons.stop_rounded),
                  tooltip: l10n.recStop,
                  onPressed: () => inFollow
                      ? unawaited(run.stop())
                      : unawaited(
                          ref
                              .read(
                                recitationSessionControllerProvider.notifier,
                              )
                              .stop(),
                        ),
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            key: const ValueKey('follow-skip'),
            onPressed: () => inFollow ? unawaited(run.skip()) : hifz.loopSkip(),
            child: Tooltip(
              message: l10n.recSkipTip,
              child: Text(l10n.followSkip),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            key: const ValueKey('follow-try-again'),
            onPressed: () =>
                inFollow ? unawaited(run.tryAgain()) : hifz.loopTryAgain(),
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: Tooltip(
              message: l10n.recTryAgainTip,
              child: Text(l10n.followTryAgain),
            ),
          ),
          const SizedBox(width: 8),
          const MushafHideControls(part: MushafHideControlsPart.pinned),
        ],
      );
    }
    // Laid out like the bar before a session: stop and pause where the mic
    // was, the reveal/hide buttons and the eye at the end — so they never
    // move, recording or not.
    final controls = BarButtonGroup(
      children: [
        GuideTarget(
          id: 'session-stop',
          // A ring that swells with the voice the microphone hears.
          child: MicLevelRing(
            active: state.phase == RecitationPhase.listening,
            child: IconButton(
              style: BarButtonGroup.buttonStyle,
              color: scheme.error,
              icon: const Icon(Icons.stop_rounded),
              tooltip: l10n.recStop,
              onPressed: canControl ? controller.stop : null,
            ),
          ),
        ),
        if (state.phase == RecitationPhase.paused)
          IconButton(
            style: BarButtonGroup.buttonStyle,
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: l10n.recResume,
            onPressed: controller.resume,
          )
        else
          IconButton(
            style: BarButtonGroup.buttonStyle,
            icon: const Icon(Icons.pause_rounded),
            tooltip: l10n.recPause,
            onPressed: canControl ? controller.pause : null,
          ),
        // A loop's or Follow along's settings, to change as it runs
        // (started again so).
        if (follow != null || looping)
          IconButton(
            key: const ValueKey('session-settings'),
            style: _runningSettingsStyle,
            icon: Icon(
              Icons.arrow_drop_up_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: l10n.recModeSettings(
              follow != null ? l10n.followTitle : l10n.recLoop,
            ),
            onPressed: () => follow != null
                ? showFollowAlongSheet(context)
                : showRecitationLoopSheet(context),
          ),
      ],
    );
    // In a wide browser window showing two pages: stop and pause under the
    // left page, the reveal buttons over the right one's width.
    return _UnderPages(
      wide: wideWebBarWidth(context, ref) != null,
      left: Align(alignment: AlignmentDirectional.centerStart, child: controls),
      right: const _RevealUnderPage(hidden: true, short: true),
      otherwise: Row(
        children: [
          controls,
          // The reveal/hide buttons (to help the test along, or go back);
          // the eye keeps its size and place.
          // On a phone they fill the rest of the row as before a session
          // (the same gaps), only as tall as stop and pause.
          // On the narrowest phones, where they don't fit at their width,
          // they scale down instead.
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= _stepsWidth
                  ? const MushafHideControls(
                      part: MushafHideControlsPart.steps,
                      expand: true,
                      short: true,
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: MushafHideControls(
                        part: MushafHideControlsPart.steps,
                      ),
                    ),
            ),
          ),
          const MushafHideControls(part: MushafHideControlsPart.pinned),
        ],
      ),
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
    // Follow along's reciter turns: no sleep timer (it is for listening).
    final following = ref.watch(followAlongControllerProvider) != null;
    return StreamBuilder<AudioPlaybackState>(
      stream: audio.state,
      initialData: const AudioPlaybackState(isPlaying: true),
      builder: (context, snapshot) {
        final playback = snapshot.data ?? const AudioPlaybackState();
        final speed = playback.speed;
        final controls = GuideTarget(
          id: 'listen-controls',
          child: BarButtonGroup(
            children: [
              IconButton(
                key: const ValueKey('listen-stop'),
                style: BarButtonGroup.buttonStyle,
                color: scheme.error,
                icon: const Icon(Icons.stop_rounded),
                tooltip: l10n.listenStop,
                onPressed: player.stop,
              ),
              if (playback.isPlaying)
                IconButton(
                  key: const ValueKey('listen-pause'),
                  style: BarButtonGroup.buttonStyle,
                  icon: const Icon(Icons.pause_rounded),
                  tooltip: l10n.recPause,
                  onPressed: player.pause,
                )
              else
                IconButton(
                  key: const ValueKey('listen-resume'),
                  style: BarButtonGroup.buttonStyle,
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: l10n.recResume,
                  onPressed: player.resume,
                ),
              TextButton(
                key: const ValueKey('listen-speed'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(46, BarButtonGroup.height),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => player.cycleSpeed(speed),
                child: Text(
                  '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                  semanticsLabel: '${l10n.listenSpeed} $speed',
                ),
              ),
              if (!following)
                SleepTimerButton(style: BarButtonGroup.buttonStyle),
              // Its settings, to change as it plays (started again so).
              IconButton(
                key: const ValueKey('listen-settings'),
                style: _runningSettingsStyle,
                icon: Icon(
                  Icons.arrow_drop_up_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: l10n.recModeSettings(
                  following ? l10n.followTitle : l10n.listenMenuTitle,
                ),
                onPressed: () => following
                    ? showFollowAlongSheet(context)
                    : showListenSheet(context),
              ),
            ],
          ),
        );
        // In a wide browser window showing two pages: the controls under
        // the left page, the eye at the right one's end.
        return _UnderPages(
          wide: wideWebBarWidth(context, ref) != null,
          left: Align(
            alignment: AlignmentDirectional.centerStart,
            child: controls,
          ),
          right: const _RevealUnderPage(hidden: false),
          otherwise: Row(
            children: [
              controls,
              // Revealing follows the recitation: only the eye stays.
              const Spacer(),
              const MushafHideControls(part: MushafHideControlsPart.pinned),
            ],
          ),
        );
      },
    );
  }
}

/// [child] (the stop button) inside a soft ring that swells and fades
/// with how loudly the microphone hears the reciter ([micLevelProvider]) —
/// that it is listening, live. Only the ring repaints, at the audio's pace.
class MicLevelRing extends ConsumerWidget {
  const MicLevelRing({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!active) return child;
    final level = ref.watch(micLevelProvider);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('mic-level-ring'),
                painter: _MicLevelPainter(
                  level,
                  Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MicLevelPainter extends CustomPainter {
  _MicLevelPainter(this.level, this.color) : super(repaint: level);

  final ValueListenable<double> level;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final v = level.value;
    if (v <= 0.02) return;
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2 - 6;
    canvas.drawCircle(
      center,
      base + 4 * v,
      Paint()..color = color.withValues(alpha: 0.10 + 0.14 * v),
    );
    canvas.drawCircle(
      center,
      base + 4 * v,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.25 + 0.45 * v),
    );
  }

  @override
  bool shouldRepaint(_MicLevelPainter old) =>
      old.level != level || old.color != color;
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
    return GuideTarget(
      id: 'hifz-settings',
      child: IconButton(
        key: const ValueKey('hifz-settings'),
        icon: const Icon(Icons.settings_outlined),
        tooltip: AppLocalizations.of(context).recHifzSettings,
        onPressed: () => showHifzSettingsSheet(context),
      ),
    );
  }
}

/// Memorization hide mode for the open Mushaf: an eye toggle that hides
/// every word (ayah markers and numbers stay), and — while hiding —
/// buttons that uncover the next ayah or the next single word, in reading
/// order from the first word on the page.
class MushafHideControls extends ConsumerWidget {
  const MushafHideControls({
    super.key,
    this.part = MushafHideControlsPart.all,
    this.expand = false,
    this.short = false,
  });

  /// The reveal/hide buttons stretched over the width they are given, as
  /// tall as the bar's labelled modes (the phone's bar in hide mode).
  final bool expand;

  /// Stretched ([expand]) but only as tall as the bar's other groups: beside
  /// stop and pause while reciting.
  final bool short;

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
    final onScreen = firstVisiblePage(location.pageNumber, spread: spread);
    // Ayah mode's continuous list, scrolled on past the page being
    // uncovered: the buttons go on there (brought back into view), not on
    // the page scrolled to.
    final continuous = ayahModeIsContinuous(context, ref);
    final underWay = continuous ? hide.revealUnderWay : null;
    final page = underWay ?? onScreen;
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

    const gap = SizedBox(width: MushafHideControls._hideControlsGap);
    Widget step(String key, IconData icon, String tip, VoidCallback? onTap) =>
        GuideTarget(
          id: key,
          child: IconButton(
            key: ValueKey(key),
            style: expand
                ? BarButtonGroup.buttonStyle.copyWith(
                    fixedSize: WidgetStatePropertyAll(
                      Size(
                        double.infinity,
                        short
                            ? BarButtonGroup.height
                            : BarButtonGroup.labelledHeight,
                      ),
                    ),
                    iconSize: WidgetStatePropertyAll(short ? 20 : 24),
                  )
                : BarButtonGroup.buttonStyle,
            icon: Icon(icon),
            tooltip: tip,
            onPressed: onTap,
          ),
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
    // On the page under way but scrolled away from: back to it first (built
    // and in view), then the step — its scroll follows the words.
    VoidCallback? backThere(VoidCallback? step) {
      if (step == null || page == onScreen) return step;
      return () {
        turns.toPage(page);
        Future<void>.delayed(const Duration(milliseconds: 350), step);
      };
    }

    final onRevealAyah = testing
        ? (hifz.completed
              ? null
              : () => hifzController!.revealNext(wholeAyah: true))
        : backThere(
            revealOrTurn(() => notifier.revealNextAyah(page, spread: spread)),
          );
    final onRevealWord = testing
        ? (hifz.completed ? null : () => hifzController!.revealNext())
        : backThere(
            revealOrTurn(() => notifier.revealNextWord(page, spread: spread)),
          );
    final onHideWord = testing
        ? (testCanHide ? () => hifzController!.hideBack() : null)
        : backThere(
            hideOrTurnBack(() => notifier.hideLastWord(page, spread: spread)),
          );
    final onHideAyah = testing
        ? (testCanHide ? () => hifzController!.hideBack(wholeAyah: true) : null)
        : backThere(
            hideOrTurnBack(() => notifier.hideLastAyah(page, spread: spread)),
          );

    // The eye's three states (owner, 2026-11-07): recitation colours shown
    // (the green eye, the default) → none drawn, reciting without them
    // (the plain eye) → ayahs hidden (their colours shown as uncovered) →
    // the colours shown again.
    final colours = ref.watch(mushafColoursShownProvider);
    final setColours = ref.read(mushafColoursShownProvider.notifier).set;
    final l10n = AppLocalizations.of(context);
    // Forward on the left, backward on the right — reading runs right to
    // left, so "next" points left — and the eye at the end: turning hide
    // mode on or off adds the reveal/hide buttons on the far side, never
    // moving the eye.
    final eye = GuideTarget(
      id: 'eye',
      child: IconButton(
        key: const ValueKey('mushaf-hide-toggle'),
        // 48 × 48 to tap, as every button on the bar.
        isSelected: hide.enabled,
        // (The Recite button's green.)
        icon: colours
            ? Icon(
                Icons.visibility_outlined,
                key: const ValueKey('mushaf-eye-coloured'),
                color: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.visibility_outlined),
        selectedIcon: const Icon(Icons.visibility_off_outlined),
        tooltip: hide.enabled
            ? l10n.recShowAyahs
            : colours
            ? l10n.recHideColours
            : l10n.recHideAyahs,
        style: hide.enabled
            ? IconButton.styleFrom(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
              )
            : null,
        onPressed: () {
          // (The guide's hide tour: straight to the ayahs hidden.)
          final guided = ref.read(guideProvider) != null;
          final notice = ref.read(coloursOffNoticeProvider.notifier);
          if (hide.enabled || guided) {
            if (!guided) {
              notice.show(hide.enabled ? EyeNotice.colours : EyeNotice.hidden);
            }
            notifier.toggle();
          } else if (colours) {
            setColours(false);
            notice.show();
            return;
          } else {
            notice.show(EyeNotice.hidden);
            notifier.toggle();
          }
          // Ayahs hidden or shown again: in colour.
          setColours(true);
        },
      ),
    );
    final steps = part == MushafHideControlsPart.pinned
        ? const <Widget>[]
        : [
            if (hide.enabled) ...[
              _expandedIf(
                expand,
                FadeScaleIn(
                  // In this order in every language (Arabic's mirrored bar
                  // too): the Mushaf reads right to left, so next is left.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: BarButtonGroup(
                      expand: expand,
                      groupHeight: expand && !short
                          ? BarButtonGroup.labelledHeight
                          : BarButtonGroup.height,
                      children: [
                        step(
                          'mushaf-reveal-ayah',
                          Icons.first_page_rounded,
                          AppLocalizations.of(context).recRevealAyah,
                          onRevealAyah,
                        ),
                        step(
                          'mushaf-reveal-word',
                          Icons.keyboard_double_arrow_left_rounded,
                          AppLocalizations.of(context).recRevealWord,
                          onRevealWord,
                        ),
                        step(
                          'mushaf-hide-word',
                          Icons.keyboard_double_arrow_right_rounded,
                          AppLocalizations.of(context).recHideWord,
                          onHideWord,
                        ),
                        step(
                          'mushaf-hide-ayah',
                          Icons.last_page_rounded,
                          AppLocalizations.of(context).recHideAyah,
                          onHideAyah,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              gap,
            ],
          ];
    final pinned = part == MushafHideControlsPart.steps
        ? const <Widget>[]
        : [eye];
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [...steps, ...pinned],
    );
  }

  static Widget _expandedIf(bool expand, Widget child) =>
      expand ? Expanded(child: child) : child;
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
  const HifzStatusStrip({
    super.key,
    required this.state,
    this.acoustic,
    this.settings = const HifzSettings(),
  });

  final HifzState state;
  final AcousticVerificationState? acoustic;

  /// The mistake colours chosen (Hifz settings).
  final HifzSettings settings;

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
    if (e.type == RecitationErrorType.ghunnahMissing) {
      return l10n.recGhunnah(expected);
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
          // As the word's own mark, in the colours chosen.
          Color(
            acoustic!.lastMistake!.isTajweed
                ? settings.tajweedColor
                : settings.pronunciationColor,
          ),
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
/// How the recitation check works, for [mode]: each time in the guide,
/// whose last step it is for that mode; outside it, once only — before the
/// first recitation of any of the three modes (the guide's showings aside).
/// What to do, what the colours mean, that the check is still learning,
/// and that the voice stays on the phone. Hifz settings open over it.
/// True: start; false: closed (in the guide, back to the step asking for
/// the button).
Future<bool> showRecitationIntro(
  BuildContext context,
  RecitationIntroMode mode,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final guided = container.read(guideProvider) != null;
  // Seen outside the guide, for any mode: not again (but in the guide).
  if (!guided && container.read(hifzSettingsProvider).introsSeen.isNotEmpty) {
    return true;
  }
  final start = await showModalBottomSheet<bool>(
    context: context,
    // (Its drag handle on the glass: GlassSheet.)
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: sheetBelowAppBar(context),
    builder: (context) =>
        GlassSheet(handle: true, child: _RecitationIntroSheet(mode)),
  );
  // (The guide's showings don't count: a reader who skipped the guide
  // still gets it once.)
  if (!guided) {
    final settings = container.read(hifzSettingsProvider);
    container
        .read(hifzSettingsProvider.notifier)
        .update(settings.copyWith(introsSeen: {...settings.introsSeen, mode}));
  }
  if (start != true && guided) {
    container.read(guideProvider.notifier).notStarted();
  }
  return start == true;
}

class _RecitationIntroSheet extends ConsumerWidget {
  const _RecitationIntroSheet(this.mode);

  final RecitationIntroMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(hifzSettingsProvider);
    Widget point(Widget leading, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: leading),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
    // The colours, one per row: each dot under the icons, its meaning in
    // line with the text.
    Widget colour(int argb, String meaning) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: CircleAvatar(radius: 7, backgroundColor: Color(argb)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(meaning, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
    final scheme = theme.colorScheme;
    // As the Loop and Follow along sheets: a titled column that scrolls,
    // inside the safe area (clear of the system navigation bar), the
    // buttons side by side at its end.
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('recitation-intro'),
        padding: const EdgeInsets.fromLTRB(
          TahfeezSpacing.md,
          0,
          TahfeezSpacing.md,
          TahfeezSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  switch (mode) {
                    RecitationIntroMode.recite => Icons.mic_rounded,
                    RecitationIntroMode.loop => Icons.repeat_rounded,
                    RecitationIntroMode.follow =>
                      Icons.record_voice_over_outlined,
                  },
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: TahfeezSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.recIntroTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SheetCloseButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: TahfeezSpacing.sm),
            // What to do, in this mode.
            ...switch (mode) {
              RecitationIntroMode.recite => [
                point(const Icon(Icons.mic_rounded), l10n.recIntroListen),
                point(
                  const Icon(Icons.stop_circle_outlined),
                  l10n.recIntroStop,
                ),
              ],
              RecitationIntroMode.loop => [
                point(const Icon(Icons.repeat_rounded), l10n.guideLoopRecite),
              ],
              RecitationIntroMode.follow => [
                point(
                  const Icon(Icons.record_voice_over_outlined),
                  l10n.guideFollowPractice,
                ),
              ],
            },
            point(const Icon(Icons.palette_outlined), l10n.recIntroColours),
            Padding(
              key: const ValueKey('recitation-intro-colours'),
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  colour(0xFF43A047, l10n.recLegendCorrect),
                  colour(0xFFE0A800, l10n.recLegendSkipped),
                  colour(0xFFD32F2F, l10n.recLegendWrong),
                  colour(
                    settings.pronunciationColor,
                    l10n.recLegendPronunciation,
                  ),
                  colour(settings.tajweedColor, l10n.recLegendTajweed),
                ],
              ),
            ),
            point(const Icon(Icons.school_outlined), l10n.recIntroLearning),
            point(const Icon(Icons.lock_outline), l10n.recIntroPrivate),
            // Before the system's own question: why it will ask.
            point(const Icon(Icons.mic_none_rounded), l10n.recIntroMicAsk),
            const SizedBox(height: TahfeezSpacing.md),
            Row(
              children: [
                // Over this sheet, back to it when closed.
                TextButton(
                  key: const ValueKey('recitation-intro-settings'),
                  onPressed: () => showHifzSettingsSheet(context),
                  child: Text(l10n.recIntroSettings),
                ),
                const SizedBox(width: TahfeezSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('recitation-intro-start'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(l10n.recIntroStart),
                    onPressed: () => Navigator.of(context).pop(true),
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

Future<void> showHifzSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // (Its drag handle on the glass: GlassSheet.)
    // As tall as its settings (not capped at half the screen), below the
    // app bar.
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: sheetBelowAppBar(context),
    builder: (context) => GlassSheet(
      handle: true,
      closable: true,
      child: const _HifzSettingsSheet(),
    ),
  );
}

/// The Hifz settings in two tabs, so neither is a long scroll: the
/// recitation's checking and feedback, and the Mushaf's appearance.
class _HifzSettingsSheet extends ConsumerStatefulWidget {
  const _HifzSettingsSheet();

  @override
  ConsumerState<_HifzSettingsSheet> createState() => _HifzSettingsSheetState();
}

class _HifzSettingsSheetState extends ConsumerState<_HifzSettingsSheet>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // (Its ✕ on the drag handle's line: the tabs the full width, no
          // row of its own.)
          TabBar(
            key: const ValueKey('hifz-settings-tabs'),
            controller: _tabs,
            tabs: [
              Tab(text: l10n.settingsRecitation),
              Tab(text: l10n.hifzTabAppearance),
            ],
          ),
          // Both tabs laid out, one shown: the sheet keeps the taller one's
          // height whichever is open.
          // Each tab its own scroll (one scrolled down leaves the other at
          // its top).
          Flexible(
            child: IndexedStack(
              index: _tabs.index,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8),
                  child: _recitationSettings(context),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: MushafAppearanceOptions(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recitationSettings(BuildContext context) {
    final settings = ref.watch(hifzSettingsProvider);
    final controller = ref.read(hifzSettingsProvider.notifier);
    final capabilities = ref.watch(platformCapabilitiesProvider);
    // The mistake alert's vibration and beep: Android and iOS; the web's
    // beep.
    final alerts =
        capabilities.isAndroid || capabilities.isIOS || capabilities.isWeb;
    // A browser: no vibration choice (the sound only).
    final web = capabilities.isWeb;
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

    final l10n = AppLocalizations.of(context);
    // Advanced chosen, or settings no level gives (chosen one by one).
    final level = settings.advanced ? null : settings.level;
    Widget choice(
      String key,
      String title,
      String subtitle,
      bool selected,
      VoidCallback onTap,
    ) => ListTile(
      key: ValueKey(key),
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
    Widget section(String key, String title, IconData icon, List<Widget> c) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TahfeezCollapsibleSection(
            key: ValueKey(key),
            title: title,
            icon: icon,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: c,
            ),
          ),
        );

    // A level (owner, 2026-11-07) — or Advanced: every setting, in
    // collapsed groups.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (l, title, subtitle) in [
          (HifzLevel.gentle, l10n.hifzLevelGentle, l10n.hifzLevelGentleSub),
          (
            HifzLevel.balanced,
            l10n.hifzLevelBalanced,
            l10n.hifzLevelBalancedSub,
          ),
          (HifzLevel.strict, l10n.hifzLevelStrict, l10n.hifzLevelStrictSub),
        ])
          choice(
            'hifz-level-${l.name}',
            title,
            subtitle,
            level == l,
            () => controller.update(settings.atLevel(l)),
          ),
        choice(
          'hifz-level-advanced',
          l10n.hifzLevelAdvanced,
          l10n.hifzLevelAdvancedSub,
          level == null,
          () => controller.update(settings.copyWith(advanced: true)),
        ),
        if (level == null) ...[
          const Divider(),
          section(
            'hifz-group-checking',
            l10n.hifzGroupChecking,
            Icons.fact_check_outlined,
            [
              toggle(
                AppLocalizations.of(context).recStrict,
                AppLocalizations.of(context).recStrictSub,
                settings.strict,
                (v) => settings.copyWith(strict: v),
              ),
              ListTile(
                key: const ValueKey('hifz-strictness'),
                title: Text(AppLocalizations.of(context).recStrictness),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context).recStrictnessSub),
                    const SizedBox(height: 8),
                    // One shift for every threshold, tajweed's too.
                    SegmentedButton<RecitationStrictness>(
                      segments: [
                        ButtonSegment(
                          value: RecitationStrictness.lenient,
                          label: Text(
                            AppLocalizations.of(context).recStrictnessLenient,
                          ),
                        ),
                        ButtonSegment(
                          value: RecitationStrictness.balanced,
                          label: Text(
                            AppLocalizations.of(context).recStrictnessBalanced,
                          ),
                        ),
                        ButtonSegment(
                          value: RecitationStrictness.strict,
                          label: Text(
                            AppLocalizations.of(context).recStrictnessStrict,
                          ),
                        ),
                      ],
                      selected: {settings.strictness},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => controller.update(
                        settings.copyWith(strictness: s.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // A legend: each level on its line, the chosen one in full.
                    for (final (level, name, meaning) in [
                      (
                        RecitationStrictness.lenient,
                        AppLocalizations.of(context).recStrictnessLenient,
                        AppLocalizations.of(context).recStrictnessLenientSub,
                      ),
                      (
                        RecitationStrictness.balanced,
                        AppLocalizations.of(context).recStrictnessBalanced,
                        AppLocalizations.of(context).recStrictnessBalancedSub,
                      ),
                      (
                        RecitationStrictness.strict,
                        AppLocalizations.of(context).recStrictnessStrict,
                        AppLocalizations.of(context).recStrictnessStrictSub,
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Opacity(
                          opacity: level == settings.strictness ? 1 : 0.65,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$name: ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: meaning),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              toggle(
                AppLocalizations.of(context).recTajweed,
                AppLocalizations.of(context).recTajweedSub,
                settings.tajweed,
                (v) => settings.copyWith(tajweed: v),
              ),
              // Each rule on or off, under tajweed.
              if (settings.tajweed) ...[
                for (final (rule, name) in [
                  (TajweedRule.ikhfa, AppLocalizations.of(context).ruleIkhfa),
                  (TajweedRule.iqlab, AppLocalizations.of(context).ruleIqlab),
                  (
                    TajweedRule.ikhfaShafawi,
                    AppLocalizations.of(context).ruleIkhfaShafawi,
                  ),
                  (TajweedRule.idgham, AppLocalizations.of(context).ruleIdgham),
                  (
                    TajweedRule.idghamMim,
                    AppLocalizations.of(context).ruleIdghamMim,
                  ),
                  (
                    TajweedRule.qalqala,
                    AppLocalizations.of(context).ruleQalqala,
                  ),
                  (TajweedRule.madd, AppLocalizations.of(context).ruleMadd),
                  (
                    TajweedRule.ghunnah,
                    AppLocalizations.of(context).ruleGhunnah,
                  ),
                ])
                  CheckboxListTile(
                    key: ValueKey('tajweed-rule-${rule.name}'),
                    dense: true,
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 32,
                      end: 16,
                    ),
                    title: Text(name),
                    value: settings.tajweedRules.contains(rule),
                    onChanged: (v) => controller.update(
                      settings.copyWith(
                        tajweedRules: v == true
                            ? {...settings.tajweedRules, rule}
                            : ({...settings.tajweedRules}..remove(rule)),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          section(
            'hifz-group-marks',
            l10n.hifzGroupMarks,
            Icons.format_color_fill_outlined,
            [
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
              if (settings.colorWords)
                _ColourChoice(
                  key: const ValueKey('hifz-pronunciation-colour'),
                  title: AppLocalizations.of(context).recPronunciationColour,
                  colours: HifzSettings.pronunciationColors,
                  selected: settings.pronunciationColor,
                  onSelected: (c) => controller.update(
                    settings.copyWith(pronunciationColor: c),
                  ),
                ),
              // (Tajweed's, while tajweed is judged.)
              if (settings.colorWords && settings.tajweed)
                _ColourChoice(
                  key: const ValueKey('hifz-tajweed-colour'),
                  title: AppLocalizations.of(context).recTajweedColour,
                  colours: HifzSettings.tajweedColors,
                  selected: settings.tajweedColor,
                  onSelected: (c) =>
                      controller.update(settings.copyWith(tajweedColor: c)),
                )
              else if (settings.colorWords)
                // Where its colour is chosen, while tajweed is not judged:
                // said, with the way to turn it on (it once just vanished).
                Row(
                  key: const ValueKey('hifz-tajweed-colour-off'),
                  spacing: TahfeezSpacing.sm,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        l10n.recTajweedColourOff,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          controller.update(settings.copyWith(tajweed: true)),
                      child: Text(l10n.recTurnOn),
                    ),
                  ],
                ),
              toggle(
                AppLocalizations.of(context).recShowMistakes,
                AppLocalizations.of(context).recShowMistakesSub,
                settings.showMistakes,
                (v) => settings.copyWith(showMistakes: v),
              ),
            ],
          ),
          if (alerts)
            section(
              'hifz-group-alerts',
              l10n.hifzGroupAlerts,
              Icons.notifications_active_outlined,
              [
                if (alerts)
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
                          // (A browser: the sound alone.)
                          if (!web)
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
                            label: Text(
                              AppLocalizations.of(context).recAlertSound,
                            ),
                          ),
                        ],
                        selected: {
                          if (!web && settings.alert.vibrates)
                            MistakeAlert.vibrate,
                          if (settings.alert.beeps) MistakeAlert.sound,
                        },
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => controller.update(
                          settings.copyWith(
                            alert: MistakeAlert.of(
                              vibrate: web
                                  ? settings.alert.vibrates
                                  : s.contains(MistakeAlert.vibrate),
                              sound: s.contains(MistakeAlert.sound),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Tajweed mistakes (purple) alert apart, as chosen here.
                if (alerts && settings.tajweed)
                  ListTile(
                    key: const ValueKey('hifz-tajweed-alert'),
                    title: Text(AppLocalizations.of(context).recTajweedAlert),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SegmentedButton<MistakeAlert>(
                        multiSelectionEnabled: true,
                        emptySelectionAllowed: true,
                        segments: [
                          // (A browser: the sound alone.)
                          if (!web)
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
                            label: Text(
                              AppLocalizations.of(context).recAlertSound,
                            ),
                          ),
                        ],
                        selected: {
                          if (!web && settings.tajweedAlert.vibrates)
                            MistakeAlert.vibrate,
                          if (settings.tajweedAlert.beeps) MistakeAlert.sound,
                        },
                        showSelectedIcon: false,
                        onSelectionChanged: (s) => controller.update(
                          settings.copyWith(
                            tajweedAlert: MistakeAlert.of(
                              vibrate: web
                                  ? settings.tajweedAlert.vibrates
                                  : s.contains(MistakeAlert.vibrate),
                              sound: s.contains(MistakeAlert.sound),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          section(
            'hifz-group-other',
            l10n.hifzGroupOther,
            Icons.more_horiz_rounded,
            [
              toggle(
                AppLocalizations.of(context).sajdahReminder,
                AppLocalizations.of(context).sajdahReminderSub,
                settings.sajdahReminder,
                (v) => settings.copyWith(sajdahReminder: v),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Development-only live recognition diagnostics: engine status, the
/// latest partial and final transcripts, measured latency, and — with
/// [match] — the matched Quran position.
/// Says plainly when recitation can't be followed on this device: the
/// on-device model is missing or unusable, or offline mode refused part of
/// the configuration.
/// A mistake colour, picked from a row of swatches (the chosen one ringed
/// and ticked).
class _ColourChoice extends StatelessWidget {
  const _ColourChoice({
    super.key,
    required this.title,
    required this.colours,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<int> colours;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final (i, c) in colours.indexed)
              Semantics(
                selected: c == selected,
                button: true,
                child: InkWell(
                  key: ValueKey('${(key as ValueKey<String>?)?.value}-$i'),
                  customBorder: const CircleBorder(),
                  onTap: () => onSelected(c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == selected
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                        width: c == selected ? 3 : 1,
                      ),
                    ),
                    child: c == selected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecitationAiNotice extends ConsumerWidget {
  const _RecitationAiNotice({required this.config, this.inference});

  final RecitationAiConfig config;
  final LocalAcousticInferenceState? inference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = inference?.model;
    final l10n = AppLocalizations.of(context);
    // The model closed the app last time (the crash guard): said plainly,
    // with a way to try again and the details to send.
    final crashed = model?.state == LocalAcousticModelState.crashed;
    final message = crashed
        ? l10n.recModelCrashed
        : config.violation ??
              inference?.error ??
              (model?.state == LocalAcousticModelState.unsupported
                  // A 32-bit phone: the model needs 64 (memory and speed);
                  // an old browser: WebAssembly SIMD.
                  ? (ref.watch(platformCapabilitiesProvider).isWeb
                        ? l10n.recWebUnsupported
                        : l10n.recNeeds64Bit)
                  : model != null && !model.usable
                  ? '$model'
                  : null);
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 12, color: scheme.onErrorContainer);
    return Container(
      key: const ValueKey('recitation-ai-notice'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            maxLines: crashed ? 4 : 3,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          // The web's download failed (offline?): try again.
          if (!crashed &&
              inference?.error != null &&
              ref.watch(platformCapabilitiesProvider).isWeb)
            TextButton(
              key: const ValueKey('recitation-ai-retry-download'),
              onPressed: () => ref
                  .read(localAcousticInferenceControllerProvider.notifier)
                  .retryAfterCrash(),
              child: Text(l10n.quranSetupRetry),
            ),
          if (crashed)
            Wrap(
              spacing: TahfeezSpacing.xs,
              children: [
                TextButton(
                  key: const ValueKey('recitation-ai-retry'),
                  onPressed: () => ref
                      .read(localAcousticInferenceControllerProvider.notifier)
                      .retryAfterCrash(),
                  child: Text(l10n.quranSetupRetry),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(appStoreServiceProvider)
                      .share(
                        'Tahfeez AI ${ref.read(appVersionProvider).value ?? '?'}'
                        ' — recitation checking closed the app\n'
                        '${model?.detail ?? ''}',
                        origin: shareOrigin(context),
                      ),
                  child: Text(l10n.quranSetupShare),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The web's first download of the acoustic model (the phones have it in
/// the app): how far it has come. Kept afterwards — once only.
class _ModelDownload extends StatelessWidget {
  const _ModelDownload();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double?>(
    valueListenable: acousticModelDownload,
    builder: (context, progress, _) {
      if (progress == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      return Padding(
        key: const ValueKey('recitation-model-download'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(
              AppLocalizations.of(context)
                  .recModelDownloading((progress * 100).round()),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(TahfeezRadii.pill),
            ),
          ],
        ),
      );
    },
  );
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
