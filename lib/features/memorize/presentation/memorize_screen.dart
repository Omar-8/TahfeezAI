import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_today.dart';
import '../../../memorization/domain/today_scheduler.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/hifz_controller.dart';

/// The Memorize tab: today's memorization, the three parts of a Hifz day
/// (`docs/MEMORIZATION_MILESTONE.md`). Each task opens the Mushaf at its
/// range with hide mode on, the Hifz test set to it; the reciter starts
/// with the mic.
class MemorizeScreen extends ConsumerWidget {
  const MemorizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(todayPlanProvider);
    final names = surahNames(ref);

    Widget section(String title, String subtitle, IconData icon, Widget body) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TahfeezSpacing.sm,
          children: [
            TahfeezSectionHeader(title: title, icon: icon),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            body,
          ],
        );

    return Scaffold(
      appBar: TahfeezAppBar(title: Text(l10n.memTitle), centerTitle: false),
      body: plan.when(
        loading: () => const TahfeezLoadingView(),
        error: (e, _) => TahfeezEmptyView(message: '$e'),
        data: (today) => ListView(
          padding: const EdgeInsets.all(TahfeezSpacing.md),
          children: [
            section(
              l10n.memNewLesson,
              l10n.memNewLessonSoon,
              Icons.auto_stories_outlined,
              const SizedBox.shrink(),
            ),
            const SizedBox(height: TahfeezSpacing.lg),
            if (today.isEmpty)
              TahfeezCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: TahfeezSpacing.sm,
                  children: [
                    Text(
                      l10n.memEmptyTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(l10n.memEmptyBody),
                  ],
                ),
              )
            else ...[
              if (today.recent.isNotEmpty) ...[
                section(
                  l10n.memRecent,
                  l10n.memRecentSub,
                  Icons.replay_outlined,
                  _TaskList(tasks: today.recent, names: names),
                ),
                const SizedBox(height: TahfeezSpacing.lg),
              ],
              if (today.old.isNotEmpty)
                section(
                  l10n.memOld,
                  l10n.memOldSub,
                  Icons.history_edu_outlined,
                  _TaskList(tasks: today.old, names: names),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Each surah's name in the UI language, by number.
Map<int, String> surahNames(WidgetRef ref) => <int, String>{
  for (final s
      in ref.watch(indexedSurahsProvider).value ?? const <IndexedSurah>[])
    s.surah.surahNo: s.localizedName ?? s.arabicName ?? '${s.surah.surahNo}',
};

/// "Al-Ikhlas 1-4", "Al-Ikhlas 1 - An-Nas 6" for ayahs [first]..[last]
/// (stable ids).
String ayahRangeLabel(int first, int last, Map<int, String> names) {
  String name(int ayah) => names[ayah ~/ 1000] ?? '${ayah ~/ 1000}';
  if (first == last) return '${name(first)} ${first % 1000}';
  if (first ~/ 1000 == last ~/ 1000) {
    return '${name(first)} ${first % 1000}–${last % 1000}';
  }
  return '${name(first)} ${first % 1000} – ${name(last)} ${last % 1000}';
}

VerseRef _verse(int ayah) => (chapterNo: ayah ~/ 1000, verseNo: ayah % 1000);

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.names});

  final List<RevisionTask> tasks;
  final Map<int, String> names;

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    RevisionTask task,
  ) async {
    final mushaf = await ref.read(defaultMushafProvider.future);
    final pages = await ref.read(ayahPagesProvider.future);
    final page = task.page ?? pages[task.first];
    if (mushaf == null || page == null || !context.mounted) return;
    ref.read(requestedHifzRangeProvider.notifier).request((
      from: _verse(task.first),
      to: _verse(task.last),
    ));
    final hide = ref.read(mushafHideModeProvider.notifier);
    if (!ref.read(mushafHideModeProvider).enabled) hide.toggle();
    goToQuranLocation(context, QuranLocation.page(mushaf.id, page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TahfeezCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, t) in tasks.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              key: ValueKey('mem-task-${t.first}'),
              title: Text(ayahRangeLabel(t.first, t.last, names)),
              subtitle: Row(
                spacing: TahfeezSpacing.sm,
                children: [
                  if (t.page != null) Text(l10n.memPage(t.page!)),
                  if (t.strength case final s?)
                    Expanded(
                      child: Row(
                        spacing: TahfeezSpacing.xs,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                TahfeezRadii.pill,
                              ),
                              child: LinearProgressIndicator(
                                value: s,
                                minHeight: 4,
                                color: s < 0.7
                                    ? scheme.tertiary
                                    : scheme.primary,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          Text(l10n.memStrength((s * 100).round())),
                        ],
                      ),
                    )
                  else if (t.unverified)
                    Text(l10n.memUnverified),
                ],
              ),
              trailing: t.done
                  ? Chip(
                      avatar: Icon(
                        Icons.check,
                        size: 16,
                        color: scheme.primary,
                      ),
                      label: Text(l10n.memDone),
                      visualDensity: VisualDensity.compact,
                    )
                  : FilledButton.tonal(
                      onPressed: () => _start(context, ref, t),
                      child: Text(l10n.memStart),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
