/// The verified QPC Hafs display-word manifest — verse-by-verse mode's
/// Quran text source, kept entirely separate from canonical `AyahWord`
/// (Tanzil) and from Mushaf mode's `MushafToken` (QPC V2). See
/// `docs/QURAN_DATA_PROVENANCE.md` §17 for the full provenance and
/// validation this manifest is built from
/// (`tool/quran_data/build_qpc_hafs_display.dart`).
///
/// Deliberately a plain class, not `@freezed`: [wordsByAyahId] holds real
/// Quran text for 6,235 ayahs, loaded once by a `keepAlive` provider and
/// never rebuilt — freezed's generated `==`/`hashCode`/`toString` would
/// only ever pay for deep-comparing/printing a large map no caller needs
/// to compare or print.
class QpcHafsDisplayManifest {
  const QpcHafsDisplayManifest({
    required this.schemaVersion,
    required this.sourceHash,
    required this.importedAyahCount,
    required this.excludedAyahIds,
    required this.wordsByAyahId,
  });

  final int schemaVersion;
  final String sourceHash;
  final int importedAyahCount;

  /// Ayahs the build-time validation excluded rather than guessed at —
  /// currently just Surah 37 ayah 130 (37130), where Tanzil and QPC Hafs
  /// segment the compound name "الياسين" into a different number of words.
  /// A real orthographic difference between the two sources, not a data
  /// error — see the build script's own doc comment.
  final List<int> excludedAyahIds;

  /// One entry per successfully validated ayah: an ordered word list whose
  /// length exactly matches that ayah's real `AyahWord` count, so a caller
  /// holding both can zip them index-for-index and know word `i` in each
  /// refers to the same canonical word. Ayahs in [excludedAyahIds], or any
  /// ayah this manifest doesn't cover at all, are absent here — callers
  /// must treat a missing key as "no QPC Hafs display text available for
  /// this ayah" and fall back to canonical text, never as an error.
  final Map<int, List<String>> wordsByAyahId;
}
