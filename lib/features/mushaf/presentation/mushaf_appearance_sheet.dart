import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
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
            const AyahViewOptions(),
          if (ref.watch(readerModeProvider) == ReaderMode.ayah)
            const Divider(height: 24),
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
