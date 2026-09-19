import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../application/reader_preferences_controller.dart';
import '../application/reader_session_controller.dart';
import '../domain/reader_layout_item.dart';
import 'widgets/bismillah_divider.dart';
import 'widgets/chapter_info_card.dart';
import 'widgets/chapter_title_header.dart';
import 'widgets/reader_mode_switch.dart';
import 'widgets/reader_options_sheet.dart';
import 'widgets/section_marker_label.dart';
import 'widgets/verse_block.dart';
import 'widgets/verse_share_sheet.dart';

/// Tahfeez's verse-by-verse Quran reader — this milestone's "production
/// -quality semantic reader," reached from any [QuranLocation] the Quran
/// index (Milestone 5) or a future caller (search, bookmarks, deep links)
/// resolves. See `lib/features/reader/application/reader_session_controller.dart`
/// for how every reading mode (full Surah, verse range, individual Ayah,
/// Juz, Hizb, continuous scrolling) is served by one batched-loading
/// engine.
///
/// The reader is deliberately quieter than Home
/// (`docs/DESIGN_DIRECTION.md`'s "chrome recedes while reading" principle):
/// a plain, non-collapsing `AppBar` rather than a scroll-linked collapsing
/// header (real collapsing-chrome animation is deferred — see
/// `docs/ARCHITECTURE.md`'s "what this milestone deliberately did not do"),
/// and no decorative surfaces around the Arabic text itself.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.location});

  final QuranLocation location;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};
  bool _recordedInitialLocation = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 800) return;

    final continuousScrolling = ref.read(
      continuousScrollingPreferenceControllerProvider,
    );
    if (!continuousScrolling) return;

    ref.read(readerSessionProvider(widget.location).notifier).loadMore();
  }

  GlobalKey _keyFor(int ayahId) =>
      _verseKeys.putIfAbsent(ayahId, () => GlobalKey());

  void _maybeScrollTo(int? ayahId) {
    if (ayahId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _verseKeys[ayahId];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.05,
          duration: const Duration(milliseconds: 1),
        );
      }
      ref
          .read(readerSessionProvider(widget.location).notifier)
          .consumeScrollTarget();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(readerSessionProvider(widget.location));
    final readerMode = ref.watch(readerModePreferenceControllerProvider);
    final arabicVisible = ref.watch(
      arabicTextVisiblePreferenceControllerProvider,
    );

    ref.listen(readerSessionProvider(widget.location), (previous, next) {
      final data = next.value;
      if (data != null && data.items.isNotEmpty && !_recordedInitialLocation) {
        _recordedInitialLocation = true;
        ref
            .read(recentQuranLocationControllerProvider.notifier)
            .record(widget.location);
      }
      _maybeScrollTo(data?.scrollToAyahId);
    });

    final session = sessionAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(widget.location)),
        actions: [
          ReaderModeSwitch(mode: readerMode),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Reader options',
            onPressed: () => showReaderOptionsSheet(context),
          ),
        ],
      ),
      body: sessionAsync.when(
        data: (state) => _ReaderBody(
          state: state,
          arabicVisible: arabicVisible,
          keyFor: _keyFor,
          onToggleSelection: (ayahId) => ref
              .read(readerSessionProvider(widget.location).notifier)
              .toggleSelection(ayahId),
        ),
        loading: () => const TahfeezLoadingView(),
        error: (_, _) => const TahfeezEmptyView(
          icon: Icons.menu_book_outlined,
          message: 'This will appear automatically once a Quran dataset is added to the app.',
        ),
      ),
      bottomNavigationBar: session != null && session.selectedAyahIds.isNotEmpty
          ? _SelectionBar(
              count: session.selectedAyahIds.length,
              onClear: () => ref
                  .read(readerSessionProvider(widget.location).notifier)
                  .clearSelection(),
              onShare: () {
                final text = _composeShareText(session);
                showVerseShareSheet(context, text);
              },
            )
          : null,
    );
  }

  String _composeShareText(ReaderSessionState state) {
    final selected =
        state.items
            .whereType<ReaderVerseItem>()
            .map((item) => item.ayah)
            .where((ayah) => state.selectedAyahIds.contains(ayah.ayah.id))
            .toList()
          ..sort((a, b) => a.ayah.id.compareTo(b.ayah.id));

    return selected
        .map((ayah) {
          final reference = '${ayah.ayah.chapterNo}:${ayah.ayah.verseNo}';
          final text = ayah.words.map((w) => w.text).join(' ');
          return '$reference\n$text';
        })
        .join('\n\n');
  }
}

String _titleFor(QuranLocation location) {
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

class _ReaderBody extends StatelessWidget {
  const _ReaderBody({
    required this.state,
    required this.arabicVisible,
    required this.keyFor,
    required this.onToggleSelection,
  });

  final ReaderSessionState state;
  final bool arabicVisible;
  final GlobalKey Function(int ayahId) keyFor;
  final ValueChanged<int> onToggleSelection;

  @override
  Widget build(BuildContext context) {
    if (state.items.isEmpty) {
      return const TahfeezEmptyView(
        icon: Icons.menu_book_outlined,
        message: 'This will appear automatically once a Quran dataset is added to the app.',
      );
    }

    final hasActiveSelection = state.selectedAyahIds.isNotEmpty;

    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        final key = ValueKey(readerLayoutItemKey(item, index));

        return switch (item) {
          ReaderChapterInfoItem(:final surah) => KeyedSubtree(
            key: key,
            child: ChapterInfoCard(surah: surah),
          ),
          ReaderBismillahItem() => KeyedSubtree(
            key: key,
            child: const BismillahDivider(),
          ),
          ReaderChapterTitleItem(:final surahNo) => KeyedSubtree(
            key: key,
            child: ChapterTitleHeader(surahNo: surahNo),
          ),
          ReaderSectionMarkerItem(:final label) => KeyedSubtree(
            key: key,
            child: SectionMarkerLabel(label: label),
          ),
          ReaderVerseItem(:final ayah) => KeyedSubtree(
            key: keyFor(ayah.ayah.id),
            child: VerseBlock(
              ayah: ayah,
              arabicVisible: arabicVisible,
              isSelected: state.selectedAyahIds.contains(ayah.ayah.id),
              hasActiveSelection: hasActiveSelection,
              onToggleSelection: () => onToggleSelection(ayah.ayah.id),
            ),
          ),
        };
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onShare,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(child: Text('$count selected')),
              TextButton(onPressed: onClear, child: const Text('Clear')),
              FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
