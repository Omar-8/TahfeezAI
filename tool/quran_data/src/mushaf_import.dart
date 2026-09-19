// Combines QUL's KFGQPC V2 layout export and word-by-word export into real
// Mushaf/MushafLine/MushafToken records — the production import pipeline
// for the Mushaf layer. No synthetic content: every field comes from one
// of the two real, vendored source files, or from canonical word counts
// already computed from Tanzil (used only to classify tokens, never to
// fabricate one).
import 'package:tahfeez_ai/quran/domain/mushaf_data_source.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_token_classifier.dart';
import 'package:tahfeez_ai/quran/domain/mushaf_token_source.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_models.dart';
import 'package:tahfeez_ai/quran/domain/models/mushaf_token_models.dart';

class MushafImportResult {
  const MushafImportResult({
    required this.mushaf,
    required this.lines,
    required this.tokens,
    required this.classificationWarnings,
  });

  final Mushaf mushaf;
  final List<MushafLine> lines;
  final List<MushafToken> tokens;
  final List<MushafTokenClassificationWarning> classificationWarnings;
}

/// Builds one Mushaf's full production data: metadata + every line +
/// every classified token.
///
/// [canonicalWordCountByAyahId] must come from the same canonical dataset
/// this Mushaf's tokens are meant to join against (ayahId ->
/// [AyahWord] count for that ayah) — [MushafTokenClassifier] uses it to
/// decide which tokens are real Quran words vs. markers. Throws nothing on
/// its own; classification warnings (never fabricated mappings) are
/// returned in [MushafImportResult.classificationWarnings] for the caller
/// to inspect and fail the build on if any exist.
Future<MushafImportResult> importMushaf({
  required int mushafId,
  required String code,
  required String qiraah,
  required String edition,
  required int scriptId,
  required MushafDataSource layoutSource,
  required MushafTokenSource tokenSource,
  required Map<int, int> canonicalWordCountByAyahId,
}) async {
  final rawLayout = await layoutSource.loadRawLayout();
  final rawTokens = await tokenSource.loadRawTokens();

  const classifier = MushafTokenClassifier();
  final classified = classifier.classify(
    mushafId: mushafId,
    rawTokens: rawTokens,
    canonicalWordCountByAyahId: canonicalWordCountByAyahId,
  );

  final lines = rawLayout.lines
      .map((raw) => mushafLineFromRaw(raw, mushafId: mushafId))
      .toList();

  final mushaf = Mushaf(
    id: mushafId,
    code: code,
    scriptId: scriptId,
    pageCount: rawLayout.pageCount,
    linesPerPage: rawLayout.linesPerPage,
    qiraah: qiraah,
    edition: edition,
    renderingType: MushafRenderingType.pageSpecificGlyphFont,
  );

  return MushafImportResult(
    mushaf: mushaf,
    lines: lines,
    tokens: classified.tokens,
    classificationWarnings: classified.warnings,
  );
}
