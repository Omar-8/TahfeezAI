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
import '../application/hifz_controller.dart';
import '../application/live_recognition_controller.dart';
import '../application/mushaf_recitation_target.dart';
import '../application/recitation_session_controller.dart';

/// Loop recitation, for a Mushaf screen's app bar: opens [showRecitationLoopSheet]
/// (only where live recognition, and so Hifz mode, is available). Selected
/// while a loop runs; disabled during a session that is not looping.
class HifzLoopButton extends ConsumerWidget {
  const HifzLoopButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(liveRecognitionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final location = ref.watch(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return const SizedBox.shrink();
    final looping =
        ref.watch(hifzControllerProvider.select((s) => s.loop)) != null;
    final session = ref.watch(recitationSessionControllerProvider);
    return IconButton(
      key: const ValueKey('hifz-loop'),
      icon: const Icon(Icons.repeat_rounded),
      isSelected: looping,
      tooltip: AppLocalizations.of(context).recLoop,
      onPressed: session.isActive
          ? null
          : () => showRecitationLoopSheet(context),
    );
  }
}

/// Loop recitation's settings: how to repeat (the whole range, or each
/// ayah), the range, and how many times — then starts reciting.
Future<void> showRecitationLoopSheet(BuildContext context) {
  return showTahfeezModalBottomSheet<void>(
    context: context,
    builder: (context) => const _RecitationLoopSheet(),
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
    _loop = ref.read(hifzControllerProvider.notifier).lastLoop;
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

  void _start() {
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location == null) return;
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

    return SingleChildScrollView(
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.repeat_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: TahfeezSpacing.smPlus),
              Expanded(
                child: Text(l10n.recLoop, style: theme.textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: TahfeezSpacing.md),
          TahfeezCard(
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
          const SizedBox(height: TahfeezSpacing.smPlus),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.recFrom),
                _VersePicker(
                  id: 'from',
                  surahs: surahList,
                  value: from,
                  ayahCount: surahs[from.chapterNo]?.surah.ayahCount ?? 1,
                  onSurah: (c) => _setFrom((chapterNo: c, verseNo: 1), surahs),
                  onAyah: (v) =>
                      _setFrom((chapterNo: from.chapterNo, verseNo: v), surahs),
                ),
                const SizedBox(height: TahfeezSpacing.md),
                label(l10n.recTo),
                _VersePicker(
                  id: 'to',
                  surahs: surahList,
                  value: to,
                  ayahCount: surahs[to.chapterNo]?.surah.ayahCount ?? 1,
                  onSurah: (c) => _setTo((
                    chapterNo: c,
                    verseNo: surahs[c]?.surah.ayahCount ?? 1,
                  )),
                  onAyah: (v) => _setTo((chapterNo: to.chapterNo, verseNo: v)),
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
                      borderRadius: BorderRadius.circular(TahfeezRadii.pill),
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
          const SizedBox(height: TahfeezSpacing.smPlus),
          TahfeezCard(
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
                    _Stepper(
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
                        onSelected: (_) =>
                            setState(() => _loop = _loop.copyWith(count: n)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TahfeezSpacing.smPlus),
          Text(
            l10n.recLoopHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TahfeezSpacing.md),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: TahfeezSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('loop-start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(l10n.recLoopStart),
                  onPressed: canStart ? _start : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A surah (searchable list) and an ayah in it.
class _VersePicker extends StatelessWidget {
  const _VersePicker({
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
            Text(
              l10n.recLoopAyah,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            _Stepper(
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
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String id;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          PopupMenuButton<int>(
            key: ValueKey('$id-value'),
            initialValue: value,
            onSelected: onChanged,
            constraints: const BoxConstraints(maxHeight: 320),
            itemBuilder: (context) => [
              for (var v = min; v <= max; v++)
                PopupMenuItem(value: v, height: 40, child: Text('$v')),
            ],
            child: SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            key: ValueKey('$id-plus'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// A running loop's progress, beside the recording controls: the ayah (ayah
/// by ayah) and which time it is being recited.
class RecitationLoopProgress extends ConsumerWidget {
  const RecitationLoopProgress({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(liveRecognitionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final hifz = ref.watch(hifzControllerProvider);
    final loop = hifz.loop;
    if (loop == null || hifz.repetition == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ayah = hifz.loopAyah;
    final text = hifz.completed
        ? l10n.recLoopComplete
        : [
            if (ayah != null) '${ayah.chapterNo}:${ayah.verseNo}',
            l10n.recLoopProgress(hifz.repetition, loop.count),
          ].join(' · ');
    // Beside the pause button; nothing (no gap either) without a loop, so
    // the bar's other buttons never move.
    return Container(
      key: const ValueKey('loop-progress'),
      margin: const EdgeInsetsDirectional.only(start: TahfeezSpacing.sm),
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.smPlus,
        vertical: TahfeezSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TahfeezRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hifz.completed ? Icons.check_rounded : Icons.repeat_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: TahfeezSpacing.xs),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
