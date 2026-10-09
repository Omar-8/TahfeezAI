/// What a plan's daily amount is counted in.
enum PlanUnit { ayahs, halfPages, pages }

/// A memorization plan: [fromAyah]..[toAyah] (stable ayah ids, inclusive),
/// learned [amount] [unit]s a day on [daysPerWeek] days.
class MemorizationPlan {
  const MemorizationPlan({
    this.id,
    required this.fromAyah,
    required this.toAyah,
    this.unit = PlanUnit.pages,
    this.amount = 1,
    this.daysPerWeek = 7,
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

  /// 7, 6 (Friday off) or 5 (Thursday and Friday off).
  final int daysPerWeek;

  /// Surahs from the last to the first (An-Nas, then Al-Falaq, ...); the
  /// ayahs of a surah are always learned in order.
  final bool backward;
  final bool active;
  final DateTime createdAt;

  /// Whether [day] is a study day.
  bool studiesOn(DateTime day) => switch (daysPerWeek) {
    7 => true,
    6 => day.weekday != DateTime.friday,
    _ => day.weekday != DateTime.friday && day.weekday != DateTime.thursday,
  };

  MemorizationPlan copyWith({
    int? id,
    int? fromAyah,
    int? toAyah,
    PlanUnit? unit,
    int? amount,
    int? daysPerWeek,
    bool? backward,
    bool? active,
  }) => MemorizationPlan(
    id: id ?? this.id,
    fromAyah: fromAyah ?? this.fromAyah,
    toAyah: toAyah ?? this.toAyah,
    unit: unit ?? this.unit,
    amount: amount ?? this.amount,
    daysPerWeek: daysPerWeek ?? this.daysPerWeek,
    backward: backward ?? this.backward,
    active: active ?? this.active,
    createdAt: createdAt,
  );
}
