import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../core/theme/tahfeez_content_widths.dart';
import '../../../core/ui/bar_space.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/search_normalizer.dart';
import '../../athkar/application/athkar_progress.dart';
import '../../athkar/data/athkar_source.dart';
import '../../athkar/domain/athkar.dart';
import '../../athkar/presentation/athkar_screen.dart';
import '../../home/presentation/home_sky.dart';
import '../../mushaf/application/reader_mode.dart';
import '../../quran/application/quran_index_providers.dart';
import '../application/duas_providers.dart';
import '../application/saved_supplications.dart';
import '../domain/duas.dart';
import 'saved_button.dart';

/// Duas (owner, 2026-11-23: from the side menu and Home, as Athkar): the
/// Quran's duas and Hisn al-Muslim's, in sections — health, provision,
/// marriage, children… — as tiles; searched; the bookmarked ones first.
class DuasScreen extends ConsumerStatefulWidget {
  const DuasScreen({super.key});

  @override
  ConsumerState<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends ConsumerState<DuasScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DuasScaffold(
      title: l10n.duasTitle,
      body: Column(
        children: [
          AthkarSearchBar(
            controller: _search,
            query: _query,
            hint: l10n.duasSearchHint,
            fieldKey: const ValueKey('duas-search'),
            onChanged: (q) => setState(() => _query = q),
          ),
          Expanded(child: _DuasContent(query: _query)),
        ],
      ),
    );
  }
}

/// The sky, the bar with [title], the content at most the reading width.
class _DuasScaffold extends StatelessWidget {
  const _DuasScaffold({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) => SkyBackdrop(
    child: Scaffold(
      appBar: TahfeezAppBar(title: Text(title), centerTitle: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TahfeezContentWidth.maxReading,
            ),
            child: body,
          ),
        ),
      ),
    ),
  );
}

class _DuasContent extends ConsumerWidget {
  const _DuasContent({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = ref.watch(athkarBookProvider).value;
    final counts = ref.watch(athkarProgressProvider);
    final saved = ref.watch(savedSupplicationsProvider);
    final hadiths = ref.watch(hadithDuasProvider).value ?? const [];
    final q = const SearchNormalizer().normalizeArabic(query.trim());
    final List<Widget> slivers;
    if (q.isNotEmpty) {
      final index = ref.watch(duasSearchIndexProvider).value;
      final groups = [
        for (final g in DuaGroup.values)
          if (const SearchNormalizer()
              .normalizeArabic(g.title(l10n))
              .contains(q))
            g,
      ];
      final quran = savedFirst(
        [
          for (final d in DuaGroup.allQuran)
            if (index?.quran[d]?.contains(q) ?? false) d,
        ],
        saved,
        (d) => d.savedKey,
      );
      final found = savedFirst(
        [
          for (final h in hadiths)
            if (index?.hadiths[h.savedKey]?.contains(q) ?? false) h,
        ],
        saved,
        (h) => h.savedKey,
      );
      final chapters = savedFirst(
        [
          if (book != null && index != null)
            for (final e in index.chapters.entries)
              if (e.value.contains(q)) ?book.category(e.key),
        ],
        saved,
        (c) => SavedSupplications.chapterKey(c.id),
      );
      slivers =
          groups.isEmpty && quran.isEmpty && found.isEmpty && chapters.isEmpty
          ? [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: TahfeezSpacing.xl),
                  child: index == null
                      ? const Center(child: CircularProgressIndicator())
                      : TahfeezEmptyView(
                          message: l10n.searchNoResults(query.trim()),
                        ),
                ),
              ),
            ]
          : [
              if (groups.isNotEmpty) _groupGrid(context, groups, book, hadiths),
              ..._quranList(quran),
              ..._hadithList(found),
              if (chapters.isNotEmpty)
                _chapterGrid(context, chapters, counts, top: true),
            ];
    } else {
      // The bookmarked first (owner, 2026-11-23): duas from the Quran, and
      // the chapters in Duas' sections.
      final inDuas = {for (final g in DuaGroup.values) ...g.chapters};
      final quran = [for (final k in saved) ?DuaGroup.quranOf(k)];
      final savedHadiths = [
        for (final k in saved)
          for (final h in hadiths)
            if (h.savedKey == k) h,
      ];
      final chapters = [
        if (book != null)
          for (final k in saved)
            if (SavedSupplications.chapterOf(k) case final id?
                when inDuas.contains(id))
              ?book.category(id),
      ];
      final anySaved =
          quran.isNotEmpty || savedHadiths.isNotEmpty || chapters.isNotEmpty;
      slivers = [
        if (anySaved) ...[
          SliverToBoxAdapter(child: SavedHeading(l10n.supplicationsBookmarked)),
          ..._quranList(quran),
          ..._hadithList(savedHadiths),
          if (chapters.isNotEmpty)
            _chapterGrid(
              context,
              chapters,
              counts,
              top: quran.isNotEmpty || savedHadiths.isNotEmpty,
            ),
          SliverToBoxAdapter(
            child: SavedHeading(l10n.athkarSections, top: TahfeezSpacing.lg),
          ),
        ],
        _groupGrid(context, DuaGroup.values, book, hadiths),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: TahfeezSpacing.md),
            child: Text(
              l10n.duasSource,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }
    return CustomScrollView(
      key: const ValueKey('duas-list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: withBarSpace(
            context,
            const EdgeInsets.all(TahfeezSpacing.md),
          ),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }
}

