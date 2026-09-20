import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/mushaf_token_models.dart';
import '../../../quran/quran_providers.dart';

part 'mushaf_page_providers.g.dart';

/// The Mushaf edition itself (page count, lines-per-page, script) —
/// resolved separately from any one page's data so the reader screen can
/// know the total page count before requesting a specific page.
@riverpod
Future<Mushaf?> mushafById(Ref ref, int mushafId) {
  return ref.watch(quranRepositoryProvider).getMushafById(mushafId);
}

/// One Mushaf page's data: its lines, each line's exact tokens (already
/// sliced from one batched page-wide load — never one query per line), and
/// the Juz/Hizb context the page's chrome needs.
class MushafPageBundle {
  const MushafPageBundle({
    required this.mushaf,
    required this.pageNumber,
    required this.lines,
    required this.tokensByLineNumber,
    required this.juzNo,
    required this.hizbNos,
  });

  final Mushaf mushaf;
  final int pageNumber;
  final List<MushafLine> lines;
  final Map<int, List<MushafToken>> tokensByLineNumber;
  final int? juzNo;
  final List<int> hizbNos;
}

/// `keepAlive: true`: unlike the 604 QPC page *fonts* (individually large
/// binary assets that genuinely need lazy, bounded loading — see
/// `QpcPageFontManager`), one page's lines/tokens are a handful of small
/// Dart objects. Caching every page a session ever visits for the app's
/// lifetime costs at most a few MB even for the full 604-page Mushaf, and
/// avoids re-querying the database (and, downstream, redoing that page's
/// real-font-shaping layout pass — see `mushafPageLayoutProvider`) every
/// time the user swipes back to a page they've already seen.
@Riverpod(keepAlive: true)
Future<MushafPageBundle?> mushafPageData(
  Ref ref,
  int mushafId,
  int pageNumber,
) async {
  final repository = ref.watch(quranRepositoryProvider);

  final mushaf = await repository.getMushafById(mushafId);
  if (mushaf == null) return null;

  final lines = await repository.getPageLines(
    mushafId: mushafId,
    pageNumber: pageNumber,
  );
  if (lines.isEmpty) return null;

  final pageTokens = await repository.getPageTokens(
    mushafId: mushafId,
    pageNumber: pageNumber,
  );

  final tokensByLine = <int, List<MushafToken>>{
    for (final line in lines) line.lineNumber: _tokensForLine(pageTokens, line),
  };

  final juzNo = await repository.getJuzForPage(
    mushafId: mushafId,
    pageNumber: pageNumber,
  );
  final hizbNos = await repository.getHizbsForPage(
    mushafId: mushafId,
    pageNumber: pageNumber,
  );

  return MushafPageBundle(
    mushaf: mushaf,
    pageNumber: pageNumber,
    lines: lines,
    tokensByLineNumber: tokensByLine,
    juzNo: juzNo,
    hizbNos: hizbNos,
  );
}

/// Slices one page-wide token list down to the tokens belonging to [line],
/// using the exact same token-id boundary trimming
/// `DriftQuranRepository.getLineTokens` applies for a single line — done
/// once in memory per page here instead of as N extra database queries.
List<MushafToken> _tokensForLine(
  List<MushafToken> pageTokens,
  MushafLine line,
) {
  final first = line.firstTokenId;
  final last = line.lastTokenId;
  if (first == null || last == null) return const [];

  return pageTokens
      .where((t) => t.sourceTokenId >= first && t.sourceTokenId <= last)
      .toList();
}
