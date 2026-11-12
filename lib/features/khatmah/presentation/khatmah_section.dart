import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/fallback_localizations.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../application/khatmah_controller.dart';
import '../domain/khatmah.dart';

/// Home's khatmah card: none yet — what it is and Start; in progress —
/// today's pages, how far the whole has come, and Read (from the first
/// page of today's not read); today's done — tomorrow's share and Read on;
/// finished — Start another. Its ⋮: change the days, pages read elsewhere,
/// end it.
class HomeKhatmahSection extends ConsumerWidget {
  const HomeKhatmahSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final khatmah = ref.watch(khatmahProvider);
    final today = ref.watch(khatmahTodayProvider);
    return Column(
      key: const ValueKey('home-khatmah'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TahfeezSectionHeader(
          title: l10n.khatmahTitle,
          icon: Icons.auto_stories_outlined,
        ),
        const SizedBox(height: TahfeezSpacing.sm),
        switch (khatmah) {
          AsyncData(value: null) => const _StartCard(),
          AsyncData(value: final k?) when today != null => _ProgressCard(
            khatmah: k,
            today: today,
          ),
          AsyncError() => const _StartCard(),
          _ => const TahfeezCard(child: TahfeezLoadingView()),
        },
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Text(
            l10n.khatmahIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonal(
              key: const ValueKey('khatmah-start'),
              onPressed: () => showKhatmahDaysSheet(context),
              child: Text(l10n.khatmahStart),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the Mushaf at [page].
Future<void> _open(BuildContext context, WidgetRef ref, int page) async {
  final mushaf = await ref.read(defaultMushafProvider.future);
  if (mushaf == null || !context.mounted) return;
  goToQuranLocation(context, QuranLocation.page(mushaf.id, page));
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.khatmah, required this.today});

  final Khatmah khatmah;
  final KhatmahToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    if (today.finished) {
      return TahfeezCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.smPlus,
          children: [
            Row(
              spacing: TahfeezSpacing.sm,
              children: [
                Icon(Icons.verified_rounded, color: scheme.primary),
                Expanded(
                  child: Text(
                    l10n.khatmahFinished,
                    key: const ValueKey('khatmah-finished'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(l10n.khatmahFinishedSub, style: muted),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonal(
                key: const ValueKey('khatmah-start-again'),
                onPressed: () => showKhatmahDaysSheet(context),
                child: Text(l10n.khatmahStartAgain),
              ),
            ),
          ],
        ),
      );
    }
    // Read on past today's portion: the first page not read at all.
    final onward = [
      for (var p = 1; p <= khatmah.total; p++)
        if (!khatmah.readOn.containsKey(p)) p,
    ].firstOrNull;
    final open = today.nextPage ?? onward;
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  today.dayNo <= today.days
                      ? l10n.khatmahDayOf(today.dayNo, today.days)
                      : l10n.khatmahPastEnd,
                  key: const ValueKey('khatmah-day'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              _Menu(khatmah: khatmah),
            ],
          ),
          if (today.doneToday) ...[
            Row(
              spacing: TahfeezSpacing.sm,
              children: [
                Icon(Icons.check_circle_rounded, color: scheme.primary),
                Expanded(
                  child: Text(
                    l10n.khatmahTodayDone,
                    key: const ValueKey('khatmah-today-done'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              today.from == today.to
                  ? l10n.khatmahTodayPage(today.from)
                  : l10n.khatmahTodayPages(today.from, today.to),
              key: const ValueKey('khatmah-today'),
              style: theme.textTheme.titleMedium,
            ),
            if (today.readToday > 0)
              Text(
                l10n.khatmahReadToday(today.readToday, today.pages),
                style: muted,
              ),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(TahfeezRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: today.progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                key: const ValueKey('khatmah-progress'),
                value: value,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
          Text(l10n.khatmahPagesRead(today.read, today.total), style: muted),
          if (open != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: today.doneToday
                  ? FilledButton.tonal(
                      key: const ValueKey('khatmah-read-on'),
                      onPressed: () => _open(context, ref, open),
                      child: Text(l10n.khatmahReadOn),
                    )
                  : FilledButton(
                      key: const ValueKey('khatmah-read'),
                      onPressed: () => _open(context, ref, open),
                      child: Text(l10n.khatmahRead),
                    ),
            ),
        ],
      ),
    );
  }
}

enum _Action { days, readThrough, end }

class _Menu extends ConsumerWidget {
  const _Menu({required this.khatmah});

  final Khatmah khatmah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_Action>(
      key: const ValueKey('khatmah-menu'),
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: l10n.khatmahOptions,
      onSelected: (action) => switch (action) {
        _Action.days => showKhatmahDaysSheet(
          context,
          current: khatmah.days,
          start: khatmah.start,
        ),
        _Action.readThrough => _readThrough(context, ref),
        _Action.end => _end(context, ref),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _Action.days,
          key: const ValueKey('khatmah-change-days'),
          child: Text(l10n.khatmahChangeDays),
        ),
        PopupMenuItem(
          value: _Action.readThrough,
          key: const ValueKey('khatmah-read-through'),
          child: Text(l10n.khatmahReadThrough),
        ),
        PopupMenuItem(
          value: _Action.end,
          key: const ValueKey('khatmah-end'),
          child: Text(l10n.khatmahEnd),
        ),
      ],
    );
  }

  Future<void> _readThrough(BuildContext context, WidgetRef ref) async {
    final page = await showDialog<int>(
      context: context,
      builder: (context) => _NumberDialog(
        title: AppLocalizations.of(context).khatmahReadThrough,
        label: AppLocalizations.of(context).khatmahPageLabel(khatmah.total),
        max: khatmah.total,
        fieldKey: const ValueKey('khatmah-read-through-page'),
        saveKey: const ValueKey('khatmah-read-through-save'),
      ),
    );
    if (page != null) {
      await ref.read(khatmahProvider.notifier).readThrough(page);
    }
  }

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.khatmahEndTitle),
        content: Text(l10n.khatmahEndBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('khatmah-end-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.khatmahEnd),
          ),
        ],
      ),
    );
    if (yes ?? false) await ref.read(khatmahProvider.notifier).end();
  }
}

