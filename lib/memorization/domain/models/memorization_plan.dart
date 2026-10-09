/// What a plan's daily amount is counted in.
enum PlanUnit { ayahs, halfPages, pages }

/// A memorization plan: [fromAyah]..[toAyah] (stable ayah ids, inclusive),
/// learned [amount] [unit]s a day on its [studyDays].
class MemorizationPlan {
  const MemorizationPlan({
    this.id,
    required this.fromAyah,
    required this.toAyah,
    this.unit = PlanUnit.pages,
    this.amount = 1,
    this.studyDays = everyDay,
    this.backward = false,
    this.active = true,
    required this.createdAt,
  });

  /// `null` until stored.
  final int? id;
  final int fromAyah, toAyah;
  final PlanUnit unit;

  /// Units a day (whole: ayahs, half-pages or pages).
  final int amount;

  /// The weekdays to learn on (`DateTime.monday`..`DateTime.sunday`), at
  /// least one.
  final Set<int> studyDays;

  static const everyDay = {1, 2, 3, 4, 5, 6, 7};

  /// Surahs from the last to the first (An-Nas, then Al-Falaq, ...); the
  /// ayahs of a surah are always learned in order.
  final bool backward;
  final bool active;
  final DateTime createdAt;

  /// Whether [day] is a study day.
  bool studiesOn(DateTime day) => studyDays.contains(day.weekday);

  /// [studyDays] as bits: bit `weekday - 1` per day.
  int get weekdayMask => studyDays.fold(0, (m, d) => m | 1 << (d - 1));

  static Set<int> weekdaysOf(int mask) => {
    for (var d = 1; d <= 7; d++)
      if (mask & 1 << (d - 1) != 0) d,
  };

  MemorizationPlan copyWith({
    int? id,
    int? fromAyah,
    int? toAyah,
    PlanUnit? unit,
    int? amount,
    Set<int>? studyDays,
    bool? backward,
    bool? active,
  }) => MemorizationPlan(
    id: id ?? this.id,
    fromAyah: fromAyah ?? this.fromAyah,
    toAyah: toAyah ?? this.toAyah,
    unit: unit ?? this.unit,
    amount: amount ?? this.amount,
    studyDays: studyDays ?? this.studyDays,
    backward: backward ?? this.backward,
    active: active ?? this.active,
    createdAt: createdAt,
  );
}
