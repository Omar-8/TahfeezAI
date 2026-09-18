import 'models/mushaf_models.dart';
import 'quran_dataset_payload.dart';

/// The Quran has exactly 114 chapters — an immutable fact about the Quran
/// itself, not a reference-app detail, and the basis of the first integrity
/// check every candidate dataset must pass.
const kExpectedSurahCount = 114;

enum IntegritySeverity {
  /// The dataset is unsafe to use as-is; [QuranDatasetImporter] refuses to
  /// import it.
  error,

  /// Suspicious but not necessarily wrong (e.g. an unusually short chapter);
  /// import proceeds.
  warning,
}

/// One integrity finding. [code] is a short, stable, machine-checkable
/// identifier (asserted on directly in tests); [message] is for humans
/// (logs, a future diagnostics screen).
class IntegrityIssue {
  const IntegrityIssue({
    required this.code,
    required this.severity,
    required this.message,
  });

  final String code;
  final IntegritySeverity severity;
  final String message;

  @override
  String toString() => '[$severity:$code] $message';
}

/// The result of validating a [QuranDatasetPayload].
class DatasetIntegrityReport {
  const DatasetIntegrityReport(this.issues);

  final List<IntegrityIssue> issues;

  bool get hasErrors =>
      issues.any((i) => i.severity == IntegritySeverity.error);

  /// A dataset with only warnings (or no issues at all) is safe to import.
  bool get isValid => !hasErrors;

  List<IntegrityIssue> get errors =>
      issues.where((i) => i.severity == IntegritySeverity.error).toList();

  List<IntegrityIssue> get warnings =>
      issues.where((i) => i.severity == IntegritySeverity.warning).toList();
}

/// Runs every deterministic structural check this milestone requires against
/// a candidate [QuranDatasetPayload], **before** any of it reaches SQLite.
///
/// Deliberately pure Dart with no Drift/Flutter dependency: any dataset —
/// bundled asset, downloaded file, or a test fixture — can be checked the
/// same way, and every rule here is unit-testable without opening a
/// database. Per `CLAUDE.md`'s Quran-correctness rules, this validator only
/// ever *reports on* the payload; it never edits, drops, or "fixes" a
/// canonical text field.
class DatasetIntegrityValidator {
  const DatasetIntegrityValidator();

  DatasetIntegrityReport validate(QuranDatasetPayload payload) {
    final issues = <IntegrityIssue>[
      ..._checkSurahCount(payload),
      ..._checkAyahNumbering(payload),
      ..._checkStableAyahIds(payload),
      ..._checkOrderedWords(payload),
      ..._checkMushafPageMappings(payload),
      ..._checkOrderedMushafLines(payload),
      ..._checkLineWordRanges(payload),
      ..._checkNavigationRangeBoundaries(payload),
      ..._checkNoMissingText(payload),
      ..._checkDatasetMetadata(payload),
    ];
    return DatasetIntegrityReport(issues);
  }

  Iterable<IntegrityIssue> _checkSurahCount(QuranDatasetPayload payload) sync* {
    final surahNumbers = payload.surahs.map((s) => s.surahNo).toSet();

    // Every specific check below runs unconditionally (no early return) so
    // that, e.g., a dataset missing surah 50 is reported as exactly that —
    // not masked by a single generic "wrong count" issue that stops before
    // saying which surah is the problem.
    for (var expected = 1; expected <= kExpectedSurahCount; expected++) {
      if (!surahNumbers.contains(expected)) {
        yield IntegrityIssue(
          code: 'surah_missing',
          severity: IntegritySeverity.error,
          message: 'Surah $expected is missing from the dataset.',
        );
      }
    }

    for (final n in surahNumbers) {
      if (n < 1 || n > kExpectedSurahCount) {
        yield IntegrityIssue(
          code: 'surah_unexpected',
          severity: IntegritySeverity.error,
          message:
              'Surah number $n is outside the valid 1..$kExpectedSurahCount range.',
        );
      }
    }

    if (payload.surahs.length != surahNumbers.length) {
      yield IntegrityIssue(
        code: 'surah_duplicate',
        severity: IntegritySeverity.error,
        message:
            'The dataset lists ${payload.surahs.length} surah rows but only ${surahNumbers.length} '
            'distinct surah numbers — some surah number is duplicated.',
      );
    }

    if (surahNumbers.length != kExpectedSurahCount) {
      yield IntegrityIssue(
        code: 'surah_count',
        severity: IntegritySeverity.error,
        message:
            'Expected exactly $kExpectedSurahCount distinct surahs, found ${surahNumbers.length}.',
      );
    }
  }

