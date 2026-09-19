import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/application/quran_script_code.dart';
import '../../../quran/domain/models/ayah_models.dart';
import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/quran_providers.dart';

part 'mushaf_page_providers.g.dart';

/// The Mushaf edition itself (page count, lines-per-page, script) —
/// resolved separately from any one page's data so the reader screen can
/// know the total page count before requesting a specific page.
@riverpod
Future<Mushaf?> mushafById(Ref ref, int mushafId) {
  return ref.watch(quranRepositoryProvider).getMushafById(mushafId);
}

/// One Mushaf page's data: its lines, each line's exact words (already
/// sliced from one batched page-wide load — never one query per line), and
/// the Juz/Hizb context the page's chrome needs.
class MushafPageBundle {
  const MushafPageBundle({
    required this.mushaf,
    required this.pageNumber,
    required this.lines,
    required this.wordsByLineNumber,
    required this.juzNo,
    required this.hizbNos,
  });

  final Mushaf mushaf;
  final int pageNumber;
  final List<MushafLine> lines;
  final Map<int, List<AyahWord>> wordsByLineNumber;
  final int? juzNo;
  final List<int> hizbNos;
}

@riverpod
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

  final scriptCode = ref.watch(quranScriptCodeProvider);
  final pageWords = await repository.getWordsForPage(
    mushafId: mushafId,
    pageNumber: pageNumber,
    scriptCode: scriptCode,
  );

  final wordsByLine = <int, List<AyahWord>>{
    for (final line in lines) line.lineNumber: _wordsForLine(pageWords, line),
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
    wordsByLineNumber: wordsByLine,
    juzNo: juzNo,
    hizbNos: hizbNos,
  );
}

/// Slices one page-wide word list down to the words belonging to [line],
/// using the exact same ayah-id/word-index boundary trimming
/// `DriftQuranRepository.getWordsForLine` applies for a single line — done
/// once in memory per page here instead of as N extra database queries.
List<AyahWord> _wordsForLine(List<AyahWord> pageWords, MushafLine line) {
  final startAyahId = line.startAyahId;
  final endAyahId = line.endAyahId;
  final startWordIndex = line.startWordIndex;
  final endWordIndex = line.endWordIndex;
  if (startAyahId == null ||
      endAyahId == null ||
      startWordIndex == null ||
      endWordIndex == null) {
    return const [];
  }

  return pageWords.where((word) {
    if (word.ayahId < startAyahId || word.ayahId > endAyahId) return false;
    if (word.ayahId == startAyahId && word.wordIndex < startWordIndex) {
      return false;
    }
    if (word.ayahId == endAyahId && word.wordIndex > endWordIndex) {
      return false;
    }
    return true;
  }).toList();
}
