import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../../settings/presentation/theme_choices.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_passages.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';

/// Lets the user pick one of the five reader appearances
/// (`docs/DESIGN_DIRECTION.md`'s "Reader themes").
void showMushafAppearanceSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).mushafAppearance,
    builder: (context) => const _MushafAppearanceBody(),
  );
}

class _MushafAppearanceBody extends ConsumerWidget {
  const _MushafAppearanceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mushafAppearanceControllerProvider);

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ayah mode: what each ayah shows.
          if (ref.watch(readerModeProvider) == ReaderMode.ayah)
            const _AyahViewOptions(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final appearance in MushafAppearance.values)
                ChoiceChip(
                  label: Text(mushafAppearanceName(appearance, l10n)),
                  selected: appearance == selected,
                  onSelected: (_) => ref
                      .read(mushafAppearanceControllerProvider.notifier)
                      .setAppearance(appearance),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('mushaf-passages'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.mushafPassages),
            subtitle: Text(l10n.mushafPassagesSub),
            value: ref.watch(mushafPassagesProvider),
            onChanged: (on) =>
                ref.read(mushafPassagesProvider.notifier).set(on),
          ),
        ],
      ),
    );
  }
}

/// Ayah mode's switches: what each ayah shows under its Arabic.
class _AyahViewOptions extends ConsumerWidget {
  const _AyahViewOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(ayahViewPreferencesProvider);
    final controller = ref.read(ayahViewPreferencesProvider.notifier);
    Widget toggle(
      String key,
      String title,
      bool value,
      AyahViewPreferences Function(bool) apply,
    ) => SwitchListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      value: value,
      onChanged: (v) => controller.set(apply(v)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.ayahView, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<AyahLayout>(
          key: const ValueKey('ayah-view-layout'),
          segments: [
            ButtonSegment(
              value: AyahLayout.paged,
              label: Text(l10n.tafsirLayoutPaged),
              icon: const Icon(Icons.auto_stories_outlined),
            ),
            ButtonSegment(
              value: AyahLayout.continuous,
              label: Text(l10n.tafsirLayoutContinuous),
              icon: const Icon(Icons.view_day_outlined),
            ),
          ],
          selected: {view.layout},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              controller.set(view.copyWith(layout: s.first)),
        ),
        toggle(
          'ayah-view-translation',
          l10n.tafsirShowTranslation,
          view.showTranslation,
          (v) => view.copyWith(showTranslation: v),
        ),
        toggle(
          'ayah-view-transliteration',
          l10n.tafsirShowTransliteration,
          view.showTransliteration,
          (v) => view.copyWith(showTransliteration: v),
        ),
        toggle(
          'ayah-view-tafsir',
          l10n.ayahViewTafsir,
          view.showTafsir,
          (v) => view.copyWith(showTafsir: v),
        ),
        toggle(
          'ayah-view-meanings',
          l10n.ayahViewWordMeanings,
          view.showWordMeanings,
          (v) => view.copyWith(showWordMeanings: v),
        ),
        const Divider(height: 24),
      ],
    );
  }
}
