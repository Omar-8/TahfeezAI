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

  /// Each one-off's sound, channel and whether exact, by id.
  final onceSound =
      <int, ({ReminderSound sound, String channelId, bool exact})>{};

  /// Whether exact alarms are allowed; [requestExact] calls.
  bool exact = true;
  var exactRequested = 0;
  @override
  Future<bool> exactAllowed() async => exact;
  @override
  Future<void> requestExact() async => exactRequested++;

  /// The repeating ones, by id: daily ([weekday] `null`) or weekly.
  final repeating =
      <
        int,
        ({int? weekday, int hour, int minute, String title, String payload})
      >{};
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
    ReminderSound sound = ReminderSound.standard,
    bool exact = false,
  }) async {
    once[id] = (at: at, title: title, body: body);
    onceSound[id] = (sound: sound, channelId: channelId, exact: exact);
  }

  @override
  Future<void> scheduleRepeating({
    required int id,
    int? weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String payload,
  }) async => repeating[id] = (
    weekday: weekday,
    hour: hour,
    minute: minute,
    title: title,
    payload: payload,
  );
  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      once.remove(id);
      onceSound.remove(id);
      repeating.remove(id);
    }
  }

  @override
  Future<void> cancelAll() async {
    once.clear();
    repeating.clear();
  }
}