/// Asks a whole number from 1 to [max] ([label] its field); pops it.
class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.max,
    required this.fieldKey,
    required this.saveKey,
    this.initial,
  });

  final String title, label;
  final int max;
  final int? initial;
  final Key fieldKey, saveKey;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _value = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _done() {
    final n = int.tryParse(_value.text);
    if (n != null && n >= 1 && n <= widget.max) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _value,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: widget.saveKey,
          onPressed: _done,
          child: Text(l10n.khatmahSave),
        ),
      ],
    );
  }
}

/// How many days to finish the Quran in — a new khatmah, or [current]'s
/// changed (its pages read kept; it began on [start]): one of the usual
/// choices, a number typed, or the days to a date picked.
Future<void> showKhatmahDaysSheet(
  BuildContext context, {
  int? current,
  String? start,
}) => showTahfeezModalBottomSheet<void>(
  context: context,
  title: current == null
      ? AppLocalizations.of(context).khatmahStart
      : AppLocalizations.of(context).khatmahChangeDays,
  builder: (context) => _DaysSheet(current: current, start: start),
);

class _DaysSheet extends ConsumerStatefulWidget {
  const _DaysSheet({this.current, this.start});

  final int? current;

  /// The khatmah's first day (a [khatmahDay]); a new one's: today.
  final String? start;

  @override
  ConsumerState<_DaysSheet> createState() => _DaysSheetState();
}

class _DaysSheetState extends ConsumerState<_DaysSheet> {
  /// The most days a khatmah can take: ten years.
  static const maxDays = 3650;

  late int _days = widget.current ?? 30;

  DateTime get _today {
    final now = ref.read(memorizationClockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  late final DateTime _start = widget.start == null
      ? _today
      : DateTime.parse(widget.start!);

  /// The khatmah's last day for [days].
  DateTime _end(int days) =>
      DateTime(_start.year, _start.month, _start.day + days - 1);

  /// Pages a day for [_days]: a khatmah under way, what is left over the
  /// days left (as today's share would be).
  int _perDay() {
    final k = widget.current == null ? null : ref.watch(khatmahProvider).value;
    if (k == null) return (kKhatmahPages / _days).ceil();
    return k.copyWith(days: _days).today(khatmahDay(_today)).pages;
  }

  Future<void> _typeDays() async {
    final l10n = AppLocalizations.of(context);
    final days = await showDialog<int>(
      context: context,
      builder: (context) => _NumberDialog(
        title: l10n.khatmahOtherDays,
        label: l10n.khatmahDaysField(maxDays),
        max: maxDays,
        initial: _days,
        fieldKey: const ValueKey('khatmah-days-field'),
        saveKey: const ValueKey('khatmah-days-field-save'),
      ),
    );
    if (days != null && mounted) setState(() => _days = days);
  }

  Future<void> _pickDate() async {
    // Not before today, nor before the khatmah began.
    final first = _start.isAfter(_today) ? _start : _today;
    final initial = _end(_days).isBefore(first) ? first : _end(_days);
    final date = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: _end(maxDays),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final day = DateTime(date.year, date.month, date.day);
    setState(() => _days = day.difference(_start).inDays + 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final choices = {...Khatmah.dayChoices, _days}.toList()..sort();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          Text(l10n.khatmahFinishIn, style: theme.textTheme.titleSmall),
          Wrap(
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              for (final d in choices)
                ChoiceChip(
                  key: ValueKey('khatmah-days-$d'),
                  label: Text(l10n.khatmahDays(d)),
                  selected: d == _days,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          Wrap(
            spacing: TahfeezSpacing.sm,
            runSpacing: TahfeezSpacing.sm,
            children: [
              ActionChip(
                key: const ValueKey('khatmah-days-other'),
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.khatmahOtherDays),
                onPressed: _typeDays,
              ),
              ActionChip(
                key: const ValueKey('khatmah-days-date'),
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(l10n.khatmahByDate),
                onPressed: _pickDate,
              ),
            ],
          ),
          Text(
            l10n.khatmahFinishesOn(
              DateFormat.yMMMd(intlLocaleOf(Localizations.localeOf(context)))
                  .format(_end(_days)),
            ),
            key: const ValueKey('khatmah-finishes-on'),
            style: theme.textTheme.titleSmall,
          ),
          Text(
            l10n.khatmahPerDay(_perDay()),
            key: const ValueKey('khatmah-per-day'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.khatmahReadTodayHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FilledButton(
            key: const ValueKey('khatmah-days-save'),
            onPressed: () async {
              final controller = ref.read(khatmahProvider.notifier);
              Navigator.of(context).pop();
              if (widget.current == null) {
                await controller.start(_days);
              } else {
                await controller.setDays(_days);
              }
            },
            child: Text(
              widget.current == null ? l10n.khatmahStart : l10n.khatmahSave,
            ),
          ),
        ],
      ),
    );
  }
}
