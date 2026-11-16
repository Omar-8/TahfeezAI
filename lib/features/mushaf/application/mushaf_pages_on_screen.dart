import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/ui/full_bleed_content.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/domain/models/quran_refs.dart';
import '../../../quran/quran_providers.dart';
import '../../recitation/application/mushaf_recitation_target.dart';
import '../domain/quran_engine/quran_engine_mushaf_backend.dart'
    show MushafWordLocatingPage;
import 'mushaf_hide_mode.dart' show firstVisiblePage;
import 'mushaf_page_turn.dart';
import 'mushaf_page_verses.dart';
import 'mushaf_word_overlay.dart' show compareWordRefs;

/// The Mushaf pages built that can say where a word is drawn, by page
/// number (registered by each page as it loads, gone with it).
final mushafWordLocators = <int, MushafWordLocatingPage>{};

/// [word]'s box on the screen (global), from the page it is on — `null`
/// when that page is not built, or can't tell.
Rect? mushafWordRect(ProviderRead read, WordRef word) {
  for (final MapEntry(key: page, value: range) in read(
    mushafPageWordRangesProvider,
  ).entries) {
    if (compareWordRefs(range.first, word) <= 0 &&
        compareWordRefs(range.last, word) >= 0) {
      return mushafWordLocators[page]?.wordRectOnScreen(word);
    }
  }
  return null;
}

/// A provider read ([Ref.read] or [WidgetRef.read]).
typedef ProviderRead = T Function<T>(ProviderListenable<T> provider);

/// The page(s) on screen in the Mushaf — both of a browser's spread — or
/// `null` when no Mushaf is.
Set<int>? mushafPagesOnScreen(ProviderRead read) {
  final location = read(mushafRecitationTargetProvider)?.location;
  if (location is! QuranLocationPage) return null;
  final spread = read(fullBleedContentProvider);
  final first = firstVisiblePage(location.pageNumber, spread: spread);
  return {first, if (spread) first + 1};
}

/// The Mushaf turned to [word]'s page when it is not on screen (a sheet
/// going from word to word, or ayah to ayah, over it). Only the pages on
/// screen count — not those loaded beside them: counting those, the page
/// stayed until the word was two pages on, then jumped there (owner,
/// 2026-11-16: "it jumps 3 pages").
Future<void> showMushafPageOf(ProviderRead read, WordRef word) async {
  final pages = mushafPagesOnScreen(read);
  final location = read(mushafRecitationTargetProvider)?.location;
  if (pages == null || location is! QuranLocationPage) return;
  int? page;
  for (final MapEntry(key: p, value: range) in read(
    mushafPageWordRangesProvider,
  ).entries) {
    if (compareWordRefs(range.first, word) <= 0 &&
        compareWordRefs(range.last, word) >= 0) {
      page = p;
      break;
    }
  }
  final turns = read(mushafPageTurnRequestsProvider.notifier);
  page ??= await read(quranRepositoryProvider)
      .getPageForAyah(mushafId: location.mushafId, ayahId: word.ayahId);
  if (page != null && !pages.contains(page)) turns.toPage(page);
}
