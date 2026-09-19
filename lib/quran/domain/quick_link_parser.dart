import 'models/quran_location.dart';

/// A quick-link match parsed directly from a search query's text shape —
/// resolves instantly, with no index lookup, the moment a query looks like
/// a structured navigation reference.
class QuickLink {
  const QuickLink({required this.label, required this.location});

  final String label;
  final QuranLocation location;
}

/// Recognizes structured navigation queries typed directly into the search
/// box — a verse jump (`2:255`), a verse-range jump (`2:255-257`), and a
/// bare chapter/Juz number — independently designed from, but functionally
/// equivalent to, `SearchQuickLinksParser`
/// (`docs/reference/07_SEARCH_SPEC.md` §2.4): letting a numeric or
/// reference-shaped query resolve instantly without a full-text index
/// query. Pure and synchronous — no repository dependency, since it only
/// needs the fixed structural constants of the Quran (114 chapters, 30
/// Juz), not any installed dataset.
class QuickLinkParser {
  const QuickLinkParser();

  static const _chapterCount = 114;
  static const _juzCount = 30;

  static final _verseRange = RegExp(r'^(\d{1,3}):(\d{1,3})-(\d{1,3})$');
  static final _verse = RegExp(r'^(\d{1,3}):(\d{1,3})$');
  static final _bareNumber = RegExp(r'^(\d{1,3})$');

  List<QuickLink> parse(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    final rangeMatch = _verseRange.firstMatch(query);
    if (rangeMatch != null) {
      final chapterNo = int.parse(rangeMatch.group(1)!);
      final fromVerseNo = int.parse(rangeMatch.group(2)!);
      final toVerseNo = int.parse(rangeMatch.group(3)!);
      if (_isValidChapter(chapterNo) &&
          fromVerseNo >= 1 &&
          toVerseNo >= fromVerseNo) {
        return [
          QuickLink(
            label: 'Go to $chapterNo:$fromVerseNo-$toVerseNo',
            location: QuranLocation.ayahRange(
              chapterNo,
              fromVerseNo,
              toVerseNo,
            ),
          ),
        ];
      }
      return const [];
    }

    final verseMatch = _verse.firstMatch(query);
    if (verseMatch != null) {
      final chapterNo = int.parse(verseMatch.group(1)!);
      final verseNo = int.parse(verseMatch.group(2)!);
      if (_isValidChapter(chapterNo) && verseNo >= 1) {
        return [
          QuickLink(
            label: 'Go to $chapterNo:$verseNo',
            location: QuranLocation.ayah(chapterNo, verseNo),
          ),
        ];
      }
      return const [];
    }

    final bareMatch = _bareNumber.firstMatch(query);
    if (bareMatch != null) {
      final number = int.parse(bareMatch.group(1)!);
      final links = <QuickLink>[];
      if (_isValidChapter(number)) {
        links.add(
          QuickLink(
            label: 'Go to Surah $number',
            location: QuranLocation.surah(number),
          ),
        );
      }
      if (number >= 1 && number <= _juzCount) {
        links.add(
          QuickLink(
            label: 'Go to Juz $number',
            location: QuranLocation.juz(number),
          ),
        );
      }
      return links;
    }

    return const [];
  }

  bool _isValidChapter(int chapterNo) =>
      chapterNo >= 1 && chapterNo <= _chapterCount;
}
