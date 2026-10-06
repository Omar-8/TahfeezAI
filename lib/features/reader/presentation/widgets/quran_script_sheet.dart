import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/components/components.dart';
import '../../../../quran/application/available_quran_scripts.dart';
import '../../../../quran/application/quran_script_code.dart';

/// Lets the user pick which installed [QuranScript] the Reader and Mushaf
/// resolve words/pages in — this milestone's "scripts are swappable without
/// UI rewrites" requirement made real: both reading modes already resolve
/// through [quranScriptCodeProvider]/[QuranScriptPreferenceController], so
/// picking a script here changes both without either screen's own code
/// changing. Only reachable from the Reader's options sheet today (no
/// Settings screen exists yet, Milestone 14); Mushaf benefits from the
/// shared preference immediately without needing its own entry point.
void showQuranScriptSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: AppLocalizations.of(context).readerQuranScript,
    builder: (context) => const _QuranScriptSheetBody(),
  );
}

class _QuranScriptSheetBody extends ConsumerWidget {
  const _QuranScriptSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(availableQuranScriptsProvider);
    final selectedCode = ref.watch(quranScriptPreferenceControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: scripts.when(
        data: (scripts) {
          if (scripts.isEmpty) {
            return TahfeezEmptyView(
              icon: Icons.font_download_outlined,
              message: AppLocalizations.of(context)
                  .homeQuranDatasetUnavailableBody,
            );
          }
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final script in scripts)
                ChoiceChip(
                  label: Text(script.displayName),
                  selected: script.code == selectedCode,
                  onSelected: (_) => ref
                      .read(quranScriptPreferenceControllerProvider.notifier)
                      .setScriptCode(script.code),
                ),
            ],
          );
        },
        loading: () => const TahfeezLoadingView(),
        error: (_, _) => TahfeezErrorView(
          message: AppLocalizations.of(context).readerScriptsError,
        ),
      ),
    );
  }
}
