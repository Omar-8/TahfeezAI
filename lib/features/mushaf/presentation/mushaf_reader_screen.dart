import '../../guide/guide.dart';

import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_location.dart';
import '../../recitation/presentation/recitation_controls.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../application/reader_mode.dart';
import '../domain/mushaf_appearance.dart';
import 'mushaf_pager.dart';
import 'mushaf_page_title.dart';
import 'mushaf_appearance_sheet.dart';
import 'reader_mode_toggle.dart';

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

  // Captured up front: `ref` is unusable by the time dispose runs.
  late final AyahModeTarget _target = ref.read(ayahModeTargetProvider.notifier);

  @override
  void initState() {
    super.initState();
    _target;
  }

  @override
  void dispose() {
    final target = _target;
    // An ayah asked into view (Memorize's parts) but not yet shown: no
    // longer asked once this closes.
    Future.microtask(target.done);
    super.dispose();
  }

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
          // `_MushafModeScaffold`: both open the Mushaf themes
          // (`showMushafAppearanceSheet`).
          // Recording: a red dot while a recitation session runs.
          const RecordingDot(),
          // Hifz mode's feedback settings, beside the reader's own (loop
          // recitation is in the recitation bar).
          const HifzSettingsButton(),
          // The printed page ⇄ Ayah mode.
          const ReaderModeToggle(),
          // The guide to the modes (left of the reader's own settings).
          const GuideButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).readerOptions,
            onPressed: () => showMushafAppearanceSheet(context),
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
