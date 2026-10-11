import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/tafsir_routing.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../application/mushaf_focus_ayah.dart';
import '../application/mushaf_hide_mode.dart' show firstVisiblePage;
import '../application/mushaf_page_verses.dart';

/// The Mushaf's top bar: the tafsir reader (as the ayah sheet's "More"
/// opens it), at the ayah highlighted on the page, else the first ayah of
/// the page on screen.
class MushafTafsirButton extends ConsumerWidget {
  const MushafTafsirButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      key: const ValueKey('mushaf-tafsir'),
      icon: const Icon(Icons.auto_stories_outlined),
      tooltip: AppLocalizations.of(context).tafsirOpen,
      onPressed: () {
        final ayahId = _ayah(ref);
        if (ayahId == null) return;
        openTafsirReader(
          context,
          chapterNo: ayahId ~/ 1000,
          verseNo: ayahId % 1000,
        );
      },
    );
  }

  static int? _ayah(WidgetRef ref) {
    final focused = ref.read(mushafFocusAyahProvider)?.ayahId;
    if (focused != null) return focused;
    final location = ref.read(mushafRecitationTargetProvider)?.location;
    if (location is! QuranLocationPage) return null;
    final page = firstVisiblePage(
      location.pageNumber,
      spread: ref.read(fullBleedContentProvider),
    );
    final first = ref.read(mushafPageVersesProvider)[page]?.first;
    return first == null ? null : first.chapterNo * 1000 + first.verseNo;
  }
}
