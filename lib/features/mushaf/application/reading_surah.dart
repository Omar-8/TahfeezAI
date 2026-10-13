import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The surah being read, and on which page: the reader's title names it
/// while that page is on screen (Ya-Sin opened on page 440, which starts
/// with Faatir's end; the surah scrolled into in Ayah mode) — other pages
/// are titled by the surah they start with.
class ReadingSurah extends Notifier<({int page, int surah})?> {
  @override
  ({int page, int surah})? build() => null;

  void read(int page, int ayahId) {
    final next = (page: page, surah: ayahId ~/ 1000);
    if (state != next) state = next;
  }

  /// The reader closed: nothing being read.
  void clear() {
    if (ref.mounted) state = null;
  }
}

final readingSurahProvider =
    NotifierProvider<ReadingSurah, ({int page, int surah})?>(ReadingSurah.new);
