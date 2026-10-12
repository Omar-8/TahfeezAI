import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/audio_models.dart';
import '../../core/core_providers.dart';
import '../../core/routing/app_routes.dart';
import '../../features/listen/application/listen_options.dart';
import '../../features/listen/application/quran_audio_player.dart';
import '../../features/listen/application/reciter_controller.dart';
import '../../features/listen/domain/quran_audio_sources.dart' show reciterFor;
import '../../features/listen/presentation/listen_sheet.dart';
import '../../features/quran/application/quran_index_providers.dart';
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
    // One ayah at a time: on to the ayah the reciter reaches.
    if (!continuous) {
      ref.listen(quranAudioPlayerProvider.select((n) => n?.ayahId), (
        previous,
        playing,
      ) {
        if (playing == null || playing == previous) return;
        if (playing == chapterNo * 1000 + verseNo) return;
        GoRouter.of(context).pushReplacement(
          '${AppRoutes.tafsir}/${playing ~/ 1000}/${playing % 1000}',
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: _TafsirTitle(opened: chapterNo * 1000 + verseNo),
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TafsirPlayerBar(),
          if (!continuous) _PrevNextBar(verse: _verse),
        ],
      ),
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

/// The whole Quran ayah after ayah, opened at [start]: scrolling down
/// goes on to the ayahs after it, scrolling up back to the ones before
/// (each built as it comes into view).
class _ContinuousTafsir extends ConsumerStatefulWidget {
  const _ContinuousTafsir({
    required this.tafsirId,
    required this.start,
    required this.textScale,
  });

  final String tafsirId;
  final VerseRef start;
  final double textScale;

  @override
  ConsumerState<_ContinuousTafsir> createState() => _ContinuousTafsirState();
}

class _ContinuousTafsirState extends ConsumerState<_ContinuousTafsir> {
  // Where the scroll view starts: [start] at the top, earlier ayahs above.
  final _center = UniqueKey();
  final _scroll = ScrollController();

  /// Each built ayah's key (by its number in the whole Quran), to scroll
  /// it into view.
  final _keys = <int, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the ayah [ayahId] into view: at once when built, else a screen
  /// at a time towards it until it is.
  Future<void> _follow(int ayahId) async {
    final target = globalAyahNumber(ayahId);
    for (var tries = 0; tries < 60 && mounted; tries++) {
      final built = _keys.entries.where((e) => e.value.currentContext != null);
      final at = _keys[target]?.currentContext;
      if (at != null && at.mounted) {
        await Scrollable.ensureVisible(
          at,
          alignment: 0.05,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
        return;
      }
      if (built.isEmpty || !_scroll.hasClients) return;
      final below = built.every((e) => e.key < target);
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + (below ? 1 : -1) * position.viewportDimension * 0.9)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Widget _ayah(BuildContext context, int global) {
    final id = ayahIdAtGlobal(global);
    final verse = (chapterNo: id ~/ 1000, verseNo: id % 1000);
    return Column(
      key: _keys.putIfAbsent(global, GlobalKey.new),
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
          tafsirId: widget.tafsirId,
          verse: verse,
          textScale: widget.textScale,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = globalAyahNumber(
      widget.start.chapterNo * 1000 + widget.start.verseNo,
    );
    // The reciter's ayah kept in view.
    ref.listen(quranAudioPlayerProvider.select((n) => n?.ayahId), (
      previous,
      playing,
    ) {
      if (playing != null && playing != previous) unawaited(_follow(playing));
    });
    const pad = EdgeInsets.symmetric(horizontal: TahfeezSpacing.md);
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (_) {
        // After the frame, once the ayahs are laid out where they moved.
        if (!_reportQueued) {
          _reportQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _reportQueued = false;
            if (mounted) _reportTop();
          });
        }
        return false;
      },
      child: CustomScrollView(
        key: const ValueKey('tafsir-continuous'),
        controller: _scroll,
        center: _center,
        slivers: [
          // Before [start], nearest first, growing upwards.
          SliverPadding(
            padding: pad,
            sliver: SliverList.builder(
              itemCount: first - 1,
              itemBuilder: (context, i) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ayah(context, first - 1 - i),
                  const Divider(height: TahfeezSpacing.xl),
                ],
              ),
            ),
          ),
          // [start] and after.
          SliverPadding(
            key: _center,
            padding: pad.copyWith(bottom: TahfeezSpacing.md),
            sliver: SliverList.builder(
              itemCount: ayahTotal - first + 1,
              itemBuilder: (context, i) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i == 0) ...[
                    const SizedBox(height: TahfeezSpacing.md),
                    _TafsirAttribution(tafsirId: widget.tafsirId),
                    const SizedBox(height: TahfeezSpacing.sm),
                  ] else
                    const Divider(height: TahfeezSpacing.xl),
                  _ayah(context, first + i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  var _reportQueued = false;

  /// The ayah at the top of the screen, for the title.
  void _reportTop() {
    final list = context.findRenderObject();
    if (list is! RenderBox) return;
    final top = list.localToGlobal(Offset.zero).dy;
    int? best;
    var bestY = double.negativeInfinity;
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy - top;
      // The last ayah starting in the screen's upper quarter, or above it.
      if (y <= list.size.height / 4 && y > bestY) {
        bestY = y;
        best = e.key;
      }
    }
    if (best != null) {
      ref.read(_tafsirTopAyahProvider.notifier).set(ayahIdAtGlobal(best));
    }
  }
}

/// Continuous: the ayah at the top of the screen (the title follows it).
class _TafsirTopAyah extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int ayahId) {
    if (state != ayahId) state = ayahId;
  }
}

final _tafsirTopAyahProvider =
    NotifierProvider.autoDispose<_TafsirTopAyah, int?>(_TafsirTopAyah.new);

/// The surah's name, and "Tafsir · surah:ayah" under it: the ayah opened,
/// or — scrolling through, continuous — the one at the top of the screen.
class _TafsirTitle extends ConsumerWidget {
  const _TafsirTitle({required this.opened});

  final int opened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuous =
        ref.watch(tafsirReaderPreferencesProvider).layout ==
        TafsirLayout.continuous;
    final ayahId =
        (continuous ? ref.watch(_tafsirTopAyahProvider) : null) ?? opened;
    final surahs = ref.watch(indexedSurahsProvider).value;
    final surah = surahs
        ?.where((s) => s.surah.surahNo == ayahId ~/ 1000)
        .firstOrNull;
    final name = surah == null
        ? null
        : surah.localizedName ?? surah.arabicName ?? '${ayahId ~/ 1000}';
    final theme = Theme.of(context);
    final sub = AppLocalizations.of(context)
        .tafsirTitle('${ayahId ~/ 1000}:${ayahId % 1000}');
    if (name == null) return Text(sub);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, key: const ValueKey('tafsir-surah-name')),
        Text(
          sub,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
    final playing = ref.watch(
      quranAudioPlayerProvider.select((n) => n?.ayahId == ayahId),
    );
    return Column(
      key: playing ? const ValueKey('tafsir-block-playing') : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TahfeezSpacing.md,
      children: [
        // The ayah itself, above its commentary.
        _AyahText(ayahId: ayahId),
        _PlayButtons(ayahId: ayahId),
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
    // Being recited: tinted, as the Mushaf highlights it.
    final playing = ref.watch(
      quranAudioPlayerProvider.select((n) => n?.ayahId == ayahId),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      key: ValueKey(playing ? 'tafsir-ayah-playing' : 'tafsir-ayah'),
      width: double.infinity,
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      decoration: BoxDecoration(
        color: playing ? scheme.primaryContainer : scheme.surfaceContainerLow,
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

/// Play the ayah, or from it on (the Mushaf's Listen menu, from here).
class _PlayButtons extends ConsumerWidget {
  const _PlayButtons({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: TahfeezSpacing.sm,
      children: [
        TextButton.icon(
          key: ValueKey('tafsir-play-$ayahId'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final played = await ref
                .read(quranAudioPlayerProvider.notifier)
                .playAyahs([
                  ayahId,
                ], options: const ListenOptions(followPages: false));
            if (!played) showListenOffline(messenger, l10n.listenOffline);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l10n.listenPlayAyah),
        ),
        TextButton.icon(
          key: ValueKey('tafsir-play-from-$ayahId'),
          onPressed: () => showListenSheet(
            context,
            from: (chapterNo: ayahId ~/ 1000, verseNo: ayahId % 1000),
          ),
          icon: const Icon(Icons.playlist_play_rounded),
          label: Text(l10n.listenPlayFrom),
        ),
      ],
    );
  }
}

/// While the reciter plays: which ayah, by whom, with pause / resume and
/// stop.
class _TafsirPlayerBar extends ConsumerWidget {
  const _TafsirPlayerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(quranAudioPlayerProvider);
    final ayahId = now?.ayahId;
    if (now == null || ayahId == null) return const SizedBox.shrink();
    final player = ref.read(quranAudioPlayerProvider.notifier);
    final audio = ref.watch(audioControllerProvider);
    final theme = Theme.of(context);
    final reciter = now.reciter ?? reciterFor(ref.watch(reciterProvider));
    return Material(
      key: const ValueKey('tafsir-player'),
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.xs,
          ),
          child: StreamBuilder<AudioPlaybackState>(
            stream: audio.state,
            initialData: const AudioPlaybackState(isPlaying: true),
            builder: (context, snapshot) {
              final playing = snapshot.data?.isPlaying ?? true;
              return Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: TahfeezSpacing.sm),
                  Expanded(
                    child: Text(
                      '${ayahId ~/ 1000}:${ayahId % 1000} · '
                      '${reciterName(context, reciter)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('tafsir-player-pause'),
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    tooltip: playing
                        ? AppLocalizations.of(context).recPause
                        : AppLocalizations.of(context).recResume,
                    onPressed: playing ? player.pause : player.resume,
                  ),
                  IconButton(
                    key: const ValueKey('tafsir-player-stop'),
                    icon: const Icon(Icons.stop_rounded),
                    tooltip: AppLocalizations.of(context).recStop,
                    onPressed: player.stop,
                  ),
                ],
              );
            },
          ),
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
