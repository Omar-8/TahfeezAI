import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/quran_topics_provider.dart';
import 'tabs/topics_index_tab.dart';

/// The topics an ayah is in (the Quran tab's Topics), in its sheet: each a
/// chip — tapped, the topic in a sheet, its ayahs and passages. Nothing for
/// an ayah in none (owner, 2026-11-15).
class AyahTopicsSection extends ConsumerWidget {
  const AyahTopicsSection({super.key, required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // (Loaded the first time they are asked for.)
    ref.watch(quranTopicsProvider);
    final topics = ref.watch(topicsByAyahProvider)[ayahId] ?? const [];
    if (topics.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      key: const ValueKey('ayah-topics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        TahfeezSectionHeader(
          title: l10n.quranTabTopics,
          icon: Icons.label_outline_rounded,
        ),
        Wrap(
          spacing: TahfeezSpacing.xs,
          runSpacing: TahfeezSpacing.xs,
          children: [
            for (final (:group, :concept) in topics)
              ActionChip(
                key: ValueKey('ayah-topic-${concept.id}'),
                avatar: Icon(topicGroupLook(l10n, group.id).$1, size: 18),
                label: Text(concept.nameIn(language)),
                onPressed: () => showTopicSheet(context, group, concept),
              ),
          ],
        ),
      ],
    );
  }
}
