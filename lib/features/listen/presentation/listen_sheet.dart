import '../../guide/guide.dart';

import 'dart:async';

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
import '../../../quran/application/meaning_defaults.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../../recitation/presentation/recitation_loop_sheet.dart'
    show CountStepper, VersePicker;
import '../application/listen_options.dart';
import '../application/quran_audio_player.dart';
import '../application/reciter_controller.dart';
import '../application/reciter_downloads.dart';
import '../domain/quran_audio_sources.dart';
import '../../../core/ui/sheet_actions.dart';

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
                        _ReciterRow(
                          reciter: r,
                          key: ValueKey('reciter-${r.edition}'),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// [reciter]'s name in the UI language: Arabic script for the languages
/// written in it (Arabic, Urdu, Persian).
String reciterName(BuildContext context, Reciter reciter) =>
    usesArabicScript(Localizations.localeOf(context).languageCode)
    ? reciter.nameAr
    : reciter.nameEn;

class _ListenSheet extends ConsumerStatefulWidget {
  const _ListenSheet({this.from});

  final VerseRef? from;

  @override
  ConsumerState<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends ConsumerState<_ListenSheet> {
  VerseRef? _from, _to;

  /// The menu's choices, each saved as soon as it changes.
  ListenOptions get _options => ref.read(listenOptionsProvider);
  set _options(ListenOptions options) =>
      ref.read(listenOptionsProvider.notifier).set(options);

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
          GuideTarget(
            id: 'listen-reciter',
            child: TahfeezCard(
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
          ),
          GuideTarget(
            id: 'listen-range',
            child: TahfeezCard(
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
                    onAyah: (v) =>
                        _setTo((chapterNo: to.chapterNo, verseNo: v)),
                  ),
                ],
              ),
            ),
          ),
          GuideTarget(
            id: 'listen-repeats',
            child: TahfeezCard(
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
          ),
          // The speed of all listening (as in Follow along), kept for next
          // time.
          TahfeezCard(
            key: const ValueKey('listen-speed-choice'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label(l10n.listenSpeed),
                Wrap(
                  spacing: TahfeezSpacing.sm,
                  runSpacing: TahfeezSpacing.sm,
                  children: [
                    for (final speed in listenSpeeds)
                      ChoiceChip(
                        key: ValueKey('listen-speed-$speed'),
                        showCheckmark: false,
                        label: Text(
                          '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                        ),
                        selected:
                            (ref.watch(listenSpeedProvider) - speed).abs() <
                            0.01,
                        onSelected: (_) =>
                            ref.read(listenSpeedProvider.notifier).set(speed),
                      ),
                  ],
                ),
              ],
            ),
          ),
          GuideTarget(
            id: 'listen-options',
            child: TahfeezCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    key: const ValueKey('listen-continue'),
                    title: Text(l10n.listenContinue),
                    value: _options.continueToNextSurahs,
                    onChanged: (on) => setState(
                      () => _options = _options.copyWith(
                        continueToNextSurahs: on,
                      ),
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
          ),
          SheetActions(
            primary: GuideTarget(
              id: 'listen-play',
              child: FilledButton.icon(
                key: const ValueKey('listen-play'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _play,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.listenPlay),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One reciter in the picker: chosen with its radio (or a tap on the row);
/// its recitation's size, and — where downloads are possible — download,
/// its progress (tap to stop), then delete.
class _ReciterRow extends ConsumerWidget {
  const _ReciterRow({super.key, required this.reciter});

  final Reciter reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final downloads = ref.read(reciterDownloadsProvider.notifier);
    final d = ref.watch(
      reciterDownloadsProvider.select((all) => all[reciter.edition]),
    );
    final size = reciterDownloadSize(reciter);
    final status = switch (d) {
      _ when !downloads.supported => null,
      ReciterDownload(complete: true) => l10n.listenDownloaded,
      ReciterDownload(failed: true) => l10n.listenDownloadFailed,
      ReciterDownload(:final progress, :final juz?, downloading: true) =>
        '${l10n.homeContinueReadingJuz(juz)} · ${(progress * 100).floor()}%',
      ReciterDownload(:final progress, :final surah?, downloading: true) =>
        '${_surahName(ref, l10n, surah)} · ${(progress * 100).floor()}%',
      ReciterDownload(:final progress, downloading: true) =>
        '${(progress * 100).floor()}%',
      ReciterDownload(:final files) when files > 0 => l10n.listenDownloadedPart(
        (files * 100 / 6236).ceil(),
      ),
      _ => null,
    };
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 4),
      leading: Radio<String>(value: reciter.edition),
      title: Text(reciterName(context, reciter)),
      subtitle: Text(
        [?size, ?status].join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: d?.failed ?? false
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: downloads.supported
          ? _DownloadButton(reciter: reciter, download: d, size: size)
          : null,
      onTap: () =>
          RadioGroup.maybeOf<String>(context)?.onChanged(reciter.edition),
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({
    required this.reciter,
    required this.download,
    required this.size,
  });

  final Reciter reciter;
  final ReciterDownload? download;
  final String? size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final downloads = ref.read(reciterDownloadsProvider.notifier);
    final d = download;
    if (d != null && d.downloading) {
      return IconButton(
        key: ValueKey('reciter-download-stop-${reciter.edition}'),
        tooltip: l10n.listenDownloadStop,
        onPressed: () => downloads.cancel(reciter.edition),
        icon: SizedBox.square(
          dimension: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: d.progress.clamp(0.02, 1.0),
                strokeWidth: 3,
              ),
              const Icon(Icons.stop_rounded, size: 14),
            ],
          ),
        ),
      );
    }
    if (d != null && d.complete) {
      return IconButton(
        key: ValueKey('reciter-download-delete-${reciter.edition}'),
        tooltip: l10n.listenDownloadDelete,
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () async {
          final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.listenDownloadDeleteTitle),
              content: Text(
                l10n.listenDownloadDeleteBody(
                  reciterName(context, reciter),
                  size ?? '',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  key: const ValueKey('reciter-download-delete-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.commonDelete),
                ),
              ],
            ),
          );
          if (yes ?? false) await downloads.delete(reciter.edition);
        },
      );
    }
    return IconButton(
      key: ValueKey('reciter-download-${reciter.edition}'),
      tooltip: l10n.listenDownload,
      icon: const Icon(Icons.download_rounded),
      onPressed: () => _showDownloadChoices(context, reciter),
    );
  }
}

