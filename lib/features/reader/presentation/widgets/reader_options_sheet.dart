import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/components/components.dart';
import '../../../../quran/application/quran_script_code.dart';
import '../../../../quran/application/translation_selection_controller.dart';
import '../../../../quran/presentation/tafsir_packs_sheet.dart';
import '../../../../quran/presentation/translation_packs_sheet.dart';
import '../../../../wbw/presentation/wbw_packs_sheet.dart';
import '../../../mushaf/application/mushaf_appearance_controller.dart';
import '../../../mushaf/domain/mushaf_appearance.dart';
import '../../../mushaf/presentation/mushaf_appearance_sheet.dart';
import '../../application/reader_preferences_controller.dart';
import 'quran_script_sheet.dart';

/// The reader's own options — a lighter-weight, reader-scoped counterpart
/// to the "reader settings only" gear `docs/reference/04_READER_SPEC.md`
/// §3 describes, since a full Settings screen doesn't exist yet
/// (Milestone 14). Everything here is real and working: "Quran script"
/// and "Word by word" (Milestone 8), and "Translations" (Milestone 9) are
/// real, persisted preferences/resources.
void showReaderOptionsSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Reader options',
    builder: (context) => const _ReaderOptionsBody(),
  );
}

class _ReaderOptionsBody extends ConsumerWidget {
  const _ReaderOptionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuousScrolling = ref.watch(
      continuousScrollingPreferenceControllerProvider,
    );
    final arabicTextVisible = ref.watch(
      arabicTextVisiblePreferenceControllerProvider,
    );
    final scriptCode = ref.watch(quranScriptCodeProvider);
    final activeTranslations = ref.watch(
      translationSelectionControllerProvider,
    );
    final appearance = ref.watch(mushafAppearanceControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: const Text('Appearance'),
          // The same Light/Warm/Sepia/Dark/Black reader theme Mushaf mode
          // already offers, now genuinely applied to verse-by-verse mode
          // too (background, verse Arabic text) -- not just a picker with
          // no effect.
          subtitle: Text(appearance.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showMushafAppearanceSheet(context),
        ),
        // "Quran text boldness" (Mushaf-only) does NOT belong in this
        // sheet: `_ReaderScreenState.build()` only ever renders
        // `showReaderOptionsSheet` from its verse-by-verse branch --
        // Mushaf mode returns `_MushafModeScaffold` instead, which opens
        // `showMushafReaderOptionsSheet` (`mushaf_reader_options_sheet
        // .dart`). A `readerMode == ReaderMode.mushaf` condition here
        // would be unreachable dead code, not a real gate -- that was a
        // real, shipped bug (the setting was completely unreachable from
        // Mushaf mode, the one place it applies) fixed by moving it there
        // instead of guarding it here.
        SwitchListTile(
          title: const Text('Continuous scrolling'),
          subtitle: const Text('Automatically continue into the next chapter'),
          value: continuousScrolling,
          onChanged: (value) => ref
              .read(continuousScrollingPreferenceControllerProvider.notifier)
              .setEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Show Arabic text'),
          value: arabicTextVisible,
          onChanged: (value) => ref
              .read(arabicTextVisiblePreferenceControllerProvider.notifier)
              .setVisible(value),
        ),
        ListTile(
          title: const Text('Translations'),
          subtitle: Text('${activeTranslations.length} selected'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTranslationPacksSheet(context),
        ),
        ListTile(
          title: const Text('Tafsir'),
          subtitle: const Text('Language, active work'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showTafsirPacksSheet(context),
        ),
        ListTile(
          title: const Text('Quran script'),
          subtitle: Text(scriptCode),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showQuranScriptSheet(context),
        ),
        ListTile(
          title: const Text('Word by word'),
          subtitle: const Text('Language packs, translation, transliteration'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showWbwPacksSheet(context),
        ),
      ],
    );
  }
}
