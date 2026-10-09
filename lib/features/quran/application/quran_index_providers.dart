import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../quran/application/meaning_defaults.dart';
import '../../../quran/application/quran_script_code.dart';
import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/navigation_models.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/quran_providers.dart';

part 'quran_index_providers.g.dart';

/// One chapter enriched with its Arabic and current-UI-language localized
/// names, for the Surah index tab. Built from two batched
/// `getAllSurahLocalizations` calls (never per-chapter lookups — see that
/// method's doc comment) plus the one `getAllSurahs` call.
class IndexedSurah {
  const IndexedSurah({
    required this.surah,
    required this.arabicName,
    required this.localizedName,
  });

  final Surah surah;
  final String? arabicName;
  final String? localizedName;
}

@riverpod
Future<List<IndexedSurah>> indexedSurahs(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final languageCode = surahNameLanguage(
    ref.watch(localeControllerProvider)?.languageCode ?? 'en',
  );

  final surahs = await repository.getAllSurahs();
  final arabicLocalizations = await repository.getAllSurahLocalizations(
    languageCode: 'ar',
  );
  final localizedLocalizations = languageCode == 'ar'
      ? arabicLocalizations
      : await repository.getAllSurahLocalizations(languageCode: languageCode);

  final arabicBySurah = {for (final l in arabicLocalizations) l.surahNo: l};
  final localizedBySurah = {
    for (final l in localizedLocalizations) l.surahNo: l,
  };

  return [
    for (final surah in surahs)
      IndexedSurah(
        surah: surah,
        arabicName: arabicBySurah[surah.surahNo]?.name,
        localizedName: localizedBySurah[surah.surahNo]?.name,
      ),
  ];
}

/// One navigation unit (a Juz or a Hizb), aggregating every chapter segment
/// it spans, built by grouping a single `getNavigationRanges` query result
/// client-side rather than issuing one query per unit (30 for Juz, 60 for
/// Hizb) — the same "batch, don't N+1" discipline
/// `docs/ARCHITECTURE.md` §4a established for verse/word loading.
class IndexedNavigationUnit {
  const IndexedNavigationUnit({required this.unitNo, required this.ranges});

  final int unitNo;
  final List<NavigationRange> ranges;

  /// The chapter/verse this unit begins at — its first range in Mushaf
  /// order, since `getNavigationRanges` is already ordered by
  /// (unitNo, surahNo).
  NavigationRange get start => ranges.first;
}

@riverpod
Future<List<IndexedNavigationUnit>> indexedJuzList(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final ranges = await repository.getNavigationRanges(NavigationUnitType.juz);
  return _groupByUnit(ranges);
}

@riverpod
Future<List<IndexedNavigationUnit>> indexedHizbList(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final ranges = await repository.getNavigationRanges(NavigationUnitType.hizb);
  return _groupByUnit(ranges);
}

List<IndexedNavigationUnit> _groupByUnit(List<NavigationRange> ranges) {
  final byUnit = <int, List<NavigationRange>>{};
  for (final range in ranges) {
    (byUnit[range.unitNo] ??= []).add(range);
  }
  final unitNumbers = byUnit.keys.toList()..sort();
  return [
    for (final unitNo in unitNumbers)
      IndexedNavigationUnit(unitNo: unitNo, ranges: byUnit[unitNo]!),
  ];
}

/// The Mushaf the Page navigator tab jumps within, resolved from
/// [quranScriptCodeProvider]. `null` means no matching Mushaf is installed
/// (the "unavailable resource" state the Page tab must render honestly) —
/// still the normal state in a release build, or in a dev build without
/// the license-gated Mushaf dataset present; see
/// `docs/QURAN_DATA_PROVENANCE.md` §7.
@riverpod
Future<Mushaf?> defaultMushaf(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  final scriptCode = ref.watch(quranScriptCodeProvider);
  return repository.getMushaf(scriptCode: scriptCode);
}
