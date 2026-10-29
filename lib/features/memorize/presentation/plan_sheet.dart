import '../../../core/localization/fallback_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_plan.dart';
import '../../../memorization/memorization_providers.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../../core/ui/sheet_actions.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper, VersePicker;

/// Creates or edits the memorization plan: the range, its order, how much a
/// day (ayahs, half-pages or pages), and the study days.
Future<void> showPlanSheet(BuildContext context, {MemorizationPlan? plan}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      builder: (context) => _PlanSheet(plan: plan),
    );

class _PlanSheet extends ConsumerStatefulWidget {
  const _PlanSheet({this.plan});

  final MemorizationPlan? plan;

  @override
  ConsumerState<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<_PlanSheet> {
  // Juz 'Amma, backward, a page a day: a common start.
  late VerseRef _from = _verse(widget.plan?.fromAyah ?? 78001);
  late VerseRef _to = _verse(widget.plan?.toAyah ?? 114006);
  late PlanUnit _unit = widget.plan?.unit ?? PlanUnit.pages;
  late int _amount = widget.plan?.amount ?? 1;
  late final Set<int> _days = {
    ...widget.plan?.studyDays ?? MemorizationPlan.everyDay,
  };
  late bool _backward = widget.plan?.backward ?? widget.plan == null;

  static VerseRef _verse(int ayah) =>
      (chapterNo: ayah ~/ 1000, verseNo: ayah % 1000);
  static int _id(VerseRef v) => v.chapterNo * 1000 + v.verseNo;

  // Bounds for the stepper only: up to a juz a day.
  static const _maxAmount = {
    PlanUnit.ayahs: 300,
    PlanUnit.halfPages: 40,
    PlanUnit.pages: 20,
  };

  /// The weekdays (`DateTime.monday`..) from the locale's first day.
  static List<int> _week(BuildContext context) {
    // 0 = Sunday.
    final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return [for (var i = 0; i < 7; i++) (first + i + 6) % 7 + 1];
  }

  static String _dayName(BuildContext context, int weekday) =>
      DateFormat.E(intlLocaleOf(Localizations.localeOf(context)))
      // 2024-01-01 was a Monday.
      .format(DateTime(2024, 1, weekday));

  Future<void> _save({bool stop = false}) async {
    final repo = ref.read(memorizationRepositoryProvider);
    final now = ref.read(memorizationClockProvider)();
    final from = _id(_from), to = _id(_to);
    final plan =
        (widget.plan ??
                MemorizationPlan(fromAyah: from, toAyah: to, createdAt: now))
            .copyWith(
              fromAyah: from,
              toAyah: to,
              unit: _unit,
              amount: _amount,
              studyDays: _days,
              backward: _backward,
              active: !stop,
            );
    await repo.savePlan(plan);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surahList = ref.watch(indexedSurahsProvider).value;
    if (surahList == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final surahs = {for (final s in surahList) s.surah.surahNo: s};
    int count(int surah) => surahs[surah]?.surah.ayahCount ?? 1;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    void setFrom(VerseRef v) => setState(() {
      _from = v;
      if (_id(_to) < _id(v)) {
        _to = (chapterNo: v.chapterNo, verseNo: count(v.chapterNo));
      }
    });
    void setTo(VerseRef v) => setState(() {
      _to = v;
      if (_id(v) < _id(_from)) _from = (chapterNo: v.chapterNo, verseNo: 1);
    });

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
          Text(l10n.memPlanTitle, style: theme.textTheme.titleLarge),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.recFrom),
                VersePicker(
                  id: 'plan-from',
                  surahs: surahList,
                  value: _from,
                  ayahCount: count(_from.chapterNo),
                  onSurah: (c) => setFrom((chapterNo: c, verseNo: 1)),
                  onAyah: (v) =>
                      setFrom((chapterNo: _from.chapterNo, verseNo: v)),
                ),
                const SizedBox(height: TahfeezSpacing.md),
                label(l10n.recTo),
                VersePicker(
                  id: 'plan-to',
                  surahs: surahList,
                  value: _to,
                  ayahCount: count(_to.chapterNo),
                  onSurah: (c) => setTo((chapterNo: c, verseNo: count(c))),
                  onAyah: (v) => setTo((chapterNo: _to.chapterNo, verseNo: v)),
                ),
              ],
            ),
          ),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.memPlanOrder),
                SegmentedButton<bool>(
                  key: const ValueKey('plan-order'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.memPlanForward),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.memPlanBackward),
                    ),
                  ],
                  selected: {_backward},
                  onSelectionChanged: (s) =>
                      setState(() => _backward = s.first),
                ),
                const SizedBox(height: TahfeezSpacing.md),
                label(l10n.memPlanEachDay),
                SegmentedButton<PlanUnit>(
                  key: const ValueKey('plan-unit'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: PlanUnit.ayahs,
                      label: Text(l10n.memUnitAyahs),
                    ),
                    ButtonSegment(
                      value: PlanUnit.halfPages,
                      label: Text(l10n.memUnitHalfPages),
                    ),
                    ButtonSegment(
                      value: PlanUnit.pages,
                      label: Text(l10n.memUnitPages),
                    ),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => setState(() {
                    _unit = s.first;
                    _amount = _amount.clamp(1, _maxAmount[_unit]!);
                  }),
                ),
                const SizedBox(height: TahfeezSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: CountStepper(
                    id: 'plan-amount',
                    value: _amount,
                    min: 1,
                    max: _maxAmount[_unit]!,
                    onChanged: (n) => setState(() => _amount = n),
                  ),
                ),
              ],
            ),
          ),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: label(l10n.memPlanDays)),
                    Flexible(child: label(l10n.memPlanDaysCount(_days.length))),
                  ],
                ),
                Wrap(
                  spacing: TahfeezSpacing.sm,
                  runSpacing: TahfeezSpacing.sm,
                  children: [
                    for (final day in _week(context))
                      FilterChip(
                        key: ValueKey('plan-day-$day'),
                        showCheckmark: false,
                        label: Text(_dayName(context, day)),
                        selected: _days.contains(day),
                        // At least one study day.
                        onSelected: (on) => setState(() {
                          if (on) {
                            _days.add(day);
                          } else if (_days.length > 1) {
                            _days.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: TahfeezSpacing.sm),
                Text(
                  l10n.memPlanDaysSub,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SheetActions(
            secondary: widget.plan != null
                ? TextButton(
                    key: const ValueKey('plan-stop'),
                    onPressed: () => _save(stop: true),
                    child: SheetActions.label(l10n.memPlanStop),
                  )
                : null,
            primary: FilledButton(
              key: const ValueKey('plan-save'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _save,
              child: Text(
                widget.plan == null ? l10n.memPlanSave : l10n.memPlanUpdate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
