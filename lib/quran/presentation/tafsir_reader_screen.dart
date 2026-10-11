import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/components/components.dart';
import '../../core/theme/quran_text_style.dart';
import '../application/ayah_reading_extras.dart';
import '../application/canonical_ayah_word_text.dart';
import '../application/tafsir_reader_preferences.dart';
import '../application/translation_selection_controller.dart';
import '../application/tafsir_selection_controller.dart';
import '../application/tafsir_verse_text.dart';
import '../domain/models/quran_refs.dart';
import '../domain/models/translation_models.dart';
import '../domain/quran_ayah_numbers.dart';
import '../translation_providers.dart';
import 'translation_block.dart';
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
    final chosen = ref.watch(tafsirSelectionControllerProvider);
    // A chosen tafsir that isn't installed counts as none.
    final work = chosen == null ? null : ref.watch(_tafsirWorkForId(chosen));
    final textScale = ref.watch(tafsirTextScaleControllerProvider);
    final view = ref.watch(tafsirReaderPreferencesProvider);
    final continuous = view.layout == TafsirLayout.continuous;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).tafsirTitle('$chapterNo:$verseNo'),
        ),
        actions: [
          IconButton(
            key: const ValueKey('tafsir-view-options'),
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: AppLocalizations.of(context).tafsirView,
            onPressed: () => _showViewSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: AppLocalizations.of(context).tafsirTextSizeTooltip,
            onPressed: () => _showTextSizeSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: AppLocalizations.of(context).packsTafsirLibrary,
            onPressed: () => showTafsirPacksSheet(context),
          ),
        ],
      ),
      body: switch (work) {
        null => const _NoTafsirSelected(),
        AsyncValue(isLoading: true, hasValue: false) =>
          const TahfeezLoadingView(),
        AsyncValue(value: final installed?) when continuous =>
          _ContinuousTafsir(
            tafsirId: installed.id,
            start: _verse,
            textScale: textScale,
          ),
        AsyncValue(value: final installed?) => _TafsirContent(
          tafsirId: installed.id,
          verse: _verse,
          textScale: textScale,
        ),
        _ => const _NoTafsirSelected(),
      },
      bottomNavigationBar: continuous ? null : _PrevNextBar(verse: _verse),
    );
  }

  /// How the reader shows its ayahs: one at a time or continuous, and
  /// with translation and transliteration or without (saved).
  void _showViewSheet(BuildContext context) {
    showTahfeezModalBottomSheet(
      context: context,
      title: AppLocalizations.of(context).tafsirView,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final l10n = AppLocalizations.of(context);
          final view = ref.watch(tafsirReaderPreferencesProvider);
          final controller = ref.read(tafsirReaderPreferencesProvider.notifier);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<TafsirLayout>(
                  key: const ValueKey('tafsir-layout'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: TafsirLayout.paged,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(l10n.tafsirLayoutPaged),
                    ),
                    ButtonSegment(
                      value: TafsirLayout.continuous,
                      icon: const Icon(Icons.vertical_split_outlined),
                      label: Text(l10n.tafsirLayoutContinuous),
                    ),
                  ],
                  selected: {view.layout},
                  onSelectionChanged: (s) =>
                      controller.set(view.copyWith(layout: s.first)),
                ),
                const SizedBox(height: TahfeezSpacing.sm),
                SwitchListTile(
                  key: const ValueKey('tafsir-show-translation'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tafsirShowTranslation),
                  value: view.showTranslation,
                  onChanged: (v) =>
                      controller.set(view.copyWith(showTranslation: v)),
                ),
                SwitchListTile(
                  key: const ValueKey('tafsir-show-transliteration'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tafsirShowTransliteration),
                  value: view.showTransliteration,
                  onChanged: (v) =>
                      controller.set(view.copyWith(showTransliteration: v)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTextSizeSheet(BuildContext context, WidgetRef ref) {
    showTahfeezModalBottomSheet(
      context: context,
      title: AppLocalizations.of(context).tafsirTextSize,
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
      message: AppLocalizations.of(context).tafsirInstall,
      action: TextButton(
        onPressed: () => showTafsirPacksSheet(context),
        child: Text(AppLocalizations.of(context).tafsirBrowse),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TahfeezSpacing.md,
        children: [
          _AyahTafsirBlock(
            tafsirId: tafsirId,
            verse: verse,
            textScale: textScale,
          ),
          _TafsirAttribution(tafsirId: tafsirId),
        ],
      ),
    );
  }
}

/// Ayah after ayah from [start] to the end of the Quran, scrolled through
/// (built as they come into view).
class _ContinuousTafsir extends StatelessWidget {
  const _ContinuousTafsir({
    required this.tafsirId,
    required this.start,
    required this.textScale,
  });

  final String tafsirId;
  final VerseRef start;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final first = globalAyahNumber(start.chapterNo * 1000 + start.verseNo);
    return ListView.separated(
      key: const ValueKey('tafsir-continuous'),
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      itemCount: ayahTotal - first + 2,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox(height: TahfeezSpacing.sm)
          : const Divider(height: TahfeezSpacing.xl),
      itemBuilder: (context, i) {
        if (i == 0) return _TafsirAttribution(tafsirId: tafsirId);
        final id = ayahIdAtGlobal(first + i - 1);
        final verse = (chapterNo: id ~/ 1000, verseNo: id % 1000);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: TahfeezSpacing.sm,
          children: [
            Text(
              '${verse.chapterNo}:${verse.verseNo}',
              key: ValueKey('tafsir-ref-${verse.chapterNo}:${verse.verseNo}'),
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            _AyahTafsirBlock(
              tafsirId: tafsirId,
              verse: verse,
              textScale: textScale,
            ),
          ],
        );
      },
    );
  }
}

/// One ayah: its text, then (as the view says) its translations and its
/// transliteration, then the tafsir's commentary on it.
class _AyahTafsirBlock extends ConsumerWidget {
  const _AyahTafsirBlock({
    required this.tafsirId,
    required this.verse,
    required this.textScale,
  });

  final String tafsirId;
  final VerseRef verse;
  final double textScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tafsirReaderPreferencesProvider);
    final ayahId = verse.chapterNo * 1000 + verse.verseNo;
    final verseTextAsync = ref.watch(
      tafsirVerseTextProvider(
        chapterNo: verse.chapterNo,
        verseNo: verse.verseNo,
        tafsirId: tafsirId,
      ),
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TahfeezSpacing.md,
      children: [
        // The ayah itself, above its commentary.
        _AyahText(ayahId: ayahId),
        if (view.showTransliteration) _Transliteration(ayahId: ayahId),
        if (view.showTranslation) _Translations(ayahId: ayahId),
        verseTextAsync.when(
          data: (text) => text == null
              ? TahfeezEmptyView(
                  icon: Icons.menu_book_outlined,
                  message: AppLocalizations.of(context).tafsirNoCommentary,
                )
              : Text(
                  text.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize:
                        (theme.textTheme.bodyLarge?.fontSize ?? 16) * textScale,
                    height: 1.6,
                  ),
                ),
          loading: () => const TahfeezLoadingView(),
          error: (_, _) => TahfeezErrorView(
            message: AppLocalizations.of(context).tafsirLoadError,
          ),
        ),
      ],
    );
  }
}

