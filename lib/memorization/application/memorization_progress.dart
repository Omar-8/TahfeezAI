import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quran/domain/models/navigation_models.dart';
import '../../quran/quran_providers.dart';
import '../domain/progress_map.dart';
import 'memorization_today.dart';

/// Each juz's ayahs (stable ids, Quran order), from the dataset's juz
/// ranges.
final juzAyahsProvider = FutureProvider<Map<int, List<int>>>((ref) async {
  final ranges = await ref
      .watch(quranRepositoryProvider)
      .getNavigationRanges(NavigationUnitType.juz);
  final juz = <int, List<int>>{};
  for (final r in ranges) {
    final ayahs = juz[r.unitNo] ??= [];
    for (var a = r.startAyahNo; a <= r.endAyahNo; a++) {
      ayahs.add(r.surahNo * 1000 + a);
    }
  }
  for (final ayahs in juz.values) {
    ayahs.sort();
  }
  return juz;
});

/// The whole Quran's memorization, juz by juz and page by page (M4), live.
final progressMapProvider = FutureProvider<ProgressMap>((ref) async {
  final memories = await ref.watch(ayahMemoriesProvider.future);
  final pages = await ref.watch(ayahPagesProvider.future);
  final juz = await ref.watch(juzAyahsProvider.future);
  return ProgressMapBuilder.build(
    memories: memories,
    pages: pages,
    juzOfAyah: {
      for (final MapEntry(key: j, value: ayahs) in juz.entries)
        for (final a in ayahs) a: j,
    },
    now: ref.read(memorizationClockProvider)(),
  );
});
