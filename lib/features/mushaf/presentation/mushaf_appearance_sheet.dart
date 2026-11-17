import 'package:flutter/material.dart';

import '../../../core/ui/settings_search.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../../guide/guide.dart';
import '../../settings/presentation/theme_choices.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_passages.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';
import 'ayah_view_options.dart';

/// Lets the user pick one of the five reader appearances
/// (`docs/DESIGN_DIRECTION.md`'s "Reader themes").
void showMushafAppearanceSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).mushafAppearance,
    // Scrolls when taller than the room it has (Ayah mode's options, a
    // small screen, large text).
    builder: (context) => const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: MushafAppearanceOptions(),
    ),
  );
}

/// The Mushaf's appearance: in Ayah mode what each ayah shows, then the
/// page's theme and the thematic passages' colours — in its own sheet and
/// at the end of the Hifz settings.
/// The words a search (Hifz settings', [SettingsSearchScope]) finds the
/// page's theme by: its title and each theme's name.
List<String> _themeWords(AppLocalizations l10n) => [
  l10n.mushafPageTheme,
  for (final a in MushafAppearance.values) mushafAppearanceName(a, l10n),
];

List<String> _passageWords(AppLocalizations l10n) => [
  l10n.mushafPassages,
  l10n.mushafPassagesSub,
];

/// Whether [query] (folded) finds any of [MushafAppearanceOptions]'
/// settings.
bool mushafAppearanceHits(BuildContext context, String query) {
  final l10n = AppLocalizations.of(context);
  return SettingsSearchScope.hits(query, [
    ..._themeWords(l10n),
    ..._passageWords(l10n),
  ]);
}

class MushafAppearanceOptions extends ConsumerWidget {
  const MushafAppearanceOptions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mushafAppearanceControllerProvider);

    final l10n = AppLocalizations.of(context);
    // Under a search (Hifz settings'): only what it finds.
    final query = SettingsSearchScope.of(context);
    final themes = SettingsSearchScope.hits(query, _themeWords(l10n));
    final passages = SettingsSearchScope.hits(query, _passageWords(l10n));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ayah mode: what each ayah shows.
        if (query.isEmpty && ref.watch(readerModeProvider) == ReaderMode.ayah)
          const AyahViewOptions(),
        if (query.isEmpty && ref.watch(readerModeProvider) == ReaderMode.ayah)
          const Divider(height: 24),
        // The page's theme: each with a swatch of its paper and ink.
        if (themes) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SearchText(
              l10n.mushafPageTheme,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          GuideTarget(
            id: 'mushaf-page-theme',
            child: Wrap(
              key: const ValueKey('mushaf-page-theme'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final appearance in MushafAppearance.values)
                  ChoiceChip(
                    key: ValueKey('mushaf-page-theme-${appearance.name}'),
                    avatar: ThemeSwatch(
                      paper: appearance.colors.background,
                      ink: appearance.colors.text,
                    ),
                    showCheckmark: false,
                    label: SearchText(mushafAppearanceName(appearance, l10n)),
                    selected: appearance == selected,
                    onSelected: (_) => ref
                        .read(mushafAppearanceControllerProvider.notifier)
                        .setAppearance(appearance),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (passages)
          SwitchListTile(
            key: const ValueKey('mushaf-passages'),
            contentPadding: EdgeInsets.zero,
            title: SearchText(l10n.mushafPassages),
            subtitle: SearchText(l10n.mushafPassagesSub),
            value: ref.watch(mushafPassagesProvider),
            onChanged: (on) =>
                ref.read(mushafPassagesProvider.notifier).set(on),
          ),
      ],
    );
  }
}
