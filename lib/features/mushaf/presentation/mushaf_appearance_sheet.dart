import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../../settings/presentation/arabic_font_choices.dart';
import '../../settings/presentation/theme_choices.dart';
import '../../../core/theme/quran_text_style.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_passages.dart';
import '../application/mushaf_page_translations.dart';
import '../application/reader_mode.dart';
import '../../../quran/application/tafsir_library_controller.dart';
import '../../../quran/application/tafsir_selection_controller.dart';
import '../../../quran/presentation/meaning_resource_names.dart';
import '../../../quran/presentation/tafsir_packs_sheet.dart';
import '../../../quran/presentation/translation_packs_sheet.dart';
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
    // Scrolls when taller than the room it has (Ayah mode's options, a
    // small screen, large text).
    return SingleChildScrollView(
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
        // Which ones: the same choice as Settings'.
        if (view.showTranslation)
          _Choice(
            key: const ValueKey('ayah-view-translations'),
            label: l10n.searchTranslations,
            value: switch (ref.watch(activeTranslationBooksProvider).value) {
              final books? when books.isNotEmpty => [
                for (final b in books.values) translationName(l10n, b),
              ].join(', '),
              _ => l10n.readerSelected(0),
            },
            onTap: () => showTranslationPacksSheet(context),
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
        if (view.showTafsir)
          _Choice(
            key: const ValueKey('ayah-view-tafsir-choice'),
            label: l10n.readerTafsir,
            value:
                [
                  for (final t
                      in ref.watch(tafsirLibraryControllerProvider).value ??
                          const [])
                    if (t.work.id ==
                        ref.watch(tafsirSelectionControllerProvider))
                      tafsirName(l10n, t.work),
                ].firstOrNull ??
                l10n.settingsTafsirNone,
            onTap: () => showTafsirPacksSheet(context),
          ),
        toggle(
          'ayah-view-meanings',
          l10n.ayahViewWordMeanings,
          view.showWordMeanings,
          (v) => view.copyWith(showWordMeanings: v),
        ),
        // One size for all of it: the Arabic, word meanings,
        // transliteration, translations and tafsir.
        Row(
          children: [
            Text(l10n.tafsirTextSizeTooltip),
            Expanded(
              child: Slider(
                key: const ValueKey('ayah-view-text-size'),
                value: ref
                    .watch(tafsirTextScaleControllerProvider)
                    .clamp(0.8, 2.0),
                min: 0.8,
                max: 2.0,
                divisions: 12,
                label:
                    '${(ref.watch(tafsirTextScaleControllerProvider) * 100).round()}%',
                onChanged: (value) => ref
                    .read(tafsirTextScaleControllerProvider.notifier)
                    .setScale(value),
              ),
            ),
          ],
        ),
        // The Arabic font (Settings' own choice): Arabic tafsir and
        // translations, and the app's Arabic. The Quran's text keeps its
        // own font.
        // The Quran text's own font: only fonts made for Uthmani text.
        Text(l10n.ayahViewQuranFont),
        const SizedBox(height: 8),
        Wrap(
          key: const ValueKey('ayah-view-quran-font'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final font in QuranFont.values)
              ChoiceChip(
                key: ValueKey('ayah-view-quran-font-${font.name}'),
                // Each one showing itself.
                label: Text(
                  'بِسْمِ ٱللَّهِ',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: font.family, fontSize: 20),
                ),
                tooltip: font.arabicName,
                selected: font == view.quranFont,
                showCheckmark: false,
                onSelected: (_) =>
                    controller.set(view.copyWith(quranFont: font)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l10n.settingsArabicFont),
        const SizedBox(height: 8),
        const ArabicFontChoices(),
        const Divider(height: 24),
      ],
    );
  }
}

/// Which translations, or which tafsir: the current choice, opening the
/// picker Settings uses.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label, value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: const EdgeInsetsDirectional.only(start: 16),
    title: Text(label),
    subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