/// The sections' tiles: wide and low, two across (as Athkar's).
Widget _groupGrid(
  BuildContext context,
  List<DuaGroup> groups,
  AthkarBook? book,
  List<HadithDua> hadiths,
) => SliverGrid.builder(
  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(260),
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(108),
    crossAxisSpacing: TahfeezSpacing.sm,
    mainAxisSpacing: TahfeezSpacing.sm,
  ),
  itemCount: groups.length,
  itemBuilder: (context, i) =>
      _GroupTile(group: groups[i], book: book, hadiths: hadiths),
);

/// Quran duas' cards, one under the other.
List<Widget> _quranList(List<QuranDua> duas) => [
  for (final d in duas)
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
        child: QuranDuaCard(dua: d),
      ),
    ),
];

/// Hadith duas' tiles (as Hisn al-Muslim's chapters'), a little space
/// under them.
List<Widget> _hadithList(List<HadithDua> duas) => [
  if (duas.isNotEmpty)
    SliverPadding(
      padding: const EdgeInsets.only(bottom: TahfeezSpacing.sm),
      sliver: Builder(
        builder: (context) => SliverGrid.builder(
          gridDelegate: athkarTileGrid(context),
          itemCount: duas.length,
          itemBuilder: (context, i) => HadithDuaTile(dua: duas[i]),
        ),
      ),
    ),
];

/// Hisn al-Muslim chapters' tiles (Athkar's).
Widget _chapterGrid(
  BuildContext context,
  List<AthkarCategory> chapters,
  Map<int, int> counts, {
  bool top = false,
}) => SliverPadding(
  padding: EdgeInsets.only(top: top ? TahfeezSpacing.sm : 0),
  sliver: SliverGrid.builder(
    gridDelegate: athkarTileGrid(context),
    itemCount: chapters.length,
    itemBuilder: (context, i) =>
        AthkarCategoryTile(category: chapters[i], counts: counts),
  ),
);

