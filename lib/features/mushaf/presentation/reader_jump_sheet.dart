import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/domain/quran_ayah_numbers.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper, VersePicker;

/// From the reader's title (its surah and page): where to go — a surah and
/// an ayah in it, or a page — starting from where the reader is.
Future<void> showReaderJumpSheet(
  BuildContext context, {
  required int mushafId,
  required int pageNumber,
  required int pageCount,
  int? surahNo,
}) => showTahfeezModalBottomSheet<void>(
  context: context,
  builder: (_) => _ReaderJump(
    mushafId: mushafId,
    pageNumber: pageNumber,
    pageCount: pageCount,
    surahNo: surahNo ?? 1,
    // The reader's context: the sheet's own is gone once it closes.
    reader: context,
  ),
);

class _ReaderJump extends ConsumerStatefulWidget {
  const _ReaderJump({
    required this.mushafId,
    required this.pageNumber,
    required this.pageCount,
    required this.surahNo,
    required this.reader,
  });

  final int mushafId, pageNumber, pageCount, surahNo;
  final BuildContext reader;

  @override
  ConsumerState<_ReaderJump> createState() => _ReaderJumpState();
}

class _ReaderJumpState extends ConsumerState<_ReaderJump> {
  late VerseRef _verse = (chapterNo: widget.surahNo, verseNo: 1);
  late int _page = widget.pageNumber;

  void _go(QuranLocation location) {
    Navigator.of(context).pop();
    if (widget.reader.mounted) goToQuranLocation(widget.reader, location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(indexedSurahsProvider).value ?? const [];
    Widget heading(String text, IconData icon) => Row(
      spacing: TahfeezSpacing.sm,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        Expanded(child: Text(text, style: theme.textTheme.titleSmall)),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.md,
        children: [
          // A surah, and an ayah in it.
          heading(l10n.recLoopSurah, Icons.menu_book_outlined),
          if (surahs.isNotEmpty)
            VersePicker(
              id: 'jump',
              surahs: surahs,
              value: _verse,
              ayahCount: surahAyahCounts[_verse.chapterNo - 1],
              onSurah: (s) =>
                  setState(() => _verse = (chapterNo: s, verseNo: 1)),
              onAyah: (a) => setState(
                () => _verse = (chapterNo: _verse.chapterNo, verseNo: a),
              ),
            ),
          FilledButton.icon(
            key: const ValueKey('jump-ayah'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(l10n.quranGoToAyah),
            onPressed: () =>
                _go(QuranLocation.ayah(_verse.chapterNo, _verse.verseNo)),
          ),
          const Divider(height: TahfeezSpacing.md),
          // A page.
          heading(l10n.quranTabPage, Icons.auto_stories_outlined),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.homeContinueReadingPage(_page),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              CountStepper(
                id: 'jump-page-number',
                value: _page,
                min: 1,
                max: widget.pageCount,
                onChanged: (p) => setState(() => _page = p),
              ),
            ],
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('jump-page'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(l10n.quranGoToPage),
            onPressed: () => _go(QuranLocation.page(widget.mushafId, _page)),
          ),
        ],
      ),
    );
  }
}
