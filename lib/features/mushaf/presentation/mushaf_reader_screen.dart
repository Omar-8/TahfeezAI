import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_location.dart';
import '../../recitation/presentation/recitation_controls.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../domain/mushaf_appearance.dart';
import 'mushaf_pager.dart';
import 'mushaf_page_title.dart';
import 'mushaf_reader_options_sheet.dart';

/// Tahfeez's standalone Mushaf (paginated, printed-page-style) reader route
/// — reached from the Quran index's Page tab, with no underlying
/// verse-by-verse [QuranLocation] to anchor to (unlike the Reader's own
/// in-place Mushaf mode, `lib/features/reader/presentation/reader_screen.dart`,
/// which shares the same [MushafPager] this screen wraps in its own
/// Scaffold/AppBar).
class MushafReaderScreen extends ConsumerStatefulWidget {
  const MushafReaderScreen({
    super.key,
    required this.mushafId,
    required this.initialPageNumber,
  });

  final int mushafId;
  final int initialPageNumber;

  @override
  ConsumerState<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends ConsumerState<MushafReaderScreen> {
  late int _currentPageNumber = widget.initialPageNumber;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;
    final mushafAsync = ref.watch(mushafByIdProvider(widget.mushafId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        titleSpacing: 0,
        title: MushafPageTitle(
          mushafId: widget.mushafId,
          pageNumber: _currentPageNumber,
        ),
        actions: [
          // Same icon/tooltip/sheet as `reader_screen.dart`'s
          // `_MushafModeScaffold` -- both Mushaf surfaces share
          // `showMushafReaderOptionsSheet` so Appearance/Quran text
          // boldness can never drift out of sync between them again (see
          // that sheet's own doc comment for the real bug this fixes).
          // Recording: a red dot while a recitation session runs.
          const RecordingDot(),
          // Loop recitation, and Hifz mode's feedback settings, beside the
          // reader's own.
          const HifzLoopButton(),
          const HifzSettingsButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).readerOptions,
            onPressed: () => showMushafReaderOptionsSheet(context),
          ),
        ],
      ),
      // Reports the page on screen to the app shell's recitation bar.
      body: RecitationMushafAnchor(
        location: QuranLocation.page(widget.mushafId, _currentPageNumber),
        child: mushafAsync.when(
          data: (mushaf) {
            if (mushaf == null) {
              return _unavailable(colors.secondaryText);
            }
            return MushafPager(
              mushafId: mushaf.id,
              pageCount: mushaf.pageCount,
              initialPageNumber: widget.initialPageNumber,
              onPageChanged: (pageNumber) =>
                  setState(() => _currentPageNumber = pageNumber),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.secondaryText),
          ),
          error: (_, _) => _unavailable(colors.secondaryText),
        ),
      ),
    );
  }

  Widget _unavailable(Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context).homeQuranDatasetUnavailableBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}
