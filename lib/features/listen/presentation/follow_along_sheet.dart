import '../../guide/guide.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/live_recognition_controller.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper, VersePicker;
import '../application/follow_along_controller.dart';
import '../../recitation/application/hifz_controller.dart';
import '../application/listen_options.dart';
import '../application/quran_audio_player.dart';
import '../application/reciter_controller.dart';
import '../domain/quran_audio_sources.dart';
import '../../recitation/presentation/recitation_controls.dart'
    show showRecitationIntro;
import 'listen_sheet.dart';

/// Follow along's menu, laid out like the Listen menu: the reciter, the
/// range (from the page on screen to its surah's end), each ayah or the
/// whole range, how many times the reciter and then the user recite it,
/// and the reciter's speed.
Future<void> showFollowAlongSheet(BuildContext context) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).followTitle,
      builder: (context) => const _FollowAlongSheet(),
    );

class _FollowAlongSheet extends ConsumerStatefulWidget {
  const _FollowAlongSheet();

  @override
  ConsumerState<_FollowAlongSheet> createState() => _FollowAlongSheetState();
}

class _FollowAlongSheetState extends ConsumerState<_FollowAlongSheet> {
  VerseRef? _from, _to;

  /// The menu's choices, each saved as soon as it changes.
  // Strict is one setting, shared with Hifz settings and Loop.
  FollowAlongOptions get _options => ref
      .read(followAlongOptionsProvider)
      .copyWith(strict: ref.read(hifzSettingsProvider).strict);
  set _options(FollowAlongOptions options) {
    ref.read(followAlongOptionsProvider.notifier).set(options);
    final settings = ref.read(hifzSettingsProvider);
    if (settings.strict != options.strict) {
      ref
          .read(hifzSettingsProvider.notifier)
          .update(settings.copyWith(strict: options.strict));
    }
  }

  static int _id(VerseRef v) => v.chapterNo * 1000 + v.verseNo;

  void _defaults() {
    if (_from != null) return;
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    final page = location is QuranLocationPage
        ? firstVisiblePage(
            location.pageNumber,
            spread: ref.read(fullBleedContentProvider),
          )
        : null;
    final first =
        ref.read(mushafPageVersesProvider)[page]?.first ??
        (chapterNo: 1, verseNo: 1);
    _from = first;
    _to = (
      chapterNo: first.chapterNo,
      verseNo: surahAyahCounts[first.chapterNo - 1],
    );
  }

  void _setFrom(VerseRef v) => setState(() {
    _from = v;
    if (_id(_to!) < _id(v)) {
      _to = (chapterNo: v.chapterNo, verseNo: surahAyahCounts[v.chapterNo - 1]);
    }
  });

