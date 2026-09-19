import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';

/// Shows a bottom sheet for the milestone's "direct Ayah selection" mode: a
/// chapter number and a verse number, validated against the installed
/// dataset before resolving to a [QuranLocation].
Future<QuranLocation?> showGoToAyahSheet(BuildContext context) {
  return showTahfeezModalBottomSheet<QuranLocation>(
    context: context,
    title: 'Go to Ayah',
    builder: (context) => const _GoToAyahForm(),
  );
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
      setState(() => _error = 'Enter a chapter and verse number.');
      return;
    }
    final repository = ref.read(quranRepositoryProvider);
    final valid = await repository.isValidVerse((
      chapterNo: chapterNo,
      verseNo: verseNo,
    ));
    if (!valid) {
      setState(() => _error = 'That chapter/verse combination is invalid.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(QuranLocation.ayah(chapterNo, verseNo));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                  decoration: const InputDecoration(labelText: 'Chapter'),
                ),
              ),
              Expanded(
                child: TextField(
                  key: const Key('goToAyahVerseField'),
                  controller: _verseController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Verse'),
                ),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(onPressed: _go, child: const Text('Go')),
        ],
      ),
    );
  }
}
