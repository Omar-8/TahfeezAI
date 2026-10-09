import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_progress.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/models/memorization_models.dart';
import '../../../memorization/memorization_providers.dart';
import '../../quran/application/quran_index_providers.dart';

/// Marks the surahs or juz the user already knows
/// (`docs/MEMORIZATION_MILESTONE.md`, "mark, then verify"): checked ones
/// count as memorized, unverified until recited with hide mode on.
/// Unchecking removes only marks never recited.
Future<void> showMarkKnownSheet(BuildContext context) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).memMarkKnown,
      builder: (context) => const _MarkKnownSheet(),
    );

class _MarkKnownSheet extends ConsumerStatefulWidget {
  const _MarkKnownSheet();

  @override
  ConsumerState<_MarkKnownSheet> createState() => _MarkKnownSheetState();
}

class _MarkKnownSheetState extends ConsumerState<_MarkKnownSheet> {
  bool _byJuz = false;

  /// Changes made here, by item: `surah:N` / `juz:N` → checked.
  final _changes = <String, bool>{};
  bool _saving = false;

  Future<void> _save(Map<String, List<int>> ayahsOf) async {
    setState(() => _saving = true);
    final repo = ref.read(memorizationRepositoryProvider);
    final mark = <int>{}, unmark = <int>{};
    for (final MapEntry(key: item, value: checked) in _changes.entries) {
      (checked ? mark : unmark).addAll(ayahsOf[item] ?? const []);
    }
    // An ayah in both (a juz unchecked, a surah in it checked) stays.
    unmark.removeAll(mark);
    await repo.unmarkUnverified(unmark);
    await repo.markMemorized(mark);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(indexedSurahsProvider).value;
    final juz = ref.watch(juzAyahsProvider).value;
    final memories = ref.watch(ayahMemoriesProvider).value;
    if (surahs == null || juz == null || memories == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final ayahsOf = <String, List<int>>{
      for (final s in surahs)
        'surah:${s.surah.surahNo}': [
          for (var a = 1; a <= s.surah.ayahCount; a++)
            s.surah.surahNo * 1000 + a,
        ],
      for (final MapEntry(key: j, value: ayahs) in juz.entries) 'juz:$j': ayahs,
    };
    bool memorized(int a) => memories[a]?.status == MemoryStatus.memorized;

    /// Checked when all its ayahs are memorized, `null` when some are.
    bool? stored(String item) {
      final ayahs = ayahsOf[item] ?? const [];
      final n = ayahs.where(memorized).length;
      return n == 0 ? false : (n == ayahs.length ? true : null);
    }

    final items = _byJuz
        ? [
            for (final j in juz.keys.toList()..sort())
              ('juz:$j', l10n.memJuzNo(j), ''),
          ]
        : [
            for (final s in surahs)
              (
                'surah:${s.surah.surahNo}',
                '${s.surah.surahNo}. ${s.localizedName ?? s.arabicName ?? ''}',
                '${s.surah.ayahCount}',
              ),
          ];

    return Padding(
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
            l10n.memMarkSub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SegmentedButton<bool>(
            key: const ValueKey('mark-by'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l10n.memMarkSurahs)),
              ButtonSegment(value: true, label: Text(l10n.memMarkJuz)),
            ],
            selected: {_byJuz},
            onSelectionChanged: (s) => setState(() => _byJuz = s.first),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final (item, title, trailing) = items[i];
                final value = _changes[item] ?? stored(item);
                return CheckboxListTile(
                  key: ValueKey('mark-$item'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  tristate: true,
                  value: value,
                  title: Text(title),
                  secondary: trailing.isEmpty
                      ? null
                      : Text(
                          trailing,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                  // A partly memorized item checks to all of it.
                  onChanged: (_) => setState(() {
                    final next = value != true;
                    if (next == stored(item)) {
                      _changes.remove(item);
                    } else {
                      _changes[item] = next;
                    }
                  }),
                );
              },
            ),
          ),
          FilledButton(
            key: const ValueKey('mark-save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _changes.isEmpty || _saving
                ? null
                : () => _save(ayahsOf),
            child: Text(l10n.memPlanUpdate),
          ),
        ],
      ),
    );
  }
}
