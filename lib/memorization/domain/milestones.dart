import 'models/memorization_models.dart';

/// A gentle milestone, shown once when first reached: a juz or a surah
/// memorized, a share of the Quran, days in a row of recitation. Only ayahs
/// recited from memory count — not ones only marked as known.
sealed class Milestone {
  const Milestone();

  /// Stable, for remembering it was shown.
  String get id;

  /// Which to show when several are reached at once: the highest.
  int get rank;
}

class JuzMilestone extends Milestone {
  const JuzMilestone(this.juz);

  final int juz;

  @override
  String get id => 'juz-$juz';

  @override
  int get rank => 3;
}

class SurahMilestone extends Milestone {
  const SurahMilestone(this.surah);

  final int surah;

  @override
  String get id => 'surah-$surah';

  @override
  int get rank => 1;
}

class ShareMilestone extends Milestone {
  const ShareMilestone(this.percent);

  final int percent;

  @override
  String get id => 'share-$percent';

  @override
  int get rank => 4;
}

class StreakMilestone extends Milestone {
  const StreakMilestone(this.days);

  final int days;

  @override
  String get id => 'streak-$days';

  @override
  int get rank => 2;
}

abstract final class Milestones {
  static const shares = [1, 5, 10, 25, 50, 75, 100];
  static const streaks = [3, 7, 14, 30, 50, 100, 200, 365];

  /// Every milestone reached: [juzAyahs] each juz's ayahs, [surahAyahs]
  /// each surah's ayah count, [totalAyahs] the Quran's, [streak] the
  /// current streak in days.
  static List<Milestone> reached({
    required Map<int, AyahMemory> memories,
    required Map<int, List<int>> juzAyahs,
    required Map<int, int> surahAyahs,
    required int totalAyahs,
    required int streak,
  }) {
    final known = {
      for (final m in memories.values)
        if (m.status == MemoryStatus.memorized && m.verified) m.ayahId,
    };
    final bySurah = <int, int>{};
    for (final a in known) {
      bySurah[a ~/ 1000] = (bySurah[a ~/ 1000] ?? 0) + 1;
    }
    return [
      for (final MapEntry(key: juz, value: ayahs) in juzAyahs.entries)
        if (ayahs.isNotEmpty && ayahs.every(known.contains)) JuzMilestone(juz),
      for (final MapEntry(key: surah, value: n) in surahAyahs.entries)
        if (n > 0 && (bySurah[surah] ?? 0) >= n) SurahMilestone(surah),
      if (totalAyahs > 0)
        for (final p in shares)
          if (known.length * 100 >= p * totalAyahs) ShareMilestone(p),
      for (final d in streaks)
        if (streak >= d) StreakMilestone(d),
    ];
  }
}