  void _setTo(VerseRef v) => setState(() {
    _to = v;
    if (_id(v) < _id(_from!)) _from = (chapterNo: v.chapterNo, verseNo: 1);
  });

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // How the check works, over this sheet (the first time, and in the
    // guide): closed, back to the choices here.
    if (!await showRecitationIntro(context, RecitationIntroMode.follow) ||
        !mounted) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final started = await ref
        .read(followAlongControllerProvider.notifier)
        .start(_from!, _to!, _options);
    if (!started) showListenOffline(messenger, l10n.listenOffline);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(indexedSurahsProvider).value;
    if (surahs == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    _defaults();
    final from = _from!, to = _to!;
    final reciter = reciterFor(ref.watch(reciterProvider));
    final currentSpeed = ref.watch(listenSpeedProvider);
    final eachAyah = _options.unit == FollowAlongUnit.eachAyah;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    Widget stepper(
      String text,
      String id,
      int value,
      ValueChanged<int> set, {
      bool untilStopped = false,
    }) => Row(
      children: [
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        CountStepper(
          id: id,
          value: value,
          min: 1,
          max: FollowAlongOptions.maxTimes,
          untilStopped: untilStopped,
          onChanged: (n) => setState(() => set(n)),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Text(
            l10n.followSub,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          GuideTarget(
            id: 'follow-reciter',
            child: TahfeezCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const ValueKey('follow-reciter'),
                leading: const Icon(Icons.record_voice_over_outlined),
                title: Text(l10n.listenReciter),
                subtitle: Text(reciterName(context, reciter)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showReciterSheet(context),
              ),
            ),
          ),
          GuideTarget(
            id: 'follow-range',
            child: TahfeezCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(l10n.recFrom),
                  VersePicker(
                    id: 'follow-from',
                    surahs: surahs,
                    value: from,
                    ayahCount: surahAyahCounts[from.chapterNo - 1],
                    onSurah: (c) => _setFrom((chapterNo: c, verseNo: 1)),
                    onAyah: (v) =>
                        _setFrom((chapterNo: from.chapterNo, verseNo: v)),
                  ),
                  const SizedBox(height: TahfeezSpacing.md),
                  label(l10n.recTo),
                  VersePicker(
                    id: 'follow-to',
                    surahs: surahs,
                    value: to,
                    ayahCount: surahAyahCounts[to.chapterNo - 1],
                    onSurah: (c) =>
                        _setTo((chapterNo: c, verseNo: surahAyahCounts[c - 1])),
                    onAyah: (v) =>
                        _setTo((chapterNo: to.chapterNo, verseNo: v)),
                  ),
                ],
              ),
            ),
          ),
          GuideTarget(
            id: 'follow-unit',
            child: TahfeezCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.sm,
                children: [
                  label(l10n.recLoopOrder),
                  SegmentedButton<FollowAlongUnit>(
                    key: const ValueKey('follow-unit'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: FollowAlongUnit.eachAyah,
                        label: Text(l10n.recLoopEachAyah),
                      ),
                      ButtonSegment(
                        value: FollowAlongUnit.range,
                        label: Text(l10n.recLoopRange),
                      ),
                    ],
                    selected: {_options.unit},
                    onSelectionChanged: (s) => setState(
                      () => _options = _options.copyWith(unit: s.first),
                    ),
                  ),
                  Text(
                    eachAyah ? l10n.followEachAyahSub : l10n.followRangeSub,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  stepper(
                    l10n.followReciterTimes,
                    'follow-reciter-times',
                    _options.reciterTimes,
                    (n) => _options = _options.copyWith(reciterTimes: n),
                  ),
                  stepper(
                    l10n.followYourTimes,
                    'follow-user-times',
                    _options.userTimes,
                    (n) => _options = _options.copyWith(userTimes: n),
                  ),
                  // The whole range: round again, or until stopped.
                  if (!eachAyah)
                    stepper(
                      l10n.listenRepeatRange,
                      'follow-range-rounds',
                      _options.rangeRounds,
                      (n) => _options = _options.copyWith(rangeRounds: n),
                      untilStopped: true,
                    ),
                  GuideTarget(
                    id: 'follow-strict',
                    child: SwitchListTile(
                      key: const ValueKey('follow-strict'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.followStrict),
                      subtitle: Text(l10n.followStrictSub),
                      value: _options.strict,
                      onChanged: (on) => setState(
                        () => _options = _options.copyWith(strict: on),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          GuideTarget(
            id: 'follow-speed',
            child: TahfeezCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label(l10n.listenSpeed),
                  Wrap(
                    spacing: TahfeezSpacing.sm,
                    runSpacing: TahfeezSpacing.sm,
                    children: [
                      for (final speed in listenSpeeds)
                        ChoiceChip(
                          key: ValueKey('follow-speed-$speed'),
                          showCheckmark: false,
                          label: Text(
                            '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                          ),
                          // The speed of all listening, kept for next time.
                          selected: (currentSpeed - speed).abs() < 0.01,
                          onSelected: (_) =>
                              ref.read(listenSpeedProvider.notifier).set(speed),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GuideTarget(
            id: 'follow-start',
            child: FilledButton.icon(
              key: const ValueKey('follow-start'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.followStart),
            ),
          ),
        ],
      ),
    );
  }
}

/// While Follow along runs, on the bar's top border: a small pill saying
/// whose turn it is — the reciter's (listen) or the user's (recite now) —
/// and how far the run has come. Nothing without live recognition.
class FollowAlongHint extends ConsumerWidget {
  const FollowAlongHint({super.key});

  /// Its height, to centre it on the bar's border.
  static const height = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(liveRecognitionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final run = ref.watch(followAlongControllerProvider);
    if (run == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final yours = run.phase == FollowAlongPhase.user;
    final review = run.phase == FollowAlongPhase.review;
    final reciter = reciterFor(ref.watch(reciterProvider));
    final foreground = review
        ? scheme.onErrorContainer
        : yours
        ? scheme.onPrimary
        : scheme.onSecondaryContainer;
    final style = theme.textTheme.labelMedium?.copyWith(color: foreground);
    return GuideTarget(
      id: 'follow-hint',
      child: AnimatedContainer(
        key: ValueKey('follow-hint-${run.phase.name}'),
        duration: const Duration(milliseconds: 250),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: review
              ? scheme.errorContainer
              : yours
              ? scheme.primary
              : scheme.secondaryContainer,
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
              review
                  ? Icons.error_outline_rounded
                  : yours
                  ? Icons.mic_rounded
                  : Icons.headphones_rounded,
              color: foreground,
              size: 16,
            ),
            Flexible(
              child: Text(
                review
                    ? l10n.followMistakesFound
                    : !yours
                    ? l10n.followReciterTurn(reciterName(context, reciter))
                    : run.again
                    ? l10n.followAgain
                    : l10n.followYourTurn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (run.parts.length > 1)
              Text('${run.index + 1}/${run.parts.length}', style: style),
          ],
        ),
      ),
    );
  }
}
