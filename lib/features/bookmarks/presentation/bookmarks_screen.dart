import 'package:flutter/material.dart';

import '../../../quran/presentation/surah_name_calligraphy.dart';
import '../../../core/ui/bar_space.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/quran_location_routing.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../core/theme/quran_text_style.dart';
import '../../../quran/application/canonical_ayah_word_text.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../quran/application/quran_index_providers.dart';
import '../../athkar/data/athkar_source.dart';
import '../../athkar/presentation/athkar_look.dart';
import '../../duas/application/saved_supplications.dart';
import '../../duas/application/duas_providers.dart';
import '../../duas/domain/duas.dart';
import '../../duas/presentation/duas_screen.dart' show hadithReference;
import '../application/bookmarks_controller.dart';

import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';

/// The bookmarked ayahs and surahs, newest first: open one in the Mushaf,
/// or remove it.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookmarks = ref.watch(bookmarksProvider);
    // The athkar and duas bookmarked (owner, 2026-11-23), under the Quran's.
    final saved = ref.watch(savedSupplicationsProvider);
    final headed = saved.isNotEmpty;
    // Its items: a heading (a String), a Quran bookmark, or a saved key.
    final items = <Object>[
      if (headed && bookmarks.isNotEmpty) _Heading(l10n.navQuran),
      ...bookmarks,
      if (headed) _Heading(l10n.bookmarksSupplications),
      for (final k in saved) _Saved(k),
    ];
    final names = {
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        s.surah.surahNo: s.localizedName ?? s.arabicName,
    };
    return Scaffold(
      appBar: TahfeezAppBar(
        title: Text(l10n.bookmarksTitle),
        centerTitle: false,
      ),
      body: bookmarks.isEmpty && saved.isEmpty
          ? TahfeezEmptyView(
              icon: Icons.bookmark_border_rounded,
              message: l10n.bookmarksEmpty,
              action: FilledButton.tonal(
                key: const ValueKey('bookmarks-open-quran'),
                onPressed: () => context.go(AppRoutes.quran),
                child: Text(l10n.bookmarksOpenQuran),
              ),
            )
          : ListView.separated(
              padding: withBarSpace(
                context,
                const EdgeInsets.all(TahfeezSpacing.md),
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: TahfeezSpacing.sm),
              itemBuilder: (context, i) {
                final item = items[i];
                if (item is _Heading) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: i == 0 ? 0 : TahfeezSpacing.md,
                    ),
                    child: Text(
                      item.text,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                if (item is _Saved) return _SavedTile(savedKey: item.key);
                final b = item as Bookmark;
                final surah =
                    names[b.surahNo] ??
                    l10n.homeContinueReadingSurah(b.surahNo);
                return TahfeezCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: ValueKey('bookmark-${b.ayahId ?? 's${b.surahNo}'}'),
                    leading: Icon(
                      b.isSurah
                          ? Icons.bookmarks_rounded
                          : Icons.bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      b.isSurah
                          ? surah
                          : l10n.homeDailyAyahReferenceNamed(
                              surah,
                              b.ayahId! % 1000,
                            ),
                    ),
                    subtitle: b.isSurah
                        ? Text(l10n.homeContinueReadingSurah(b.surahNo))
                        : _AyahOpening(ayahId: b.ayahId!),
                    // Its surah's name as the Mushaf writes it, then remove.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SurahNameCalligraphy(
                          surahNo: b.surahNo,
                          height: 22,
                          maxWidth: 76,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: l10n.bookmarkRemove,
                          onPressed: () {
                            final bookmarks = ref.read(
                              bookmarksProvider.notifier,
                            );
                            final index = ref
                                .read(bookmarksProvider)
                                .indexOf(b);
                            bookmarks.remove(b);
                            // Removed by a slip: put back.
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(l10n.bookmarkRemoved),
                                  action: SnackBarAction(
                                    label: l10n.commonUndo,
                                    onPressed: () =>
                                        bookmarks.restore(b, index),
                                  ),
                                ),
                              );
                          },
                        ),
                      ],
                    ),
                    onTap: () => goToQuranLocation(
                      context,
                      b.isSurah
                          ? QuranLocation.surah(b.surahNo)
                          : QuranLocation.ayah(b.surahNo, b.ayahId! % 1000),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// The ayah's opening words, in the Quran-text font.
class _AyahOpening extends ConsumerWidget {
  const _AyahOpening({required this.ayahId});

  final int ayahId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(canonicalAyahTextProvider(ayahId: ayahId)).value;
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
      style: quranTextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFamily: QuranFont.scheherazade.family,
        fontSize: 18,
      ),
    );
  }
}

class _Heading {
  const _Heading(this.text);
  final String text;
}

class _Saved {
  const _Saved(this.key);
  final String key;
}

/// A bookmarked athkar chapter or dua: its icon and name (a dua's opening
/// words under it); a tap opens it; removed with an undo.
class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.savedKey});

  final String savedKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final chapterId = SavedSupplications.chapterOf(savedKey);
    final dua = DuaGroup.quranOf(savedKey);
    final Widget leading;
    final String title;
    final Widget? subtitle;
    final VoidCallback onTap;
    if (chapterId != null) {
      final chapter = ref.watch(athkarBookProvider).value?.category(chapterId);
      leading = Icon(athkarCategoryIcon(chapterId), color: scheme.primary);
      title = chapter?.titleIn(language) ?? l10n.athkarTitle;
      subtitle = Text(l10n.athkarTitle);
      onTap = () => context.push(AppRoutes.athkarCategory(chapterId));
    } else if (dua != null) {
      final names = ref.watch(indexedSurahsProvider).value ?? const [];
      String? name;
      for (final s in names) {
        if (s.surah.surahNo == dua.surah) {
          name = s.localizedName ?? s.arabicName;
        }
      }
      leading = DuaHandsIcon(color: scheme.primary);
      title = name == null ? dua.reference : '$name · ${dua.reference}';
      subtitle = _AyahOpening(ayahId: dua.ayahIds.first);
      onTap = () => context.push(
        AppRoutes.duasGroup((DuaGroup.of(dua) ?? DuaGroup.health).name),
      );
    } else if (savedKey.startsWith('hadith:')) {
      HadithDua? hadith;
      for (final h in ref.watch(hadithDuasProvider).value ?? const []) {
        if (h.savedKey == savedKey) hadith = h;
      }
      if (hadith == null) return const SizedBox.shrink();
      final group = DuaGroup.values.firstWhere(
        (g) => g.name == hadith!.group,
        orElse: () => DuaGroup.health,
      );
      leading = DuaHandsIcon(color: scheme.primary);
      title = hadith.titleIn(language);
      subtitle = Text(
        '${hadithReference(l10n, hadith)} · ${group.title(l10n)}',
      );
      final h = hadith;
      onTap = () => context.push(AppRoutes.duasHadith(h.book, h.number));
    } else {
      return const SizedBox.shrink();
    }
    return TahfeezCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        key: ValueKey('bookmark-$savedKey'),
        leading: leading,
        title: Text(title),
        subtitle: subtitle,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: l10n.bookmarkRemove,
          onPressed: () {
            final saved = ref.read(savedSupplicationsProvider.notifier);
            final index = ref
                .read(savedSupplicationsProvider)
                .indexOf(savedKey);
            saved.toggle(savedKey);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(l10n.bookmarkRemoved),
                  action: SnackBarAction(
                    label: l10n.commonUndo,
                    onPressed: () => saved.restore(savedKey, index),
                  ),
                ),
              );
          },
        ),
        onTap: onTap,
      ),
    );
  }
}
