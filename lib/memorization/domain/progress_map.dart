import 'models/memorization_models.dart';
import 'strength_model.dart';

/// One Mushaf page's memorization.
class PageProgress {
  const PageProgress({
    required this.page,
    required this.juz,
    required this.ayahIds,
    required this.memorized,
    required this.unverified,
    this.strength,
  });

  final int page;

  /// The juz the page's first ayah is in.
  final int juz;

  /// The page's ayahs (stable ids, Quran order).
  final List<int> ayahIds;

  /// Its ayahs memorized, of them [unverified] marked as known and not yet
  /// recited.
  final int memorized, unverified;

  /// The mean strength of its recited memorized ayahs; `null` when none.
  final double? strength;

  int get ayahs => ayahIds.length;
  bool get isEmpty => memorized == 0;

  /// The memorized ayahs (stable ids, Quran order) — what revising the page
  /// recites.
  List<int> memorizedIn(Map<int, AyahMemory> memories) => [
    for (final a in ayahIds)
      if (memories[a]?.status == MemoryStatus.memorized) a,
  ];
}

/// One juz's pages.
class JuzProgress {
  const JuzProgress(this.juz, this.pages);

  final int juz;
  final List<PageProgress> pages;

  int get ayahs => pages.fold(0, (n, p) => n + p.ayahs);
  int get memorized => pages.fold(0, (n, p) => n + p.memorized);
}

/// The whole Quran's memorization, juz by juz and page by page
/// (`docs/MEMORIZATION_MILESTONE.md`, M4).
class ProgressMap {
  const ProgressMap({
    required this.juz,
    required this.ayahs,
    required this.memorized,
    required this.unverified,
    required this.weak,
    this.strength,
  });

  final List<JuzProgress> juz;

  /// Ayahs in the Quran, memorized, and of those not yet recited.
  final int ayahs, memorized, unverified;

  /// The mean strength of every recited memorized ayah; `null` when none.
  final double? strength;

  /// Pages whose strength is below the weak line, weakest first.
  final List<PageProgress> weak;

  double get share => ayahs == 0 ? 0 : memorized / ayahs;
}

abstract final class ProgressMapBuilder {
  /// A page under this strength is weak.
  static const weakBelow = 0.8;

  /// [pages]: each ayah's Mushaf page; [juzOfAyah]: each ayah's juz.
  static ProgressMap build({
    required Map<int, AyahMemory> memories,
    required Map<int, int> pages,
    required Map<int, int> juzOfAyah,
    required DateTime now,
    int weakLimit = 10,
  }) {
    final byPage = <int, List<int>>{};
    for (final a in pages.keys.toList()..sort()) {
      (byPage[pages[a]!] ??= []).add(a);
    }
    var memorized = 0, unverified = 0, strengthSum = 0.0, strengthCount = 0;
    final juz = <int, List<PageProgress>>{};
    for (final page in byPage.keys.toList()..sort()) {
      final ayahIds = byPage[page]!;
      var m = 0, u = 0, sum = 0.0, n = 0;
      for (final a in ayahIds) {
        final memory = memories[a];
        if (memory?.status != MemoryStatus.memorized) continue;
        m++;
        if (!memory!.verified) u++;
        final s = StrengthModel.strength(memory, now);
        if (s != null) {
          sum += s;
          n++;
        }
      }
      memorized += m;
      unverified += u;
      strengthSum += sum;
      strengthCount += n;
      final j = juzOfAyah[ayahIds.first] ?? 0;
      (juz[j] ??= []).add(
        PageProgress(
          page: page,
          juz: j,
          ayahIds: ayahIds,
          memorized: m,
          unverified: u,
          strength: n == 0 ? null : sum / n,
        ),
      );
    }
    final weak = [
      for (final ps in juz.values)
        for (final p in ps)
          if (p.strength != null && p.strength! < weakBelow) p,
    ]..sort((a, b) => a.strength!.compareTo(b.strength!));
    return ProgressMap(
      juz: [for (final j in juz.keys.toList()..sort()) JuzProgress(j, juz[j]!)],
      ayahs: pages.length,
      memorized: memorized,
      unverified: unverified,
      strength: strengthCount == 0 ? null : strengthSum / strengthCount,
      weak: weak.take(weakLimit).toList(),
    );
  }
}
