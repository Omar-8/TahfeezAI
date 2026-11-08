import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/bookmarks/application/bookmarks_controller.dart';

void main() {
  test('ayahs and surahs bookmarked, newest first, and kept', () async {
    final first = ProviderContainer();
    final bookmarks = first.read(bookmarksProvider.notifier);
    bookmarks.toggleAyah(2255);
    bookmarks.toggleSurah(18);
    bookmarks.toggleAyah(36001);
    bookmarks.toggleAyah(36001); // removed again
    expect(bookmarks.hasAyah(2255), isTrue);
    expect(bookmarks.hasSurah(18), isTrue);
    expect(bookmarks.hasSurah(2), isFalse, reason: 'an ayah is not its surah');
    expect(
      [for (final b in first.read(bookmarksProvider)) b.toJson()['surah']],
      [18, 2],
    );
    await Future<void>.delayed(Duration.zero);
    first.dispose();

    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(bookmarksProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final kept = next.read(bookmarksProvider);
    expect(
      [for (final b in kept) (b.surahNo, b.ayahId)],
      [(18, null), (2, 2255)],
    );
  });

  test('a bookmark removed is put back where it was (Undo)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bookmarks = container.read(bookmarksProvider.notifier);
    bookmarks.toggleAyah(1001);
    bookmarks.toggleAyah(2255);
    bookmarks.toggleSurah(18);
    final middle = container.read(bookmarksProvider)[1];
    bookmarks.remove(middle);
    expect(container.read(bookmarksProvider), hasLength(2));
    bookmarks.restore(middle, 1);
    expect(container.read(bookmarksProvider)[1], same(middle));
    // Twice: not doubled.
    bookmarks.restore(middle, 1);
    expect(container.read(bookmarksProvider), hasLength(3));
  });
}
