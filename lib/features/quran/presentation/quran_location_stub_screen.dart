import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/domain/models/quran_location.dart';

/// The destination every Quran index result routes to, for this milestone.
///
/// The Verse Reader (Milestone 6) doesn't exist yet, so this proves the
/// `QuranLocation`-based routing genuinely resolves end to end (a real
/// `go_router` route, parsed back into a real, correctly-typed
/// [QuranLocation]) without prematurely building reader UI that belongs to
/// a later milestone — the same "honest placeholder, not a fake screen"
/// pattern `QuranPlaceholderScreen`/`SearchPlaceholderScreen` used in
/// Milestone 4.
class QuranLocationStubScreen extends StatelessWidget {
  const QuranLocationStubScreen({super.key, required this.location});

  final QuranLocation location;

  String _describe() {
    return switch (location) {
      QuranLocationSurah(:final surahNo) => 'Surah $surahNo',
      QuranLocationAyah(:final chapterNo, :final verseNo) =>
        'Ayah $chapterNo:$verseNo',
      QuranLocationAyahRange(
        :final chapterNo,
        :final fromVerseNo,
        :final toVerseNo,
      ) =>
        'Ayah $chapterNo:$fromVerseNo-$toVerseNo',
      QuranLocationJuz(:final juzNo) => 'Juz $juzNo',
      QuranLocationHizb(:final hizbNo) => 'Hizb $hizbNo',
      QuranLocationPage(:final pageNumber) => 'Page $pageNumber',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TahfeezAppBar(title: Text(_describe())),
      body: Padding(
        padding: const EdgeInsets.all(TahfeezSpacing.md),
        child: TahfeezEmptyView(
          icon: Icons.auto_stories_outlined,
          message:
              'Opening ${_describe()}.\n'
              'The Quran reader arrives in a later milestone.',
        ),
      ),
    );
  }
}