/// How many duas [group] has: its Quran duas, its hadiths and its
/// chapters' athkar.
int duaCount(DuaGroup group, AthkarBook? book, List<HadithDua> hadiths) =>
    group.quran.length +
    group.hadithsOf(hadiths).length +
    group.chapters.fold(
      0,
      (n, id) => n + (book?.category(id)?.athkar.length ?? 1),
    );

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.book,
    required this.hadiths,
  });

  final DuaGroup group;
  final AthkarBook? book;
  final List<HadithDua> hadiths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TahfeezCard(
      key: ValueKey('duas-group-${group.name}'),
      padding: const EdgeInsets.all(TahfeezSpacing.sm),
      onTap: () => context.push(AppRoutes.duasGroup(group.name)),
      child: Row(
        spacing: TahfeezSpacing.sm,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primaryContainer,
            ),
            child: Icon(group.icon, size: 20, color: scheme.onPrimaryContainer),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title(l10n),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  l10n.duasCount(duaCount(group, book, hadiths)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A section's duas: the Quran's, as cards, then Hisn al-Muslim's chapters
/// as tiles — the bookmarked ones first in each.
class DuaGroupScreen extends ConsumerWidget {
  const DuaGroupScreen({super.key, required this.group});

  final DuaGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(athkarBookProvider).value;
    final counts = ref.watch(athkarProgressProvider);
    final saved = ref.watch(savedSupplicationsProvider);
    final quran = savedFirst(group.quran, saved, (d) => d.savedKey);
    final hadiths = savedFirst(
      group.hadithsOf(ref.watch(hadithDuasProvider).value ?? const []),
      saved,
      (h) => h.savedKey,
    );
    final chapters = savedFirst(
      [
        if (book != null)
          for (final id in group.chapters) ?book.category(id),
      ],
      saved,
      (c) => SavedSupplications.chapterKey(c.id),
    );
    return _DuasScaffold(
      title: l10n.duasTitle,
      body: CustomScrollView(
        key: const ValueKey('duas-group-list'),
        slivers: [
          SliverPadding(
            padding: withBarSpace(
              context,
              const EdgeInsets.all(TahfeezSpacing.md),
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(child: AthkarHeading(group.title(l10n))),
                if (quran.isNotEmpty) ...[
                  SliverToBoxAdapter(child: SavedHeading(l10n.duasFromQuran)),
                  ..._quranList(quran),
                ],
                if (hadiths.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SavedHeading(
                      l10n.duasFromSunnah,
                      top: quran.isEmpty ? 0 : TahfeezSpacing.md,
                    ),
                  ),
                  ..._hadithList(hadiths),
                ],
                if (chapters.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SavedHeading(
                      l10n.duasFromHisn,
                      top: quran.isEmpty && hadiths.isEmpty
                          ? 0
                          : TahfeezSpacing.md,
                    ),
                  ),
                  _chapterGrid(context, chapters, counts),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Arabic-Indic digits for an ayah's number.
String _arabicDigits(int n) =>
    '$n'.split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join();

/// Languages written right to left (a translation's direction).
const _rtl = {'ar', 'ur', 'fa', 'ckb', 'ps'};

/// A dua from the Quran: its surah and ayah, its ayahs in the Quran font
/// (from the installed dataset), the shown translation; bookmarked from its
/// corner; a tap opens it in the Mushaf.
class QuranDuaCard extends ConsumerWidget {
  const QuranDuaCard({super.key, required this.dua});

  final QuranDua dua;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = ref.watch(quranDuaTextProvider(dua));
    final names = ref.watch(indexedSurahsProvider).value;
    String? name;
    for (final s in names ?? const <IndexedSurah>[]) {
      if (s.surah.surahNo == dua.surah) {
        name = s.localizedName ?? s.arabicName;
      }
    }
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    return TahfeezCard(
      key: ValueKey('dua-${dua.savedKey}'),
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        TahfeezSpacing.xs,
        TahfeezSpacing.xs,
        TahfeezSpacing.md,
      ),
      onTap: () =>
          goToQuranLocation(context, QuranLocation.ayah(dua.surah, dua.from)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name == null ? dua.reference : '$name · ${dua.reference}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              SavedSupplicationButton(dua.savedKey, compact: true),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: TahfeezSpacing.sm),
            child: switch (text) {
              AsyncData(value: final t?) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TahfeezSpacing.sm,
                children: [
                  Text(
                    [
                      for (var i = 0; i < t.ayahs.length; i++)
                        '${t.ayahs[i]} ﴿${_arabicDigits(dua.from + i)}﴾',
                    ].join(' '),
                    key: ValueKey('dua-text-${dua.savedKey}'),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.center,
                    style: quranTextStyle(
                      color: scheme.onSurface,
                      fontFamily: font,
                      fontSize: 24,
                    ).copyWith(height: 1.9),
                  ),
                  if (t.translations.isNotEmpty)
                    Text(
                      t.translations.join(' '),
                      textDirection: _rtl.contains(t.translationLanguage)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
              AsyncLoading() => const TahfeezCardSkeleton(lines: 2),
              _ => Text(dua.reference, style: theme.textTheme.bodyMedium),
            },
          ),
        ],
      ),
    );
  }
}

/// "Sahih al-Bukhari 6306", "Sahih Muslim 2721a" — the number left to
/// right whatever the language.
String hadithReference(AppLocalizations l10n, HadithDua dua) =>
    '${dua.book == 'bukhari' ? l10n.duasBukhari : l10n.duasMuslim} '
    '\u2066${dua.shownNumber}\u2069';

/// A dua from Sahih al-Bukhari or Sahih Muslim: its book and number, the
/// whole hadith in Arabic, and its translation in the app's language
/// (English where the source has none); bookmarked from its corner.
class HadithDuaCard extends ConsumerWidget {
  const HadithDuaCard({super.key, required this.dua});

  final HadithDua dua;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final translation = dua.translationIn(language);
    final shownLanguage = dua.translations.containsKey(language)
        ? language
        : 'en';
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    return TahfeezCard(
      key: ValueKey('dua-${dua.savedKey}'),
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        TahfeezSpacing.xs,
        TahfeezSpacing.xs,
        TahfeezSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hadithReference(l10n, dua),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ),
              SavedSupplicationButton(dua.savedKey, compact: true),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: TahfeezSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: TahfeezSpacing.sm,
              children: [
                Text(
                  dua.arabic,
                  key: ValueKey('dua-text-${dua.savedKey}'),
                  textDirection: TextDirection.rtl,
                  style: quranTextStyle(
                    color: scheme.onSurface,
                    fontFamily: font,
                    fontSize: 20,
                  ).copyWith(height: 1.8),
                ),
                if (translation != null)
                  Text(
                    translation,
                    textDirection: _rtl.contains(shownLanguage)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A hadith dua as a tile: its title, its book and number; bookmarked from
/// its corner; a tap opens it whole.
class HadithDuaTile extends StatelessWidget {
  const HadithDuaTile({super.key, required this.dua});

  final HadithDua dua;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    return TahfeezCard(
      key: ValueKey('dua-tile-${dua.savedKey}'),
      onTap: () => context.push(AppRoutes.duasHadith(dua.book, dua.number)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer,
                ),
                child: DuaHandsIcon(size: 22, color: scheme.onPrimaryContainer),
              ),
              const Spacer(),
              SavedSupplicationButton(dua.savedKey, compact: true),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dua.titleIn(language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                hadithReference(l10n, dua),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A hadith dua on its own page: its title, then the whole hadith.
class HadithDuaScreen extends ConsumerWidget {
  const HadithDuaScreen({super.key, required this.book, required this.number});

  final String book, number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final all = ref.watch(hadithDuasProvider);
    HadithDua? dua;
    for (final h in all.value ?? const <HadithDua>[]) {
      if (h.book == book && h.number == number) dua = h;
    }
    return _DuasScaffold(
      title: l10n.duasTitle,
      body: dua == null
          ? (all.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TahfeezEmptyView(message: l10n.athkarLoadError))
          : ListView(
              key: const ValueKey('duas-hadith'),
              padding: withBarSpace(
                context,
                const EdgeInsets.all(TahfeezSpacing.md),
              ),
              children: [
                AthkarHeading(dua.titleIn(language)),
                HadithDuaCard(dua: dua),
              ],
            ),
    );
  }
}