  Iterable<IntegrityIssue> _checkAyahNumbering(
    QuranDatasetPayload payload,
  ) sync* {
    final ayahsBySurah = <int, List<int>>{};
    for (final ayah in payload.ayahs) {
      ayahsBySurah.putIfAbsent(ayah.chapterNo, () => []).add(ayah.verseNo);
    }

    for (final surah in payload.surahs) {
      // A fresh, definitely-mutable copy: falling back to a `const []`
      // literal here and sorting it in place would throw at runtime for
      // any surah with zero ayahs in the payload.
      final verseNumbers = [...?ayahsBySurah[surah.surahNo]]..sort();
      final expected = List.generate(surah.ayahCount, (i) => i + 1);

      if (!_listEquals(verseNumbers, expected)) {
        yield IntegrityIssue(
          code: 'ayah_numbering',
          severity: IntegritySeverity.error,
          message:
              'Surah ${surah.surahNo} declares ${surah.ayahCount} ayahs but has verse numbers '
              '$verseNumbers (expected 1..${surah.ayahCount} with no gaps or duplicates).',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkStableAyahIds(
    QuranDatasetPayload payload,
  ) sync* {
    final seen = <int>{};
    for (final ayah in payload.ayahs) {
      if (!seen.add(ayah.id)) {
        yield IntegrityIssue(
          code: 'ayah_id_duplicate',
          severity: IntegritySeverity.error,
          message: 'Ayah id ${ayah.id} is used by more than one verse.',
        );
      }

      final expectedId = ayah.chapterNo * 1000 + ayah.verseNo;
      if (ayah.id != expectedId) {
        yield IntegrityIssue(
          code: 'ayah_id_unstable',
          severity: IntegritySeverity.error,
          message:
              'Ayah ${ayah.chapterNo}:${ayah.verseNo} has id ${ayah.id}, expected the stable id '
              '$expectedId (chapterNo * 1000 + verseNo).',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkOrderedWords(
    QuranDatasetPayload payload,
  ) sync* {
    final indicesByAyahAndScript = <(int, int), List<int>>{};
    for (final word in payload.ayahWords) {
      indicesByAyahAndScript
          .putIfAbsent((word.ayahId, word.scriptId), () => [])
          .add(word.wordIndex);
    }

    // A plain for-loop, not `.forEach((k, v) { ... })`: `yield` is only
    // valid directly inside this `sync*` function's own body, not inside a
    // nested (non-generator) closure.
    for (final entry in indicesByAyahAndScript.entries) {
      final (ayahId, scriptId) = entry.key;
      final indices = entry.value;
      final sorted = [...indices]..sort();
      final expected = List.generate(indices.length, (i) => i);

      if (!_listEquals(sorted, expected)) {
        yield IntegrityIssue(
          code: 'word_indices_not_contiguous',
          severity: IntegritySeverity.error,
          message:
              'Ayah $ayahId, script $scriptId has word indices $sorted '
              '(expected a contiguous 0..${indices.length - 1} sequence with no gaps or duplicates).',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkMushafPageMappings(
    QuranDatasetPayload payload,
  ) sync* {
    final mushafsById = {for (final m in payload.mushafs) m.id: m};

    for (final line in payload.mushafLines) {
      final mushaf = mushafsById[line.mushafId];
      if (mushaf == null) {
        yield IntegrityIssue(
          code: 'mushaf_line_unknown_mushaf',
          severity: IntegritySeverity.error,
          message:
              'A Mushaf line references unknown mushaf id ${line.mushafId}.',
        );
        continue;
      }

      if (line.pageNumber < 1 || line.pageNumber > mushaf.pageCount) {
        yield IntegrityIssue(
          code: 'mushaf_page_out_of_range',
          severity: IntegritySeverity.error,
          message:
              'Mushaf ${mushaf.id} page ${line.pageNumber} is outside its declared '
              '1..${mushaf.pageCount} page range.',
        );
      }

      if (line.lineNumber < 1 || line.lineNumber > mushaf.linesPerPage) {
        yield IntegrityIssue(
          code: 'mushaf_line_out_of_range',
          severity: IntegritySeverity.error,
          message:
              'Mushaf ${mushaf.id} page ${line.pageNumber} line ${line.lineNumber} is outside its '
              'declared 1..${mushaf.linesPerPage} lines-per-page range.',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkOrderedMushafLines(
    QuranDatasetPayload payload,
  ) sync* {
    final lineNumbersByPage = <(int, int), List<int>>{};
    for (final line in payload.mushafLines) {
      lineNumbersByPage
          .putIfAbsent((line.mushafId, line.pageNumber), () => [])
          .add(line.lineNumber);
    }

    for (final entry in lineNumbersByPage.entries) {
      final (mushafId, pageNumber) = entry.key;
      final lineNumbers = entry.value;
      final sorted = [...lineNumbers]..sort();
      final expected = List.generate(lineNumbers.length, (i) => i + 1);

      if (!_listEquals(sorted, expected)) {
        yield IntegrityIssue(
          code: 'mushaf_lines_not_contiguous',
          severity: IntegritySeverity.error,
          message:
              'Mushaf $mushafId page $pageNumber has line numbers $sorted '
              '(expected a contiguous 1..${lineNumbers.length} sequence with no gaps or duplicates).',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkLineWordRanges(
    QuranDatasetPayload payload,
  ) sync* {
    final ayahIds = payload.ayahs.map((a) => a.id).toSet();

    for (final line in payload.mushafLines) {
      final hasStart = line.startAyahId != null;
      final hasEnd = line.endAyahId != null;

      if (line.lineType != MushafLineType.quranText) {
        continue;
      }

      if (!hasStart ||
          !hasEnd ||
          line.startWordIndex == null ||
          line.endWordIndex == null) {
        yield IntegrityIssue(
          code: 'line_missing_word_range',
          severity: IntegritySeverity.error,
          message:
              'Mushaf ${line.mushafId} page ${line.pageNumber} line ${line.lineNumber} is a Quran-text '
              'line but is missing its start/end ayah or word index.',
        );
        continue;
      }

      if (!ayahIds.contains(line.startAyahId) ||
          !ayahIds.contains(line.endAyahId)) {
        yield IntegrityIssue(
          code: 'line_references_unknown_ayah',
          severity: IntegritySeverity.error,
          message:
              'Mushaf ${line.mushafId} page ${line.pageNumber} line ${line.lineNumber} references an '
              'ayah id not present in the dataset.',
        );
        continue;
      }

      final startsAfterEnds =
          line.startAyahId! > line.endAyahId! ||
          (line.startAyahId == line.endAyahId &&
              line.startWordIndex! > line.endWordIndex!);

      if (startsAfterEnds) {
        yield IntegrityIssue(
          code: 'line_range_reversed',
          severity: IntegritySeverity.error,
          message:
              'Mushaf ${line.mushafId} page ${line.pageNumber} line ${line.lineNumber} has a start '
              'position after its end position.',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkNavigationRangeBoundaries(
    QuranDatasetPayload payload,
  ) sync* {
    final ayahCountBySurah = {
      for (final s in payload.surahs) s.surahNo: s.ayahCount,
    };

    for (final range in payload.navigationRanges) {
      final ayahCount = ayahCountBySurah[range.surahNo];
      if (ayahCount == null) {
        yield IntegrityIssue(
          code: 'navigation_range_unknown_surah',
          severity: IntegritySeverity.error,
          message:
              'A ${range.type.name} range references unknown surah ${range.surahNo}.',
        );
        continue;
      }

      final withinBounds =
          range.startAyahNo >= 1 &&
          range.endAyahNo <= ayahCount &&
          range.startAyahNo <= range.endAyahNo;

      if (!withinBounds) {
        yield IntegrityIssue(
          code: 'navigation_range_invalid_bounds',
          severity: IntegritySeverity.error,
          message:
              '${range.type.name} ${range.unitNo} in surah ${range.surahNo} has verse range '
              '${range.startAyahNo}-${range.endAyahNo}, outside valid bounds 1-$ayahCount.',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkNoMissingText(
    QuranDatasetPayload payload,
  ) sync* {
    final ayahIdsWithWords = payload.ayahWords.map((w) => w.ayahId).toSet();

    for (final ayah in payload.ayahs) {
      if (!ayahIdsWithWords.contains(ayah.id)) {
        yield IntegrityIssue(
          code: 'ayah_missing_text',
          severity: IntegritySeverity.error,
          message:
              'Ayah ${ayah.chapterNo}:${ayah.verseNo} (id ${ayah.id}) has no word text in any script.',
        );
      }
    }

    for (final word in payload.ayahWords) {
      if (word.text.trim().isEmpty) {
        yield IntegrityIssue(
          code: 'ayah_word_blank',
          severity: IntegritySeverity.error,
          message:
              'Ayah ${word.ayahId}, word ${word.wordIndex} (script ${word.scriptId}) has blank text.',
        );
      }
    }
  }

  Iterable<IntegrityIssue> _checkDatasetMetadata(
    QuranDatasetPayload payload,
  ) sync* {
    final metadata = payload.metadata;

    if (metadata.datasetVersion.trim().isEmpty) {
      yield const IntegrityIssue(
        code: 'metadata_missing_version',
        severity: IntegritySeverity.error,
        message: 'Dataset metadata is missing a datasetVersion.',
      );
    }

    if (metadata.contentHash.trim().isEmpty) {
      yield const IntegrityIssue(
        code: 'metadata_missing_hash',
        severity: IntegritySeverity.error,
        message: 'Dataset metadata is missing a contentHash.',
      );
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
