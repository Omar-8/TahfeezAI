import 'khatmah.dart';

/// A khatmah completed: the day it began, the day its last page was read,
/// and the days it was planned for.
class CompletedKhatmah {
  const CompletedKhatmah({
    required this.start,
    required this.end,
    required this.days,
  });

  /// [khatmahDay]s.
  final String start, end;
  final int days;

  /// The days it took, the first and last counted.
  int get tookDays =>
      DateTime.parse(end).difference(DateTime.parse(start)).inDays + 1;

  /// [khatmah], completed: on the day its last page was read.
  static CompletedKhatmah of(Khatmah khatmah) => CompletedKhatmah(
    start: khatmah.start,
    end: khatmah.readOn.values.fold(
      khatmah.start,
      (last, day) => day.compareTo(last) > 0 ? day : last,
    ),
    days: khatmah.days,
  );

  Map<String, Object?> toJson() => {'start': start, 'end': end, 'days': days};

  static CompletedKhatmah? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = json['start'], end = json['end'], days = json['days'];
    if (start is! String || end is! String || days is! int) return null;
    if (DateTime.tryParse(start) == null || DateTime.tryParse(end) == null) {
      return null;
    }
    return CompletedKhatmah(start: start, end: end, days: days);
  }
}
