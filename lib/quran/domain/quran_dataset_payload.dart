import 'models/ayah_models.dart';
import 'models/dataset_metadata.dart';
import 'models/mushaf_models.dart';
import 'models/navigation_models.dart';
import 'models/script_models.dart';
import 'models/surah_models.dart';

/// The full set of records a Quran dataset source must provide before it
/// can be imported.
///
/// This is the seam between "where the data comes from" (a bundled asset,
/// a downloaded file, a hand-built test fixture) and "how it gets into
/// Drift" ([QuranDatasetImporter], `lib/quran/data/import/`) — a dataset can
/// be entirely replaced by constructing a different [QuranDatasetPayload]
/// from a different source, with **no change to [QuranRepository] or its
/// implementation**. This is what makes Milestone 2's "dataset can be
/// replaced without rewriting UI" requirement concretely true rather than
/// aspirational.
///
/// Deliberately plain Dart, with no Drift/Flutter dependency, so it can be
/// constructed and validated (`dataset_integrity.dart`) in pure unit tests
/// without opening a database at all.
class QuranDatasetPayload {
  const QuranDatasetPayload({
    required this.surahs,
    required this.surahLocalizations,
    required this.ayahs,
    required this.ayahWords,
    required this.scripts,
    required this.scriptVariants,
    required this.mushafs,
    required this.mushafLines,
    required this.navigationRanges,
    required this.metadata,
  });

  final List<Surah> surahs;
  final List<SurahLocalization> surahLocalizations;
  final List<Ayah> ayahs;
  final List<AyahWord> ayahWords;
  final List<QuranScript> scripts;
  final List<QuranScriptVariant> scriptVariants;
  final List<Mushaf> mushafs;
  final List<MushafLine> mushafLines;
  final List<NavigationRange> navigationRanges;
  final DatasetMetadata metadata;
}
