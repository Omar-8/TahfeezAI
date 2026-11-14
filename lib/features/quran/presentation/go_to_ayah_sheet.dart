import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import 'tabs/page_index_tab.dart';

/// Shows the "Go to" sheet: an ayah (a chapter number and a verse number)
/// or a page of the Mushaf, each validated against the installed dataset
/// before resolving to a [QuranLocation].
Future<QuranLocation?> showGoToAyahSheet(BuildContext context) {
  return showTahfeezModalBottomSheet<QuranLocation>(
    context: context,
    title: AppLocalizations.of(context).quranGoTo,
    builder: (context) => const _GoToSheet(),
  );
}

/// The ayah form, then the page form, one over the other (as the Mushaf's
/// surah-name sheet lays out its own).
class _GoToSheet extends StatelessWidget {
  const _GoToSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
          heading(l10n.quranTabAyah, Icons.menu_book_outlined),
          const _GoToAyahForm(),
          const Divider(height: TahfeezSpacing.md),
          heading(l10n.quranTabPage, Icons.auto_stories_outlined),
          PageIndexTab(
            key: const ValueKey('go-to-page'),
            embedded: true,
            onSelect: (location) => Navigator.of(context).pop(location),
          ),
        ],
      ),
    );
  }
}

class _GoToAyahForm extends ConsumerStatefulWidget {
  const _GoToAyahForm();

  @override
  ConsumerState<_GoToAyahForm> createState() => _GoToAyahFormState();
}

class _GoToAyahFormState extends ConsumerState<_GoToAyahForm> {
  final _chapterController = TextEditingController();
  final _verseController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _chapterController.dispose();
    _verseController.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final chapterNo = int.tryParse(_chapterController.text);
    final verseNo = int.tryParse(_verseController.text);
    if (chapterNo == null || verseNo == null) {
      setState(
        () => _error = AppLocalizations.of(context).quranEnterChapterVerse,
      );
      return;
    }
    final repository = ref.read(quranRepositoryProvider);
    final valid = await repository.isValidVerse((
      chapterNo: chapterNo,
      verseNo: verseNo,
    ));
    if (!valid) {
      setState(
        () => _error = AppLocalizations.of(context).quranInvalidChapterVerse,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(QuranLocation.ayah(chapterNo, verseNo));
  }

  @override
  Widget build(BuildContext context) {
    // (In the Go to sheet, which scrolls.)
    return Column(
      mainAxisSize: MainAxisSize.min,
      // (Its Go as wide as the page form's.)
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.md,
      children: [
        Row(
          spacing: TahfeezSpacing.md,
          children: [
            Expanded(
              child: TextField(
                key: const Key('goToAyahChapterField'),
                controller: _chapterController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).quranChapter,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                key: const Key('goToAyahVerseField'),
                controller: _verseController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).quranVerse,
                ),
              ),
            ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          key: const ValueKey('go-to-ayah-go'),
          onPressed: _go,
          child: Text(AppLocalizations.of(context).quranGo),
        ),
      ],
    );
  }
}
