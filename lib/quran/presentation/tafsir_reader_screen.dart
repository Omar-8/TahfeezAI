import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../application/tafsir_selection_controller.dart';
import '../application/tafsir_verse_text.dart';
import '../domain/models/quran_refs.dart';
import '../domain/repositories/quran_repository.dart';
import '../quran_providers.dart';
import '../tafsir_providers.dart';
import 'tafsir_packs_sheet.dart';

/// Tahfeez's own tafsir reader — a dedicated, single-verse-scoped screen
/// (`docs/reference/13_TRANSLATION_TAFSIR_SPEC.md` §5: "reading tafsir is a
/// separate, dedicated screen ... not inline in the main reader"), reached
/// from the verse-by-verse reader's Tafsir action or the word detail
/// sheet's "Read full tafsir" button.
///
/// Lives under `lib/quran/presentation/` (not `features/`) because more
/// than one feature reaches it (Reader's Tafsir action, the WBW word
/// detail sheet's "Read full tafsir" button, Mushaf's translation/tafsir
/// panel) — the same "shared-by-more-than-one-feature belongs outside any
/// one feature" rule `lib/wbw/presentation/` already established for
/// word-by-word, applied here to translation/tafsir content instead.
class TafsirReaderScreen extends ConsumerWidget {
  const TafsirReaderScreen({
    super.key,
    required this.chapterNo,
    required this.verseNo,
  });

  final int chapterNo;
  final int verseNo;

  VerseRef get _verse => (chapterNo: chapterNo, verseNo: verseNo);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTafsirId = ref.watch(tafsirSelectionControllerProvider);
    final textScale = ref.watch(tafsirTextScaleControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Tafsir · $chapterNo:$verseNo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Text size',
            onPressed: () => _showTextSizeSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Tafsir library',
            onPressed: () => showTafsirPacksSheet(context),
          ),
        ],
      ),
      body: activeTafsirId == null
          ? const _NoTafsirSelected()
          : _TafsirContent(
              tafsirId: activeTafsirId,
              verse: _verse,
              textScale: textScale,
            ),
      bottomNavigationBar: _PrevNextBar(verse: _verse),
    );
  }

  void _showTextSizeSheet(BuildContext context, WidgetRef ref) {
    showTahfeezModalBottomSheet(
      context: context,
      title: 'Tafsir text size',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Consumer(
          builder: (context, ref, _) {
            final scale = ref.watch(tafsirTextScaleControllerProvider);
            return Slider(
              value: scale.clamp(0.8, 2.0),
              min: 0.8,
              max: 2.0,
              divisions: 12,
              label: '${(scale * 100).round()}%',
              onChanged: (value) => ref
                  .read(tafsirTextScaleControllerProvider.notifier)
                  .setScale(value),
            );
          },
        ),
      ),
    );
  }
}

class _NoTafsirSelected extends StatelessWidget {
  const _NoTafsirSelected();

  @override
  Widget build(BuildContext context) {
    return TahfeezEmptyView(
      icon: Icons.menu_book_outlined,
      message: 'Install and select a tafsir to read commentary here.',
      action: TextButton(
        onPressed: () => showTafsirPacksSheet(context),
        child: const Text('Browse tafsirs'),
      ),
    );
  }
}

class _TafsirContent extends ConsumerWidget {
  const _TafsirContent({
    required this.tafsirId,
    required this.verse,
    required this.textScale,
  });

  final String tafsirId;
  final VerseRef verse;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workAsync = ref.watch(_tafsirWorkForId(tafsirId));
    final verseTextAsync = ref.watch(
      tafsirVerseTextProvider(
        chapterNo: verse.chapterNo,
        verseNo: verse.verseNo,
        tafsirId: tafsirId,
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.md,
        children: [
          verseTextAsync.when(
            data: (text) => text == null
                ? const TahfeezEmptyView(
                    icon: Icons.menu_book_outlined,
                    message:
                        'No commentary for this verse in the active tafsir.',
                  )
                : Text(
                    text.text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.bodyLarge?.fontSize ??
                              16) *
                          textScale,
                      height: 1.6,
                    ),
                  ),
            loading: () => const TahfeezLoadingView(),
            error: (_, _) =>
                const TahfeezErrorView(message: 'Could not load this tafsir.'),
          ),
          workAsync.when(
            data: (work) => work == null
                ? const SizedBox.shrink()
                : Text(
                    '${work.displayName} — ${work.author}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

final _tafsirWorkForId = FutureProvider.family.autoDispose((ref, String id) {
  return ref.watch(tafsirRepositoryProvider).getInstalledTafsir(id);
});

class _PrevNextBar extends ConsumerWidget {
  const _PrevNextBar({required this.verse});

  final VerseRef verse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(quranRepositoryProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TahfeezSpacing.md,
          vertical: TahfeezSpacing.sm,
        ),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () async {
                final previous = await _previousVerse(repository, verse);
                if (previous != null && context.mounted) {
                  _openTafsirReader(context, previous);
                }
              },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final next = await _nextVerse(repository, verse);
                if (next != null && context.mounted) {
                  _openTafsirReader(context, next);
                }
              },
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
    );
  }

  /// Replaces the current tafsir screen with the adjacent verse's, rather
  /// than pushing a new one per step, so paging through many verses does
  /// not grow the navigation stack unboundedly.
  void _openTafsirReader(BuildContext context, VerseRef verse) {
    GoRouter.of(context).pushReplacement(
      '${AppRoutes.tafsir}/${verse.chapterNo}/${verse.verseNo}',
    );
  }
}

Future<VerseRef?> _nextVerse(
  QuranRepository repository,
  VerseRef current,
) async {
  final surah = await repository.getSurah(current.chapterNo);
  if (surah == null) return null;
  if (current.verseNo < surah.ayahCount) {
    return (chapterNo: current.chapterNo, verseNo: current.verseNo + 1);
  }
  if (current.chapterNo >= repository.chapterCount) return null;
  return (chapterNo: current.chapterNo + 1, verseNo: 1);
}

Future<VerseRef?> _previousVerse(
  QuranRepository repository,
  VerseRef current,
) async {
  if (current.verseNo > 1) {
    return (chapterNo: current.chapterNo, verseNo: current.verseNo - 1);
  }
  if (current.chapterNo <= 1) return null;
  final previousSurah = await repository.getSurah(current.chapterNo - 1);
  if (previousSurah == null) return null;
  return (chapterNo: current.chapterNo - 1, verseNo: previousSurah.ayahCount);
}
