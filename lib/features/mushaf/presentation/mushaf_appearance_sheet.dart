import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../../settings/presentation/theme_choices.dart';
import '../application/mushaf_appearance_controller.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final appearance in MushafAppearance.values)
            ChoiceChip(
              label: Text(
                mushafAppearanceName(appearance, AppLocalizations.of(context)),
              ),
              selected: appearance == selected,
              onSelected: (_) => ref
                  .read(mushafAppearanceControllerProvider.notifier)
                  .setAppearance(appearance),
            ),
        ],
      ),
    );
  }
}
