import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../mushaf/application/mushaf_hide_mode.dart';
import '../../mushaf/application/mushaf_page_verses.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper, VersePicker;
import '../application/listen_options.dart';
import '../application/quran_audio_player.dart';
import '../application/reciter_controller.dart';
import '../domain/quran_audio_sources.dart';

/// The Mushaf's Listen menu: what to play (a range, from [from] if given,
/// else from the page on screen to its surah's end), how often, by which
/// reciter, and whether to follow the pages and highlight the ayah.
Future<void> showListenSheet(BuildContext context, {VerseRef? from}) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).listenMenuTitle,
      builder: (context) => _ListenSheet(from: from),
    );

/// The reciters, to pick one (Settings, the Listen and Follow along
/// menus), with a search box over their English and Arabic names.
Future<void> showReciterSheet(BuildContext context) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).listenReciter,
      builder: (context) => const _ReciterPicker(),
    );

class _ReciterPicker extends ConsumerStatefulWidget {
  const _ReciterPicker();

  @override
  ConsumerState<_ReciterPicker> createState() => _ReciterPickerState();
}

class _ReciterPickerState extends ConsumerState<_ReciterPicker> {
  var _query = '';

  /// Lower case, without Arabic vowel marks or tatweel, alef forms as one,
  /// and Latin punctuation and spaces dropped: "Al-Husary", "الحُصري" and
  /// "husary" alike.
  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r"[-'’ʿʾ.\s]"), '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final q = _fold(_query);
    final shown = [
      for (final r in reciters)
        if (q.isEmpty ||
            _fold(r.nameEn).contains(q) ||
            _fold(r.nameAr).contains(q))
          r,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            0,
            TahfeezSpacing.md,
            TahfeezSpacing.sm,
          ),
          child: TextField(
            key: const ValueKey('reciter-search'),
            onChanged: (text) => setState(() => _query = text),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.listenSearchReciters,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TahfeezRadii.pill),
              ),
            ),
          ),
        ),
        Flexible(
          child: RadioGroup<String>(
            groupValue: ref.watch(reciterProvider),
            onChanged: (edition) {
              if (edition == null) return;
              ref.read(reciterProvider.notifier).select(edition);
              Navigator.of(context).pop();
            },
            child: shown.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(TahfeezSpacing.lg),
                    child: Text(l10n.listenNoReciters),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(
                      TahfeezSpacing.sm,
                      0,
                      TahfeezSpacing.sm,
                      TahfeezSpacing.md,
                    ),
                    children: [
                      for (final r in shown)
                        RadioListTile<String>(
                          key: ValueKey('reciter-${r.edition}'),
                          value: r.edition,
                          title: Text(reciterName(context, r)),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// [reciter]'s name in the UI language: Arabic script for Arabic and Urdu.
String reciterName(BuildContext context, Reciter reciter) =>
    switch (Localizations.localeOf(context).languageCode) {
      'ar' || 'ur' => reciter.nameAr,
      _ => reciter.nameEn,
    };

class _ListenSheet extends ConsumerStatefulWidget {
  const _ListenSheet({this.from});

  final VerseRef? from;

  @override
  ConsumerState<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends ConsumerState<_ListenSheet> {
  VerseRef? _from, _to;
  late ListenOptions _options = ref.read(listenOptionsProvider);

  static int _id(VerseRef v) => v.chapterNo * 1000 + v.verseNo;

  /// From [widget.from], else the page on screen's first ayah, to the end
  /// of its surah.
  void _defaults() {
    if (_from != null) return;
    var first = widget.from;
    if (first == null) {
      final location = ref.read(mushafRecitationTargetProvider)?.location;
      final page = location is QuranLocationPage
          ? firstVisiblePage(
              location.pageNumber,
              spread: ref.read(fullBleedContentProvider),
            )
          : null;
      first =
          ref.read(mushafPageVersesProvider)[page]?.first ??
          (chapterNo: 1, verseNo: 1);
    }
    _from = first;
    _to = (
      chapterNo: first.chapterNo,
      verseNo: surahAyahCounts[first.chapterNo - 1],
    );
  }

  void _setFrom(VerseRef v) => setState(() {
    _from = v;
    if (_id(_to!) < _id(v)) {
      _to = (chapterNo: v.chapterNo, verseNo: surahAyahCounts[v.chapterNo - 1]);
    }
  });

  void _setTo(VerseRef v) => setState(() {
    _to = v;
    if (_id(v) < _id(_from!)) _from = (chapterNo: v.chapterNo, verseNo: 1);
  });

  Future<void> _play() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    ref.read(listenOptionsProvider.notifier).set(_options);
    Navigator.of(context).pop();
    final played = await ref
        .read(quranAudioPlayerProvider.notifier)
        .playRange(_id(_from!), _id(_to!), options: _options);
    if (!played) showListenOffline(messenger, l10n.listenOffline);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final surahs = ref.watch(indexedSurahsProvider).value;
    if (surahs == null) {
      return const Padding(
        padding: EdgeInsets.all(TahfeezSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    _defaults();
    final from = _from!, to = _to!;
    final reciter = reciterFor(ref.watch(reciterProvider));
    final hideMode = ref.watch(mushafHideModeProvider).enabled;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    Widget stepper(String text, String id, int value, ValueChanged<int> set) =>
        Row(
          children: [
            Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
            CountStepper(
              id: id,
              value: value,
              min: 1,
              max: 10,
              onChanged: (n) => setState(() => set(n)),
            ),
          ],
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TahfeezSpacing.smPlus,
        children: [
          TahfeezCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('listen-reciter'),
              leading: const Icon(Icons.record_voice_over_outlined),
              title: Text(l10n.listenReciter),
              subtitle: Text(reciterName(context, reciter)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showReciterSheet(context),
            ),
          ),
          TahfeezCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.recFrom),
                VersePicker(
                  id: 'listen-from',
                  surahs: surahs,
                  value: from,
                  ayahCount: surahAyahCounts[from.chapterNo - 1],
                  onSurah: (c) => _setFrom((chapterNo: c, verseNo: 1)),
                  onAyah: (v) =>
                      _setFrom((chapterNo: from.chapterNo, verseNo: v)),
                ),
                const SizedBox(height: TahfeezSpacing.md),
                label(l10n.recTo),
                VersePicker(
                  id: 'listen-to',
                  surahs: surahs,
                  value: to,
                  ayahCount: surahAyahCounts[to.chapterNo - 1],
                  onSurah: (c) =>
                      _setTo((chapterNo: c, verseNo: surahAyahCounts[c - 1])),
                  onAyah: (v) => _setTo((chapterNo: to.chapterNo, verseNo: v)),
                ),
              ],
            ),
          ),
          TahfeezCard(
            child: Column(
              spacing: TahfeezSpacing.sm,
              children: [
                stepper(
                  l10n.listenRepeatAyah,
                  'listen-repeat-ayah',
                  _options.ayahRepeats,
                  (n) => _options = _options.copyWith(ayahRepeats: n),
                ),
                stepper(
                  l10n.listenRepeatRange,
                  'listen-repeat-range',
                  _options.rangeRepeats,
                  (n) => _options = _options.copyWith(rangeRepeats: n),
                ),
              ],
            ),
          ),
          TahfeezCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('listen-continue'),
                  title: Text(l10n.listenContinue),
                  value: _options.continueToNextSurahs,
                  onChanged: (on) => setState(
                    () =>
                        _options = _options.copyWith(continueToNextSurahs: on),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('listen-follow'),
                  title: Text(l10n.listenFollow),
                  value: _options.followPages,
                  onChanged: (on) => setState(
                    () => _options = _options.copyWith(followPages: on),
                  ),
                ),
                SwitchListTile(
                  key: const ValueKey('listen-highlight'),
                  title: Text(l10n.listenHighlight),
                  subtitle: hideMode ? Text(l10n.listenRevealNote) : null,
                  value: _options.highlight,
                  onChanged: (on) => setState(
                    () => _options = _options.copyWith(highlight: on),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('listen-play'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _play,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.listenPlay),
          ),
        ],
      ),
    );
  }
}
