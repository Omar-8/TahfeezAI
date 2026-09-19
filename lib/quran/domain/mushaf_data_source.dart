import 'models/mushaf_models.dart';

/// One physical line of a Mushaf page as a raw layout source describes it.
///
/// This is the seam a Mushaf layout provider (currently: QUL's KFGQPC V2
/// export) produces, distinct from [MushafLine] itself only in field naming
/// (`firstWordId`/`lastWordId`, matching the source's own vocabulary) —
/// turning this into a real [MushafLine] is a direct field copy
/// ([mushafLineFromRaw]), since both now agree that a line's range is a
/// [MushafToken.sourceTokenId] range, not an (ayahId, wordIndex) range. This
/// was not always true: an earlier design tried to resolve word ids into
/// canonical ayah/word positions at this stage, before this project had a
/// real Mushaf word dataset to test that assumption against. Real data
/// showed a line's token range is not guaranteed to contain only real
/// words (`docs/QURAN_DATA_PROVENANCE.md` §7b's ayah-marker finding), so
/// resolution now happens per-token, downstream ([MushafTokenClassifier]),
/// never at the line level.
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
/// it.
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
/// — the same role [QuranDatasetPayload] plays for canonical text.
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

/// Converts one [RawMushafLine] into a real [MushafLine] for [mushafId] — a
/// direct field copy, not a resolution step (see [RawMushafLine]'s doc
/// comment for why no resolution is needed here any more).
MushafLine mushafLineFromRaw(RawMushafLine raw, {required int mushafId}) {
  return MushafLine(
    mushafId: mushafId,
    pageNumber: raw.pageNumber,
    lineNumber: raw.lineNumber,
    lineType: raw.lineType,
    isCentered: raw.isCentered,
    firstTokenId: raw.firstWordId,
    lastTokenId: raw.lastWordId,
    surahNo: raw.surahNo,
  );
}
