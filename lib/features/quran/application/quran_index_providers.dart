import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../quran/domain/models/mushaf_models.dart';
import '../../../quran/domain/models/navigation_models.dart';
import '../../../quran/domain/models/surah_models.dart';
import '../../../quran/domain/quran_location_path.dart';
import '../../../quran/domain/models/quran_location.dart';
import '../../../quran/quran_providers.dart';

part 'quran_index_providers.g.dart';

/// Placeholder default script code for [defaultMushafProvider]'s lookup.
///
/// No script-selection preference exists yet (Settings/Localization is
/// Milestone 14) — this is the one hardcoded value the Page navigator tab
/// depends on until a real user preference replaces it. Harmless today
/// regardless of its exact value, since the live app's Quran dataset is
/// empty (`docs/ARCHITECTURE.md` §11b) and every `QuranScript` lookup
/// resolves to nothing either way.
const defaultQuranScriptCode = 'uthmani';

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
  final languageCode =
      ref.watch(localeControllerProvider)?.languageCode ?? 'en';

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
/// [defaultQuranScriptCode]. `null` means no matching Mushaf is installed
/// (the "unavailable resource" state the Page tab must render honestly —
/// true for every install today, since no dataset import path exists yet).
@riverpod
Future<Mushaf?> defaultMushaf(Ref ref) async {
  final repository = ref.watch(quranRepositoryProvider);
  return repository.getMushaf(scriptCode: defaultQuranScriptCode);
}

const _recentQuranLocationPrefKey = 'quran.recent_location';

/// The last [QuranLocation] the user navigated to from the Quran index,
/// persisted via [BrowserStorage] so it survives app restarts — the
/// milestone's "remember recent/current context where appropriate"
/// requirement. `null` means none has been recorded yet.
@Riverpod(keepAlive: true)
class RecentQuranLocationController extends _$RecentQuranLocationController {
  @override
  QuranLocation? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_recentQuranLocationPrefKey);
    if (stored == null) return;
    final location = quranLocationFromPath(stored);
    if (location != null) {
      state = location;
    }
  }

  Future<void> record(QuranLocation location) async {
    state = location;
    await ref
        .read(browserStorageProvider)
        .setString(_recentQuranLocationPrefKey, quranLocationPath(location));
  }
}
