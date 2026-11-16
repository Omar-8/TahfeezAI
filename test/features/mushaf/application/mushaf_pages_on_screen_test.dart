import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/ui/full_bleed_content.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_turn.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_page_verses.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_pages_on_screen.dart';
import 'package:tahfeez_ai/features/recitation/application/mushaf_recitation_target.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_location.dart';
import 'package:tahfeez_ai/quran/domain/models/quran_refs.dart';

/// Page [p]'s words in this test: ayahs p*1000+1 .. p*1000+3.
({WordRef first, WordRef last}) _range(int p) => (
  first: (ayahId: p * 1000 + 1, wordIndex: 0),
  last: (ayahId: p * 1000 + 3, wordIndex: 4),
);

void main() {
  /// The Mushaf on [page] ([spread]: a browser's two pages), the pages
  /// beside it loaded too (as the pager preloads them).
  ProviderContainer onPage(int page, {bool spread = false}) {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(mushafRecitationTargetProvider.notifier)
        .show(Object(), QuranLocation.page(1, page));
    if (spread) c.read(fullBleedContentProvider.notifier).request();
    final ranges = c.read(mushafPageWordRangesProvider.notifier);
    for (var p = page - 2; p <= page + 3; p++) {
      ranges.report(p, _range(p));
    }
    return c;
  }

  int? turnedTo(ProviderContainer c) =>
      c.read(mushafPageTurnRequestsProvider)?.page;

  test(
    'the next ayah on the next page: one page on — not left until it '
    'is two pages away, then jumped there (owner: "it jumps 3 pages")',
    () async {
      final c = onPage(10);
      // On the page shown: no turn.
      await showMushafPageOf(c.read, (ayahId: 10002, wordIndex: 0));
      expect(turnedTo(c), isNull);
      // On the next page (already loaded beside it): to it, one page.
      await showMushafPageOf(c.read, (ayahId: 11001, wordIndex: 0));
      expect(turnedTo(c), 11);
    },
  );

  test('back a page the same way', () async {
    final c = onPage(10);
    await showMushafPageOf(c.read, (ayahId: 9003, wordIndex: 4));
    expect(turnedTo(c), 9);
  });

  test(
    "a browser's two pages: no turn within them, one spread on after",
    () async {
      // Pages 9 and 10 side by side (a spread starts on an odd page).
      final c = onPage(10, spread: true);
      expect(mushafPagesOnScreen(c.read), {9, 10});
      await showMushafPageOf(c.read, (ayahId: 9001, wordIndex: 0));
      await showMushafPageOf(c.read, (ayahId: 10003, wordIndex: 0));
      expect(turnedTo(c), isNull);
      await showMushafPageOf(c.read, (ayahId: 11001, wordIndex: 0));
      expect(turnedTo(c), 11);
    },
  );

  test('no Mushaf on screen: nothing turned', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(mushafPagesOnScreen(c.read), isNull);
    await showMushafPageOf(c.read, (ayahId: 1001, wordIndex: 0));
    expect(turnedTo(c), isNull);
  });
}
