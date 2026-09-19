import 'models/mushaf_models.dart';

/// One physical line of a Mushaf page as a raw layout source describes it —
/// before its word range has been resolved against Tahfeez's own ayah/word
/// numbering.
///
/// This is the seam a Mushaf layout provider (currently: QUL's KFGQPC V2
/// export) produces, distinct from [MushafLine] itself. A layout source
/// typically identifies a line's words by *its own* global word-id scheme
/// (e.g. QUL's `first_word_id`/`last_word_id`), not by (ayahId, wordIndex) —
/// [firstWordId]/[lastWordId] are `null` for a line with no word range of
/// its own ([MushafLineType.surahHeader]/[MushafLineType.bismillah]).
class RawMushafLine {
  const RawMushafLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    this.surahNo,
    this.firstWordId,
    this.lastWordId,
  });

  final int pageNumber;
  final int lineNumber;
  final MushafLineType lineType;
  final bool isCentered;
  final int? surahNo;
  final int? firstWordId;
  final int? lastWordId;
}

/// A Mushaf edition's raw page/line layout, exactly as its source describes
/// it — no ayah/word resolution performed yet.
class RawMushafLayout {
  const RawMushafLayout({
    required this.editionCode,
    required this.pageCount,
    required this.linesPerPage,
    required this.lines,
  });

  final String editionCode;
  final int pageCount;
  final int linesPerPage;
  final List<RawMushafLine> lines;
}

/// Where Tahfeez gets a Mushaf edition's page/line layout from.
///
/// This is the abstraction that lets a Mushaf layout provider be replaced
/// without touching [QuranRepository], the Mushaf renderer, or any other UI
/// — the same role [QuranDatasetPayload] plays for canonical text. A source
/// only has to produce a [RawMushafLayout]; turning that into real
/// [MushafLine] rows is [resolveMushafLines]'s job, kept separate because it
/// additionally needs a [MushafWordIdResolver] the layout source itself does
/// not own.
///
/// The only implementation as of this milestone reads QUL's KFGQPC V2 export
/// (`tool/quran_data/src/mushaf_layout_source.dart`, build-time tooling
/// only — QUL's own download is gated behind a required user login with no
/// public API, so this cannot run as an in-app network fetch). No synthetic
/// or placeholder implementation exists or may be created; see
/// `docs/QURAN_DATA_PROVENANCE.md`.
abstract class MushafDataSource {
  Future<RawMushafLayout> loadRawLayout();
}

/// Resolves one Mushaf layout source's own word-id scheme to Tahfeez's
/// (ayahId, wordIndex) numbering.
///
/// A [MushafDataSource] alone is not enough to populate real [MushafLine]
/// rows: QUL's `first_word_id`/`last_word_id` are bare integers into a
/// companion word/script dataset Tahfeez has not yet received (see
/// `docs/QURAN_DATA_PROVENANCE.md`'s Mushaf resource entry) — until a real
/// resolver backed by that dataset exists, [resolveMushafLines] cannot be
/// run against production data, and must not be run against fabricated
/// data either.
abstract class MushafWordIdResolver {
  /// The (ayahId, wordIndex) position of [wordId], or `null` if [wordId] is
  /// outside this resolver's known range.
  ({int ayahId, int wordIndex})? resolve(int wordId);
}

/// Thrown by [resolveMushafLines] when a raw line references a word id
/// [resolver] cannot resolve — surfaced rather than silently dropped, since
/// a gap here means the Mushaf layout and the word dataset disagree.
class MushafWordIdResolutionException implements Exception {
  MushafWordIdResolutionException(
    this.wordId,
    this.pageNumber,
    this.lineNumber,
  );

  final int wordId;
  final int pageNumber;
  final int lineNumber;

  @override
  String toString() =>
      'Could not resolve word id $wordId referenced by Mushaf page '
      '$pageNumber line $lineNumber against the supplied word dataset.';
}

/// Turns a [RawMushafLayout] into real [MushafLine] rows for [mushafId],
/// using [resolver] to translate each line's word-id range into
/// (ayahId, wordIndex) bounds. Never fabricates a resolution: throws
/// [MushafWordIdResolutionException] rather than guessing when a word id is
/// unknown to [resolver].
List<MushafLine> resolveMushafLines({
  required RawMushafLayout layout,
  required MushafWordIdResolver resolver,
  required int mushafId,
}) {
  return layout.lines.map((raw) {
    int? startAyahId;
    int? startWordIndex;
    int? endAyahId;
    int? endWordIndex;

    if (raw.firstWordId != null && raw.lastWordId != null) {
      final start = resolver.resolve(raw.firstWordId!);
      if (start == null) {
        throw MushafWordIdResolutionException(
          raw.firstWordId!,
          raw.pageNumber,
          raw.lineNumber,
        );
      }
      final end = resolver.resolve(raw.lastWordId!);
      if (end == null) {
        throw MushafWordIdResolutionException(
          raw.lastWordId!,
          raw.pageNumber,
          raw.lineNumber,
        );
      }
      startAyahId = start.ayahId;
      startWordIndex = start.wordIndex;
      endAyahId = end.ayahId;
      endWordIndex = end.wordIndex;
    }

    return MushafLine(
      mushafId: mushafId,
      pageNumber: raw.pageNumber,
      lineNumber: raw.lineNumber,
      lineType: raw.lineType,
      isCentered: raw.isCentered,
      startAyahId: startAyahId,
      startWordIndex: startWordIndex,
      endAyahId: endAyahId,
      endWordIndex: endWordIndex,
      surahNo: raw.surahNo,
    );
  }).toList();
}
