import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';

/// Records what the app schedules instead of notifying.
class FakeReminderScheduler implements DailyReminderScheduler {
  FakeReminderScheduler({this.granted = true});

  final bool granted;

  /// The daily memorization reminder's schedules: (hour, minute, title).
  final scheduled = <(int, int, String)>[];
  var cancelled = 0;

  /// The one-off notifications pending, by id.
  final once = <int, ({DateTime at, String title, String body})>{};
  final handlers = <String, void Function()>{};

  @override
  bool get supported => true;
  @override
  Future<void> initialize() async {}
  @override
  void onOpen(String payload, void Function() handler) =>
      handlers[payload] = handler;
  @override
  Future<bool> requestPermission() async => granted;
  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
  }) async => scheduled.add((hour, minute, title));
  @override
  Future<void> cancel() async => cancelled++;
  @override
  Future<void> scheduleOnce({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String payload,
  }) async => once[id] = (at: at, title: title, body: body);
  @override
  Future<void> cancelIds(Iterable<int> ids) async => ids.forEach(once.remove);
  @override
  Future<void> cancelAll() async => once.clear();
}
