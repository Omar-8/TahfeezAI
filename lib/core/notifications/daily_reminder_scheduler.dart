import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core_providers.dart';

/// Schedules one local notification a day — the platform adapter behind
/// the daily memorization reminder (`docs/MEMORIZATION_MILESTONE.md`, M5).
/// Callers never check the platform themselves: [supported] says whether
/// this one can.
abstract class DailyReminderScheduler {
  bool get supported;

  /// Sets up the plugin; [onOpen] runs when the reminder is tapped (also
  /// when it launched the app).
  Future<void> initialize({required void Function() onOpen});

  /// Asks for permission to notify; `true` once granted.
  Future<bool> requestPermission();

  /// Shows the reminder every day at [hour]:[minute] local time, replacing
  /// any earlier schedule.
  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
  });

  Future<void> cancel();
}

/// Android and iOS: `flutter_local_notifications`, repeating daily at the
/// local time (Android: inexact, no exact-alarm permission).
class LocalNotificationsReminderScheduler implements DailyReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _id = 1;
  static const _channelId = 'memorization_reminder';

  @override
  bool get supported => true;

  @override
  Future<void> initialize({required void Function() onOpen}) async {
    if (_initialized) return;
    _initialized = true;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone: UTC, the timezone package's default.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked when the reminder is turned on, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => onOpen(),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onOpen();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _id);
}

/// The web: no reminder.
class UnsupportedReminderScheduler implements DailyReminderScheduler {
  const UnsupportedReminderScheduler();

  @override
  bool get supported => false;
  @override
  Future<void> initialize({required void Function() onOpen}) async {}
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelName,
  }) async {}
  @override
  Future<void> cancel() async {}
}

final dailyReminderSchedulerProvider = Provider<DailyReminderScheduler>(
  (ref) =>
      ref.watch(platformCapabilitiesProvider).supportsScheduledNotifications
      ? LocalNotificationsReminderScheduler()
      : const UnsupportedReminderScheduler(),
);
