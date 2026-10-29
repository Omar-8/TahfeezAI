import '../../guide/guide.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listen/application/quran_audio_player.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../ai/matching/quran_word_corpus.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_providers.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/hifz_controller.dart';
import '../application/live_recognition_controller.dart';
import '../application/mushaf_recitation_target.dart';
import '../application/quran_match_controller.dart'
    show quranWordCorpusProvider;
import '../application/recitation_session_controller.dart';
import 'recitation_controls.dart' show showRecitationIntro;
import '../../../core/ui/sheet_actions.dart';

/// Loop recitation's settings: how to repeat (the whole range, or each
/// ayah), the range, and how many times — then starts reciting.
/// Shown like the Hifz settings sheet: a drag handle, as tall as its
/// content, below the app bar.
Future<void> showRecitationLoopSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    constraints: sheetBelowAppBar(context),
    builder: (context) => GlassSheet(child: const _RecitationLoopSheet()),
  );
}

class _RecitationLoopSheet extends ConsumerStatefulWidget {
  const _RecitationLoopSheet();

  @override
  ConsumerState<_RecitationLoopSheet> createState() =>
      _RecitationLoopSheetState();
}

class _RecitationLoopSheetState extends ConsumerState<_RecitationLoopSheet> {
  late HifzLoop _loop;
  VerseRef? _from, _to;

  @override
  void initState() {
    super.initState();
    final hifz = ref.read(hifzControllerProvider);
    // Strict is one setting, shared with Hifz settings and Follow along.
    _loop = ref
        .read(hifzControllerProvider.notifier)
        .lastLoop
        .copyWith(strict: ref.read(hifzSettingsProvider).strict);
    _from = hifz.range?.from;
    _to = hifz.range?.to;
  }

  static int _compare(VerseRef a, VerseRef b) => a.chapterNo != b.chapterNo
      ? a.chapterNo - b.chapterNo
      : a.verseNo - b.verseNo;

  /// Without a range chosen: from the visible page's first ayah to the end
  /// of its surah.
  void _defaults(Map<int, IndexedSurah> surahs) {
    if (_from != null && _to != null) return;
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    final spans = ref.read(mushafPageVersesProvider);
    final page = location is QuranLocationPage
        ? firstVisiblePage(
            location.pageNumber,
            spread: ref.read(fullBleedContentProvider),
          )
        : null;
    final first = spans[page]?.first ?? (chapterNo: 1, verseNo: 1);
    _from = first;
    _to = (
      chapterNo: first.chapterNo,
      verseNo: surahs[first.chapterNo]?.surah.ayahCount ?? first.verseNo,
    );
  }

  int _ayahCount(Map<int, IndexedSurah> surahs, VerseRef from, VerseRef to) {
    if (from.chapterNo == to.chapterNo) return to.verseNo - from.verseNo + 1;
    var n = (surahs[from.chapterNo]?.surah.ayahCount ?? 0) - from.verseNo + 1;
    for (var c = from.chapterNo + 1; c < to.chapterNo; c++) {
      n += surahs[c]?.surah.ayahCount ?? 0;
    }
    return n + to.verseNo;
  }

  void _setFrom(VerseRef from, Map<int, IndexedSurah> surahs) {
    setState(() {
      _from = from;
      if (_compare(_to!, from) < 0) {
        _to = (
          chapterNo: from.chapterNo,
          verseNo: surahs[from.chapterNo]?.surah.ayahCount ?? from.verseNo,
        );
      }
    });
  }

  void _setTo(VerseRef to) {
    setState(() {
      _to = to;
      if (_compare(to, _from!) < 0) {
        _from = (chapterNo: to.chapterNo, verseNo: 1);
      }
    });
  }