/// A surah's name in the app's language (its number while the names load).
String _surahName(WidgetRef ref, AppLocalizations l10n, int surah) {
  final names = ref.watch(indexedSurahsProvider).value;
  final named = [
    for (final s in names ?? const <IndexedSurah>[])
      if (s.surah.surahNo == surah) s.localizedName ?? s.arabicName,
  ].firstOrNull;
  return named ?? l10n.homeContinueReadingSurah(surah);
}

/// What to download of [reciter]: the whole Quran, or — in two tabs — one
/// juz or one surah (each with its size; a check on what is already here).
/// Deletes what is here, too.
Future<void> _showDownloadChoices(
  BuildContext context,
  Reciter reciter,
) => showTahfeezModalBottomSheet<void>(
  context: context,
  title: reciterName(context, reciter),
  builder: (context) => Consumer(
    builder: (context, ref, _) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final downloads = ref.read(reciterDownloadsProvider.notifier);
      final d = ref.watch(
        reciterDownloadsProvider.select((all) => all[reciter.edition]),
      );
      final check = Icon(
        Icons.check_circle_rounded,
        color: theme.colorScheme.primary,
      );
      void start({int? juz, int? surah}) {
        unawaited(downloads.download(reciter.edition, juz: juz, surah: surah));
        Navigator.of(context).pop();
      }

      Widget part({
        required Key key,
        required String title,
        required String? size,
        required bool here,
        required VoidCallback onTap,
      }) => ListTile(
        key: key,
        dense: true,
        title: Text(title),
        subtitle: Text(size ?? ''),
        trailing: here ? check : const Icon(Icons.download_rounded, size: 20),
        onTap: here ? null : onTap,
      );

      return DefaultTabController(
        length: 2,
        child: Column(
          children: [
            ListTile(
              key: const ValueKey('download-whole'),
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(l10n.listenDownloadWhole),
              subtitle: Text(reciterDownloadSize(reciter) ?? ''),
              trailing: d?.complete ?? false
                  ? check
                  : const Icon(Icons.download_rounded),
              onTap: d?.complete ?? false ? null : () => start(),
            ),
            TabBar(
              tabs: [
                Tab(
                  key: const ValueKey('download-tab-juz'),
                  text: l10n.quranTabJuz,
                ),
                Tab(
                  key: const ValueKey('download-tab-surah'),
                  text: l10n.quranTabSurah,
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PartsList(
                    count: 30,
                    builder: (i) => part(
                      key: ValueKey('download-juz-${i + 1}'),
                      title: l10n.homeContinueReadingJuz(i + 1),
                      size: juzDownloadSize(reciter, i + 1),
                      here: downloads.juzComplete(reciter.edition, i + 1),
                      onTap: () => start(juz: i + 1),
                    ),
                  ),
                  _PartsList(
                    count: 114,
                    builder: (i) => part(
                      key: ValueKey('download-surah-${i + 1}'),
                      title: '${i + 1}. ${_surahName(ref, l10n, i + 1)}',
                      size: surahDownloadSize(reciter, i + 1),
                      here: downloads.surahComplete(reciter.edition, i + 1),
                      onTap: () => start(surah: i + 1),
                    ),
                  ),
                ],
              ),
            ),
            if ((d?.files ?? 0) > 0) ...[
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('download-delete-all'),
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  l10n.listenDownloadDeleteAll,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  unawaited(downloads.delete(reciter.edition));
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      );
    },
  ),
);

/// The download sheet's juz or surahs: a list on a phone, two or three
/// columns where the sheet is wider (a tablet, a phone on its side) — each
/// row as tall as its tallest entry, so long names and large text wrap
/// rather than overflow.
class _PartsList extends StatelessWidget {
  const _PartsList({required this.count, required this.builder});

  final int count;
  final Widget Function(int index) builder;

  /// The narrowest a column gets before there is one fewer.
  static const _columnWidth = 280.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = (box.maxWidth / _columnWidth).floor().clamp(1, 3);
      if (columns == 1) {
        return ListView.builder(
          itemCount: count,
          itemBuilder: (context, i) => builder(i),
        );
      }
      return ListView.builder(
        itemCount: (count / columns).ceil(),
        itemBuilder: (context, row) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++)
                Expanded(
                  child: row * columns + c < count
                      ? builder(row * columns + c)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      );
    },
  );
}
