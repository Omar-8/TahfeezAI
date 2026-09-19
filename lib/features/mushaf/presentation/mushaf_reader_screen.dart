import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_breakpoints.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../wbw/presentation/word_detail_sheet.dart';
import '../application/mushaf_appearance_controller.dart';
import '../application/mushaf_page_providers.dart';
import '../domain/mushaf_appearance.dart';
import '../domain/mushaf_line_layout.dart';
import 'mushaf_appearance_sheet.dart';
import 'mushaf_page_view.dart';
import 'mushaf_translation_sheet.dart';

/// Tahfeez's Mushaf (paginated, printed-page-style) reader.
///
/// Device modes (`docs/DESIGN_DIRECTION.md`'s responsive guidance,
/// this milestone's explicit "device modes" requirement):
/// - **Phone / portrait**: one page, horizontal swipe.
/// - **Tablet landscape / wide desktop**: an optional two-page spread, with
///   the lower-numbered (earlier-read) page on the right and the next page
///   on the left, matching how a physical Mushaf opens right-to-left.
///
/// A `PageView.builder` with no explicit `controller:` — Flutter manages
/// its own internal `PageController` when none is given, which naturally
/// resets to a fresh position when this widget's `key` changes (used here
/// to reset cleanly when switching between single-page and two-page-spread
/// layouts, e.g. on rotation, rather than trying to remap one controller's
/// index meaning across two different pagination schemes).
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
        title: const Text('Mushaf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate_outlined),
            tooltip: 'Translation & tafsir',
            onPressed: () => showMushafTranslationSheet(
              context,
              mushafId: widget.mushafId,
              pageNumber: _currentPageNumber,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Appearance',
            onPressed: () => showMushafAppearanceSheet(context),
          ),
        ],
      ),
      body: mushafAsync.when(
        data: (mushaf) {
          if (mushaf == null) {
            return _unavailable(colors.secondaryText);
          }
          return _MushafPager(
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
    );
  }

  Widget _unavailable(Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'This will appear automatically once a Quran dataset is added to the app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

class _MushafPager extends StatefulWidget {
  const _MushafPager({
    required this.mushafId,
    required this.pageCount,
    required this.initialPageNumber,
    required this.onPageChanged,
  });

  final int mushafId;
  final int pageCount;
  final int initialPageNumber;
  final ValueChanged<int> onPageChanged;

  @override
  State<_MushafPager> createState() => _MushafPagerState();
}

class _MushafPagerState extends State<_MushafPager> {
  bool? _twoPageSpread;
  late PageController _controller;

  void _ensureController(bool useTwoPageSpread) {
    if (_twoPageSpread == useTwoPageSpread) return;
    if (_twoPageSpread != null) _controller.dispose();
    _twoPageSpread = useTwoPageSpread;
    final initialIndex = useTwoPageSpread
        ? ((widget.initialPageNumber - 1) ~/ 2).clamp(
            0,
            (widget.pageCount / 2).ceil() - 1,
          )
        : (widget.initialPageNumber - 1).clamp(0, widget.pageCount - 1);
    _controller = PageController(initialPage: initialIndex);
  }

  @override
  void dispose() {
    if (_twoPageSpread != null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = TahfeezBreakpoint.of(context);
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final useTwoPageSpread =
        breakpoint.isAtLeastTablet && isLandscape && size.width > 700;
    _ensureController(useTwoPageSpread);

    if (!useTwoPageSpread) {
      return PageView.builder(
        key: const ValueKey('single'),
        controller: _controller,
        reverse: true,
        itemCount: widget.pageCount,
        onPageChanged: (index) => widget.onPageChanged(index + 1),
        itemBuilder: (context, index) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: MushafPageView(
                mushafId: widget.mushafId,
                pageNumber: index + 1,
                onWordTap: (placement) => _showWordInfo(context, placement),
              ),
            ),
          );
        },
      );
    }

    final spreadCount = (widget.pageCount / 2).ceil();
    return PageView.builder(
      key: const ValueKey('spread'),
      controller: _controller,
      reverse: true,
      itemCount: spreadCount,
      onPageChanged: (index) => widget.onPageChanged(index * 2 + 1),
      itemBuilder: (context, spreadIndex) {
        final rightPageNumber = spreadIndex * 2 + 1;
        final leftPageNumber = spreadIndex * 2 + 2;
        return Row(
          children: [
            Expanded(
              child: rightPageNumber <= widget.pageCount
                  ? MushafPageView(
                      mushafId: widget.mushafId,
                      pageNumber: rightPageNumber,
                      onWordTap: (placement) =>
                          _showWordInfo(context, placement),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: leftPageNumber <= widget.pageCount
                  ? MushafPageView(
                      mushafId: widget.mushafId,
                      pageNumber: leftPageNumber,
                      onWordTap: (placement) =>
                          _showWordInfo(context, placement),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  void _showWordInfo(BuildContext context, MushafWordPlacement placement) {
    // Only a real Quran word has canonical identity to look up — an
    // ayahMarker/otherMarker/unknown token renders normally but is not a
    // recited Quran word, per this project's explicit "markers must not
    // participate in word-by-word" rule.
    if (placement.tokenType != MushafTokenType.quranWord) return;
    final ayahId = placement.canonicalAyahId;
    final wordIndex = placement.canonicalWordIndex;
    if (ayahId == null || wordIndex == null) return;

    showWordDetailSheet(
      context,
      wordRef: (ayahId: ayahId, wordIndex: wordIndex),
      arabicText: placement.text,
    );
  }
}
