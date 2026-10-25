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
import '../application/bookmarks_controller.dart';

/// The bookmarked ayahs and surahs, newest first: open one in the Mushaf,
/// or remove it.
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookmarks = ref.watch(bookmarksProvider);
    final names = {
      for (final s in ref.watch(indexedSurahsProvider).value ?? const [])
        s.surah.surahNo: s.localizedName ?? s.arabicName,
    };
    return Scaffold(
      appBar: TahfeezAppBar(
        title: Text(l10n.bookmarksTitle),
        centerTitle: false,
      ),
      body: bookmarks.isEmpty
          ? TahfeezEmptyView(
              icon: Icons.bookmark_border_rounded,
              message: l10n.bookmarksEmpty,
            )
          : ListView.separated(
              padding: withBarSpace(
                context,
                const EdgeInsets.all(TahfeezSpacing.md),
              ),
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: TahfeezSpacing.sm),
              itemBuilder: (context, i) {
                final b = bookmarks[i];
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
                          onPressed: () =>
                              ref.read(bookmarksProvider.notifier).remove(b),
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
        fontFamily: 'Scheherazade New',
        fontSize: 18,
      ),
    );
  }
}
