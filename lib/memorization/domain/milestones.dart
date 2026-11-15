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

/// Surahs memorized since the last one was congratulated, together:
/// "You memorized Al-Ikhlas, Al-Falaq and An-Nas" (one or more).
class SurahsMilestone extends Milestone {
  const SurahsMilestone(this.surahs);

  final List<int> surahs;

  @override
  String get id => 'surahs-${surahs.join('-')}';

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

/// A khatmah complete: the whole Quran read in the khatmah begun on
/// [start] (`features/khatmah`) — shown when its last page is read, not
/// remembered like the others (it happens once by itself).
class KhatmahMilestone extends Milestone {
  const KhatmahMilestone(this.start);

  final String start;

  @override
  String get id => 'khatmah-$start';

  @override
  int get rank => 5;
}

/// What a lifetime count is of ([ActivityMilestone]).
enum ActivityKind { ayahs, words, mushafDays }

/// A lifetime count reached (owner, 2026-11-15): [amount] ayahs or words
/// recited, or days (counted in hours) spent in the Mushaf.
class ActivityMilestone extends Milestone {
  const ActivityMilestone(this.kind, this.amount);

  final ActivityKind kind;
  final int amount;

  @override
  String get id => 'activity-${kind.name}-$amount';

  @override
  int get rank => 2;
}

abstract final class Milestones {
  /// Ayahs recited (from memory or reading), words recited, days in the
  /// Mushaf (1 day = 24 hours there, in all).
  static const ayahsRecited = [1000, 5000, 10000, 25000, 50000, 100000];
  static const wordsRecited = [10000, 50000, 100000, 250000, 500000, 1000000];
  static const mushafDays = [1, 7, 14, 30, 60, 90, 180, 365];

  /// Every lifetime count reached.
  static List<ActivityMilestone> activity({
    required int recitedAyahs,
    required int recitedWords,
    required int mushafSeconds,
  }) => [
    for (final n in ayahsRecited)
      if (recitedAyahs >= n) ActivityMilestone(ActivityKind.ayahs, n),
    for (final n in wordsRecited)
      if (recitedWords >= n) ActivityMilestone(ActivityKind.words, n),
    for (final n in mushafDays)
      if (mushafSeconds >= n * 86400)
        ActivityMilestone(ActivityKind.mushafDays, n),
  ];

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
