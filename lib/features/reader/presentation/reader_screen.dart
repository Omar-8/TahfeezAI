import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/application/recent_quran_location.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';
import '../../mushaf/application/mushaf_appearance_controller.dart';
import '../../mushaf/application/mushaf_focus_ayah.dart';
import '../../mushaf/application/mushaf_page_providers.dart';
import '../../mushaf/domain/mushaf_appearance.dart';
import '../../mushaf/presentation/mushaf_appearance_sheet.dart';
import '../../mushaf/presentation/mushaf_page_title.dart';
import '../../mushaf/presentation/mushaf_page_view.dart';
import '../../mushaf/presentation/mushaf_pager.dart';
import '../../recitation/presentation/recitation_controls.dart';

/// A Quran location (a surah, an ayah, an ayah range, a juz or a hizb)
/// opened in the Mushaf at the page its first ayah is on. Opened at an
/// ayah (Home's Daily Ayah, a search result, a bookmark), that ayah is
/// highlighted while this screen is open.
///
/// (The verse-by-verse reader this screen once also held is archived:
/// git tag `archive/verse-by-verse`.)
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.location});

  final QuranLocation location;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int? _mushafId;
  int? _pageNumber;

  /// No page can be resolved (no Mushaf installed, or a location without a
  /// first ayah): the screen says so instead of spinning.
  bool _unavailable = false;

  // Captured up front: `ref` is unusable by the time dispose runs.
  late final MushafFocusAyah _focus;

  @override
  void initState() {
    super.initState();
    _focus = ref.read(mushafFocusAyahProvider.notifier);
    if (widget.location case QuranLocationAyah(
      :final chapterNo,
      :final verseNo,
    )) {
      Future.microtask(() {
        if (mounted) _focus.focus(this, chapterNo * 1000 + verseNo);
      });
    }
    _resolve();
  }

  @override
  void dispose() {
    final focus = _focus;
    Future.microtask(() => focus.clear(this));
    super.dispose();
  }

  Future<void> _resolve() async {
    final ayahId = await _startAyahIdFor(widget.location);
    final repository = ref.read(quranRepositoryProvider);
    final mushaf = ayahId == null
        ? null
        : await repository.getMushaf(
            scriptCode: ref.read(quranScriptCodeProvider),
          );
    if (!mounted) return;
    if (ayahId == null || mushaf == null) {
      setState(() => _unavailable = true);
      return;
    }
    final page =
        await repository.getPageForAyah(mushafId: mushaf.id, ayahId: ayahId) ??
        1;
    if (!mounted) return;
    setState(() {
      _mushafId = mushaf.id;
      _pageNumber = page;
    });
    ref
        .read(recentQuranLocationControllerProvider.notifier)
        .record(widget.location);
  }

  /// The first ayah of [location].
  Future<int?> _startAyahIdFor(QuranLocation location) async {
    final repository = ref.read(quranRepositoryProvider);
    switch (location) {
      case QuranLocationSurah(:final surahNo):
        return surahNo * 1000 + 1;
      case QuranLocationAyah(:final chapterNo, :final verseNo):
        return chapterNo * 1000 + verseNo;
      case QuranLocationAyahRange(:final chapterNo, :final fromVerseNo):
        return chapterNo * 1000 + fromVerseNo;
      case QuranLocationJuz(:final juzNo):
        final first = (await repository.getJuz(juzNo))?.ranges.firstOrNull;
        return first == null ? null : first.surahNo * 1000 + first.startAyahNo;
      case QuranLocationHizb(:final hizbNo):
        final first = (await repository.getHizb(hizbNo))?.ranges.firstOrNull;
        return first == null ? null : first.surahNo * 1000 + first.startAyahNo;
      case QuranLocationPage():
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => _MushafModeScaffold(
    mushafId: _mushafId,
    pageNumber: _pageNumber,
    unavailable: _unavailable,
    onPageChanged: (page) => setState(() => _pageNumber = page),
  );
}

/// The Mushaf at the resolved page, its colours from
/// [MushafAppearanceController] — never `Theme.of(context)` (see
/// [MushafPageView]).
class _MushafModeScaffold extends ConsumerWidget {
  const _MushafModeScaffold({
    required this.mushafId,
    required this.pageNumber,
    this.unavailable = false,
    required this.onPageChanged,
  });

  final int? mushafId;
  final int? pageNumber;
  final bool unavailable;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(mushafAppearanceControllerProvider).colors;
    final mushafAsync = mushafId == null
        ? null
        : ref.watch(mushafByIdProvider(mushafId!));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        titleSpacing: 0,
        title: mushafId == null || pageNumber == null
            ? Text(
                AppLocalizations.of(context).readerMushaf,
                overflow: TextOverflow.ellipsis,
              )
            : MushafPageTitle(mushafId: mushafId!, pageNumber: pageNumber!),
        actions: [
          // Recording: a red dot while a recitation session runs.
          const RecordingDot(),
          // Loop recitation, and Hifz mode's feedback settings, beside the
          // reader's own.
          const HifzLoopButton(),
          const HifzSettingsButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: AppLocalizations.of(context).readerOptions,
            onPressed: () => showMushafAppearanceSheet(context),
          ),
        ],
      ),
      // Reports the page on screen to the app shell's recitation bar.
      body: RecitationMushafAnchor(
        location: mushafId == null || pageNumber == null
            ? null
            : QuranLocation.page(mushafId!, pageNumber!),
        child: unavailable && (mushafId == null || pageNumber == null)
            ? _unavailable(context, colors.secondaryText)
            : mushafId == null || pageNumber == null
            ? Center(
                child:
                    mushafAsync?.when(
                      data: (_) => CircularProgressIndicator(
                        color: colors.secondaryText,
                      ),
                      loading: () => CircularProgressIndicator(
                        color: colors.secondaryText,
                      ),
                      error: (_, _) =>
                          _unavailable(context, colors.secondaryText),
                    ) ??
                    CircularProgressIndicator(color: colors.secondaryText),
              )
            : mushafAsync!.when(
                data: (mushaf) {
                  if (mushaf == null) {
                    return _unavailable(context, colors.secondaryText);
                  }
                  return MushafPager(
                    key: ValueKey('mushaf-pager-${mushaf.id}'),
                    mushafId: mushaf.id,
                    pageCount: mushaf.pageCount,
                    initialPageNumber: pageNumber!,
                    onPageChanged: onPageChanged,
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colors.secondaryText),
                ),
                error: (_, _) => _unavailable(context, colors.secondaryText),
              ),
      ),
    );
  }

  Widget _unavailable(BuildContext context, Color color) {
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