/// The ayah's transliteration (the word-by-word pack's, joined).
class _Transliteration extends ConsumerWidget {
  const _Transliteration({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(ayahTransliterationProvider(ayahId)).value;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Text(
      text,
      key: ValueKey('tafsir-transliteration-$ayahId'),
      textDirection: TextDirection.ltr,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }
}

/// The ayah's chosen translations (Settings), each with its translator.
class _Translations extends ConsumerWidget {
  const _Translations({required this.ayahId});

  final int ayahId;

  static const _rtl = {'ar', 'ur', 'fa', 'he', 'ps', 'sd', 'ug', 'ckb'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = ref.watch(ayahTranslationsProvider(ayahId)).value;
    if (texts == null || texts.isEmpty) return const SizedBox.shrink();
    final books = ref.watch(_translationBooks).value ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        for (final entry in texts.entries)
          TranslationBlock(
            verseText: entry.value,
            authorName: books[entry.key]?.author ?? entry.key,
            inlineFootnotes: true,
            textDirection: _rtl.contains(books[entry.key]?.languageCode)
                ? TextDirection.rtl
                : TextDirection.ltr,
          ),
      ],
    );
  }
}

final _translationBooks = FutureProvider.autoDispose((ref) async {
  final slugs = ref.watch(translationSelectionControllerProvider);
  final repository = ref.watch(translationRepositoryProvider);
  final books = <String, TranslationBook>{};
  for (final slug in slugs) {
    final book = await repository.getInstalledTranslation(slug);
    if (book != null) books[slug] = book;
  }
  return books;
});

/// The tafsir's name and author.
class _TafsirAttribution extends ConsumerWidget {
  const _TafsirAttribution({required this.tafsirId});

  final String tafsirId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final work = ref.watch(_tafsirWorkForId(tafsirId)).value;
    if (work == null) return const SizedBox.shrink();
    return Text(
      '${work.displayName} — ${work.author}',
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// The ayah's canonical text, in the Quran-text font (as the ayah sheet
/// shows it).
class _AyahText extends ConsumerWidget {
  const _AyahText({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(canonicalAyahTextProvider(ayahId: ayahId)).value;
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('tafsir-ayah'),
      width: double.infinity,
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TahfeezRadii.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: quranTextStyle(
          color: scheme.onSurface,
          fontFamily: 'Scheherazade New',
          fontSize: 26,
        ),
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
              label: Text(AppLocalizations.of(context).commonPrevious),
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
              label: Text(AppLocalizations.of(context).commonNext),
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
