import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../application/mushaf_appearance_controller.dart';
import '../domain/mushaf_appearance.dart';
import 'mushaf_appearance_sheet.dart';

/// Mushaf mode's own "Reader options" — Appearance, the one Mushaf-page
/// visual setting Quran Engine exposes (the former QPC-V2-specific "Quran
/// text boldness" stroke-emboldening setting had no Quran Engine
/// equivalent and was removed with that renderer —
/// `docs/QURAN_ENGINE_MIGRATION.md`). Shared by both Mushaf surfaces so
/// they never drift out of sync with each other: [_MushafModeScaffold]
/// (`reader_screen.dart`'s in-place Mushaf mode) and [MushafReaderScreen]
/// (the standalone Page-tab route) each have their own tune/"Reader
/// options" button, and both open *this* sheet.
void showMushafReaderOptionsSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).readerOptions,
    builder: (context) => const _MushafReaderOptionsBody(),
  );
}

class _MushafReaderOptionsBody extends ConsumerWidget {
  const _MushafReaderOptionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(mushafAppearanceControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).settingsAppearance),
          subtitle: Text(appearance.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showMushafAppearanceSheet(context),
        ),
      ],
    );
  }
}