  Future<void> _start() async {
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location == null) return;
    // How the check works, over this sheet (the first time, and in the
    // guide): closed, back to the choices here.
    if (!await showRecitationIntro(context, RecitationIntroMode.loop) ||
        !mounted) {
      return;
    }
    ref.read(hifzControllerProvider.notifier).setLoop((
      from: _from!,
      to: _to!,
    ), _loop);
    Navigator.of(context).pop();
    ref
        .read(recitationSessionControllerProvider.notifier)
        .start(startLocation: location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surahList = ref.watch(indexedSurahsProvider).value;
    if (surahList == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final surahs = {for (final s in surahList) s.surah.surahNo: s};
    _defaults(surahs);
    final from = _from!, to = _to!;
    final canStart =
        ref.watch(mushafRecitationTargetProvider)?.location != null &&
        !ref.watch(recitationSessionControllerProvider).isActive;
    final eachAyah = _loop.mode == HifzLoopMode.eachAyah;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
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
                Icon(Icons.repeat_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: TahfeezSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.recLoop,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TahfeezSpacing.md),
            GuideTarget(
              id: 'loop-order',
              child: _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label(l10n.recLoopOrder),
                    SegmentedButton<HifzLoopMode>(
                      key: const ValueKey('loop-mode'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: HifzLoopMode.eachAyah,
                          label: Text(l10n.recLoopEachAyah),
                        ),
                        ButtonSegment(
                          value: HifzLoopMode.range,
                          label: Text(l10n.recLoopRange),
                        ),
                      ],
                      selected: {_loop.mode},
                      onSelectionChanged: (s) =>
                          setState(() => _loop = _loop.copyWith(mode: s.first)),
                    ),
                    const SizedBox(height: TahfeezSpacing.smPlus),
                    Text(
                      eachAyah ? l10n.recLoopEachAyahSub : l10n.recLoopRangeSub,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: TahfeezSpacing.lg),
            GuideTarget(
              id: 'loop-range',
              child: _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label(l10n.recFrom),
                    VersePicker(
                      id: 'from',
                      surahs: surahList,
                      value: from,
                      ayahCount: surahs[from.chapterNo]?.surah.ayahCount ?? 1,
                      onSurah: (c) =>
                          _setFrom((chapterNo: c, verseNo: 1), surahs),
                      onAyah: (v) => _setFrom((
                        chapterNo: from.chapterNo,
                        verseNo: v,
                      ), surahs),
                    ),
                    const SizedBox(height: TahfeezSpacing.md),
                    label(l10n.recTo),
                    VersePicker(
                      id: 'to',
                      surahs: surahList,
                      value: to,
                      ayahCount: surahs[to.chapterNo]?.surah.ayahCount ?? 1,
                      onSurah: (c) => _setTo((
                        chapterNo: c,
                        verseNo: surahs[c]?.surah.ayahCount ?? 1,
                      )),
                      onAyah: (v) =>
                          _setTo((chapterNo: to.chapterNo, verseNo: v)),
                    ),
                    const SizedBox(height: TahfeezSpacing.md),
                    Center(
                      child: Container(
                        key: const ValueKey('loop-ayah-count'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: TahfeezSpacing.smPlus,
                          vertical: TahfeezSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            TahfeezRadii.pill,
                          ),
                        ),
                        child: Text(
                          l10n.recLoopAyahCount(_ayahCount(surahs, from, to)),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: TahfeezSpacing.lg),
            GuideTarget(
              id: 'loop-times',
              child: _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.recLoopTimes,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: TahfeezSpacing.xs),
                              Text(
                                eachAyah
                                    ? l10n.recLoopTimesAyahSub
                                    : l10n.recLoopTimesRangeSub,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: TahfeezSpacing.sm),
                        CountStepper(
                          id: 'loop-count',
                          value: _loop.count,
                          min: 1,
                          max: HifzLoop.maxCount,
                          onChanged: (n) =>
                              setState(() => _loop = _loop.copyWith(count: n)),
                        ),
                      ],
                    ),
                    const SizedBox(height: TahfeezSpacing.smPlus),
                    Wrap(
                      spacing: TahfeezSpacing.sm,
                      runSpacing: TahfeezSpacing.sm,
                      children: [
                        for (final n in const [3, 5, 7, 10, 20])
                          ChoiceChip(
                            label: Text('$n'),
                            selected: _loop.count == n,
                            showCheckmark: false,
                            onSelected: (_) => setState(
                              () => _loop = _loop.copyWith(count: n),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!eachAyah) ...[
              const Divider(height: TahfeezSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recLoopPerAyah,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: TahfeezSpacing.xs),
                        Text(
                          l10n.recLoopPerAyahSub,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TahfeezSpacing.sm),
                  CountStepper(
                    id: 'loop-per-ayah',
                    value: _loop.perAyah,
                    min: 1,
                    max: HifzLoop.maxCount,
                    onChanged: (n) =>
                        setState(() => _loop = _loop.copyWith(perAyah: n)),
                  ),
                ],
              ),
            ],
            const Divider(height: TahfeezSpacing.lg),
            SwitchListTile(
              key: const ValueKey('loop-strict'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.followStrict),
              subtitle: Text(l10n.recLoopStrictSub),
              value: _loop.strict,
              onChanged: (v) => setState(() {
                _loop = _loop.copyWith(strict: v);
                ref
                    .read(hifzSettingsProvider.notifier)
                    .update(ref.read(hifzSettingsProvider).copyWith(strict: v));
              }),
            ),
            const SizedBox(height: TahfeezSpacing.smPlus),
            Text(
              l10n.recLoopHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TahfeezSpacing.md),
            SheetActions(
              primary: GuideTarget(
                id: 'loop-start',
                child: FilledButton.icon(
                  key: const ValueKey('loop-start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  // "Start", as Follow along's button says.
                  label: Text(
                    l10n.followStart,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  onPressed: canStart ? _start : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One part of the loop sheet, unboxed (like the Hifz settings sheet's
/// rows).
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A surah (searchable list) and an ayah in it.
class VersePicker extends StatelessWidget {
  const VersePicker({
    super.key,
    required this.id,
    required this.surahs,
    required this.value,
    required this.ayahCount,
    required this.onSurah,
    required this.onAyah,
  });

  final String id;
  final List<IndexedSurah> surahs;
  final VerseRef value;
  final int ayahCount;
  final ValueChanged<int> onSurah;
  final ValueChanged<int> onAyah;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<int>(
          // Rebuilt when the surah changes from outside (the other end of
          // the range moving it), so its text follows.
          key: ValueKey('loop-$id-surah-${value.chapterNo}'),
          initialSelection: value.chapterNo,
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 360,
          label: Text(l10n.recLoopSurah),
          leadingIcon: const Icon(Icons.menu_book_outlined),
          dropdownMenuEntries: [
            for (final s in surahs)
              DropdownMenuEntry(
                value: s.surah.surahNo,
                label:
                    '${s.surah.surahNo}. '
                    '${s.localizedName ?? s.arabicName ?? ''}',
              ),
          ],
          onSelected: (c) {
            if (c != null && c != value.chapterNo) onSurah(c);
          },
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        Row(
          children: [
            // Wraps rather than pushing the stepper off (long languages,
            // large text).
            Expanded(
              child: Text(
                l10n.recLoopAyah,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            CountStepper(
              id: 'loop-$id-ayah',
              value: value.verseNo,
              min: 1,
              max: ayahCount,
              onChanged: onAyah,
            ),
          ],
        ),
      ],
    );
  }
}

/// − value +, the value itself a menu of every choice (an ayah among 286
/// is too far to step to).
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.id,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.untilStopped = false,
  });

  final String id;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  /// One more choice past [max]: ∞, until stopped, as the value 0.
  final bool untilStopped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final endless = untilStopped && value == 0;
    Widget shown(int v) => v == 0
        ? Semantics(
            label: AppLocalizations.of(context).countUntilStopped,
            excludeSemantics: true,
            child: const Text('∞'),
          )
        : Text('$v');
    return Container(
      key: ValueKey(id),
      padding: const EdgeInsets.all(TahfeezSpacing.xs),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            key: ValueKey('$id-minus'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: endless
                ? () => onChanged(max)
                : value > min
                ? () => onChanged(value - 1)
                : null,
          ),
          PopupMenuButton<int>(
            key: ValueKey('$id-value'),
            initialValue: value,
            onSelected: onChanged,
            constraints: const BoxConstraints(maxHeight: 320),
            itemBuilder: (context) => [
              for (var v = min; v <= max; v++)
                PopupMenuItem(value: v, height: 40, child: shown(v)),
              if (untilStopped)
                PopupMenuItem(value: 0, height: 40, child: shown(0)),
            ],
            child: SizedBox(
              width: 48,
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: shown(value),
              ),
            ),
          ),
          IconButton.filledTonal(
            key: ValueKey('$id-plus'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: endless
                ? null
                : value < max
                ? () => onChanged(value + 1)
                : untilStopped
                ? () => onChanged(0)
                : null,
          ),
        ],
      ),
    );
  }
}

/// A thin progress line under a Mushaf screen's app bar, drawn over the
/// page's top edge (it takes none of its height): where the page on screen
/// is in the Mushaf — or, while a loop runs, how far the loop has come, cut
/// into its repetitions (whole range) or ayahs (ayah by ayah).
class RecitationProgressBar extends ConsumerWidget {
  const RecitationProgressBar({super.key, required this.location});

  final QuranLocation? location;

  static const height = 3.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = this.location;
    if (location is! QuranLocationPage) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final loop = ref.watch(liveRecognitionEnabledProvider)
        ? _loopProgress(ref, AppLocalizations.of(context))
        : null;
    final double value;
    var segments = 1;
    String? semantics;
    final reading = loop == null ? _readingProgress(ref, location) : null;
    if (loop != null) {
      (value, segments, semantics) = loop;
    } else if (reading != null) {
      value = reading;
    } else {
      // (The words not loaded yet: the page's place in the Mushaf.)
      final pages = ref
          .watch(mushafByIdProvider(location.mushafId))
          .value
          ?.pageCount;
      if (pages == null || pages <= 0) return const SizedBox.shrink();
      final spread = ref.watch(fullBleedContentProvider);
      final last =
          firstVisiblePage(location.pageNumber, spread: spread) +
          (spread ? 1 : 0);
      value = (last / pages).clamp(0.0, 1.0);
    }
    final bar = TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, v, _) => CustomPaint(
        key: ValueKey(loop == null ? 'reading-progress' : 'loop-progress'),
        size: const Size.fromHeight(height),
        painter: _ProgressPainter(
          value: v,
          segments: segments,
          fill: scheme.primary,
          track: scheme.primary.withValues(alpha: 0.18),
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
    return semantics == null
        ? ExcludeSemantics(child: bar)
        : Semantics(
            label: AppLocalizations.of(context).recLoop,
            value: semantics,
            child: bar,
          );
  }

  /// How much of the page (or spread) on screen is done: up to the word last
  /// recited (a Hifz test) or revealed (hide mode); none otherwise.
  static double? _readingProgress(WidgetRef ref, QuranLocationPage location) {
    final corpus = ref.watch(quranWordCorpusProvider).value;
    if (corpus == null || corpus.length == 0) return null;
    final spread = ref.watch(fullBleedContentProvider);
    final first = firstVisiblePage(location.pageNumber, spread: spread);
    final second = spread ? first + 1 : first;
    final ranges = ref.watch(mushafPageWordRangesProvider);
    final firstRange = ranges[first];
    final pageFirst = firstRange == null
        ? null
        : corpus.positionOf(firstRange.first);
    final lastRange = ranges[second] ?? firstRange;
    final pageLast = lastRange == null
        ? null
        : corpus.positionOf(lastRange.last);
    if (pageFirst == null || pageLast == null) return null;
    final hifz = ref.watch(liveRecognitionEnabledProvider)
        ? ref.watch(hifzControllerProvider)
        : null;
    final hide = ref.watch(mushafHideModeProvider);
    // Listening: through the ayah being recited.
    final playing = ref.watch(quranAudioPlayerProvider)?.ayahId;
    int? done;
    if (playing != null &&
        corpus.positionOf((ayahId: playing, wordIndex: 0)) != null) {
      var end = corpus.positionOf((ayahId: playing, wordIndex: 0))!;
      while (end + 1 < corpus.length &&
          corpus.words[end + 1].ref.ayahId == playing) {
        end++;
      }
      done = end;
    } else if (hifz != null && hifz.active) {
      final next = hifz.completed ? null : hifz.expected;
      done = next != null
          ? switch (corpus.positionOf(next)) {
              final int p => p - 1,
              null => null,
            }
          : corpus.positionOf(hifz.last!);
    } else if (hide.enabled) {
      var revealed = hide.revealedOn(first);
      if (second != first && hide.fullyRevealed(first)) {
        revealed += hide.revealedOn(second);
      }
      done = pageFirst + revealed - 1;
    } else {
      done = pageFirst - 1;
    }
    if (done == null) return null;
    return pageProgress(done, first: pageFirst, last: pageLast);
  }

  /// A running loop: its progress, its segments, and in words where it is;
  /// `null` without one.
  static (double, int, String)? _loopProgress(
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final hifz = ref.watch(hifzControllerProvider);
    final corpus = ref.watch(quranWordCorpusProvider).value;
    final loop = hifz.loop;
    final progress = corpus == null ? null : loopProgress(hifz, corpus);
    if (loop == null || progress == null) return null;
    final ayah = hifz.loopAyah;
    final where = hifz.completed
        ? l10n.recLoopComplete
        : [
            if (ayah != null) '${ayah.chapterNo}:${ayah.verseNo}',
            l10n.recLoopProgress(hifz.repetition, loop.count),
          ].join(' · ');
    return (progress.value, progress.segments, where);
  }
}

/// The share of the words [first]..[last] (corpus positions: the page on
/// screen) done up to corpus position [done].
double pageProgress(int done, {required int first, required int last}) =>
    last < first
    ? 0
    : ((done - first + 1) / (last - first + 1)).clamp(0.0, 1.0);

/// How far a running loop has come (0–1), and the segments a progress
/// line shows it in: its repetitions (whole range) or its ayahs (ayah by
/// ayah). `null` without a loop under way.
({double value, int segments})? loopProgress(
  HifzState hifz,
  QuranWordCorpus corpus,
) {
  final loop = hifz.loop, range = hifz.range;
  if (loop == null || range == null || hifz.repetition == 0) return null;
  if (hifz.completed) return (value: 1, segments: 1);
  // How much of this repetition has been recited.
  final first = hifz.first == null ? null : corpus.positionOf(hifz.first!);
  final last = hifz.last == null ? null : corpus.positionOf(hifz.last!);
  final words = first == null || last == null ? 0 : last - first + 1;
  final within = words == 0 ? 0.0 : hifz.revealed.length / words;
  final done = hifz.repetition - 1 + within.clamp(0.0, 1.0);
  if (loop.mode == HifzLoopMode.range && !loop.byAyah) {
    return (value: done / loop.count, segments: loop.count);
  }
  // Ayah by ayah: the ayahs before this one, each recited count times.
  final from = corpus.verseStartPosition(range.from);
  final to = corpus.verseEndPosition(range.to);
  final ayah = hifz.loopAyah;
  final at = ayah == null ? null : corpus.verseStartPosition(ayah);
  if (from == null || to == null || at == null) return null;
  var ayahs = 0, before = 0;
  for (var p = from; p <= to; p++) {
    if (p == from || corpus.words[p].verse != corpus.words[p - 1].verse) {
      ayahs++;
      if (p < at) before++;
    }
  }
  if (loop.mode == HifzLoopMode.range) {
    // A whole-range pass, each ayah perAyah times: this pass's ayahs done.
    final inAyah =
        (hifz.ayahRepetition - 1 + within.clamp(0.0, 1.0)) / loop.perAyah;
    final pass = (before + inAyah) / ayahs;
    return (
      value: (hifz.repetition - 1 + pass) / loop.count,
      segments: loop.count,
    );
  }
  return (
    value: (before * loop.count + done) / (ayahs * loop.count),
    segments: ayahs,
  );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.value,
    required this.segments,
    required this.fill,
    required this.track,
    required this.rtl,
  });

  final double value;
  final int segments;
  final Color fill, track;
  final bool rtl;

  /// Segments narrower than this are drawn as one line.
  static const _minSegment = 12.0;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = size.width / segments >= _minSegment ? segments : 1;
    final width = (size.width - _gap * (n - 1)) / n;
    final radius = Radius.circular(size.height / 2);
    final filled = value.clamp(0.0, 1.0) * n;
    for (var k = 0; k < n; k++) {
      final start = k * (width + _gap);
      final left = rtl ? size.width - start - width : start;
      final rect = Rect.fromLTWH(left, 0, width, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()..color = track,
      );
      final part = (filled - k).clamp(0.0, 1.0);
      if (part <= 0) continue;
      final w = width * part;
      final fillRect = Rect.fromLTWH(
        rtl ? rect.right - w : left,
        0,
        w,
        size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, radius),
        Paint()..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value ||
      old.segments != segments ||
      old.fill != fill ||
      old.track != track ||
      old.rtl != rtl;
}
