import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../application/reader_mode.dart';

/// The Mushaf's top bar: the printed page ⇄ Ayah mode (the same page, ayah
/// by ayah with its translation, tafsir and more). The page, the bar and
/// its modes stay as they are.
class ReaderModeToggle extends ConsumerWidget {
  const ReaderModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ayah = ref.watch(readerModeProvider) == ReaderMode.ayah;
    return IconButton(
      key: const ValueKey('reader-mode-toggle'),
      isSelected: ayah,
      icon: const Icon(Icons.view_agenda_outlined),
      selectedIcon: const Icon(Icons.menu_book_outlined),
      // Says where the tap goes.
      tooltip: ayah ? l10n.readerModeMushaf : l10n.readerModeAyah,
      onPressed: () => ref.read(readerModeProvider.notifier).toggle(),
    );
  }
}
