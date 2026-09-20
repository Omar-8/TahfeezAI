import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_text_boldness_controller.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/mushaf_text_boldness.dart';
import 'mushaf_appearance_sheet.dart';
import 'mushaf_text_boldness_sheet.dart';

/// Mushaf mode's own "Reader options" — Appearance and Quran text
/// boldness, the two Mushaf-page visual settings. Shared by both Mushaf
/// surfaces so they never drift out of sync with each other again:
/// [_MushafModeScaffold] (`reader_screen.dart`'s in-place Mushaf mode) and
/// [MushafReaderScreen] (the standalone Page-tab route) each have their
/// own tune/"Reader options" button, and both must open *this* sheet, not
/// [showMushafAppearanceSheet] directly — a real bug this fixes: the
/// in-place Mushaf mode's tune button used to open the appearance picker
/// directly, so the newer "Quran text boldness" setting (added to the
/// verse-by-verse-only `reader_options_sheet.dart` sheet, which Mushaf
/// mode never actually opens) was completely unreachable from Mushaf mode
/// itself — the one place it was meant for.
void showMushafReaderOptionsSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Reader options',
    builder: (context) => const _MushafReaderOptionsBody(),
  );
}

class _MushafReaderOptionsBody extends ConsumerWidget {
  const _MushafReaderOptionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mushafAppearanceControllerProvider);
    final textBoldness = ref.watch(mushafTextBoldnessControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Appearance'),
          subtitle: Text(appearance.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showMushafAppearanceSheet(context),
        ),
        ListTile(
          title: const Text('Quran text boldness'),
          subtitle: Text(textBoldness.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showMushafTextBoldnessSheet(context),
        ),
      ],
    );
  }
}
