import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core_providers.dart';

/// A notification's sound: the phone's usual one, none, one the app
/// brings (an Android raw resource, an iPhone's Library/Sounds file — by
/// the same name), or a sound on the phone (an Android content URI).
class ReminderSound {
  const ReminderSound._({
    this.bundled,
    this.uri,
    this.silent = false,
    this.vibrate = true,
  });

  /// The phone's notification sound.
  static const standard = ReminderSound._();

  /// No sound, no vibration.
  static const none = ReminderSound._(silent: true, vibrate: false);

  /// No sound; a vibration (Android: an iPhone has no vibration without
  /// a sound).
  static const vibrateOnly = ReminderSound._(silent: true);

  /// The app's sound [name] (`adhan_madinah`: res/raw/adhan_madinah.ogg on
  /// Android, Library/Sounds/adhan_madinah.caf on an iPhone).
  const ReminderSound.bundled(String name) : this._(bundled: name);

  /// A sound on the phone, chosen in Android's sound picker.
  const ReminderSound.device(String uri) : this._(uri: uri);

  final String? bundled, uri;
  final bool silent;

  /// Whether it vibrates (where the phone vibrates for notifications).
  final bool vibrate;
}

/// Schedules local notifications — the platform adapter behind the daily
/// memorization reminder (`docs/MEMORIZATION_MILESTONE.md`, M5) and the
/// khatmah's reminder of each day's pages. Callers never check the
/// platform themselves: [supported] says whether this one can.
abstract class DailyReminderScheduler {
  bool get supported;

  /// Sets up the plugin (once, however often it is called).
  Future<void> initialize();

  /// [handler] runs when a notification scheduled with [payload] is tapped
  /// (also when it launched the app, even before this was called).
  void onOpen(String payload, void Function() handler);

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

  /// Cancels the daily memorization reminder.
  Future<void> cancel();

  /// Shows a notification once, at [at] local time (replacing any with the
  /// same [id]); a tap runs [payload]'s [onOpen] handler. With [sound] (on
  /// Android fixed for its channel: a channel of its own for each sound);
  /// [exact]: at the minute, where the phone allows exact alarms
  /// ([exactAllowed]), else within a few minutes.
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
  });

  /// Whether notifications may come at the exact minute (Android's
  /// "Alarms & reminders" access; elsewhere always).
  Future<bool> exactAllowed();

  /// Opens the phone's setting for exact alarms (Android).
  Future<void> requestExact();

  /// Shows a notification every day at [hour]:[minute] local time — or,
  /// with [weekday] ([DateTime.monday] … [DateTime.sunday]), every week on
  /// that day — one pending notification however long it repeats (an
  /// iPhone keeps only 64). A tap runs [payload]'s [onOpen] handler.
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
  });

  /// Cancels the notifications with these [ids].
  Future<void> cancelIds(Iterable<int> ids);

  /// Cancels every notification the app scheduled.
  Future<void> cancelAll();
}

/// The memorization reminder's payload — also what a tap on one scheduled
/// before payloads existed (no payload) opens.
const memorizeReminderPayload = 'memorize';

/// Android and iOS: `flutter_local_notifications`, repeating daily at the
/// local time (Android: inexact, no exact-alarm permission).
class LocalNotificationsReminderScheduler implements DailyReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialized;
  final _handlers = <String, void Function()>{};

  /// The payload of the notification that launched the app, until its
  /// handler is there.
  String? _pending;

  static const _id = 1;
  static const _channelId = 'memorization_reminder';

  @override
  bool get supported => true;

  @override
  Future<void> initialize() => _initialized ??= _initialize();

  @override
  void onOpen(String payload, void Function() handler) {
    _handlers[payload] = handler;
    if (_pending == payload) {
      _pending = null;
      handler();
    }
  }

  void _open(String? payload) {
    final key = payload ?? memorizeReminderPayload;
    final handler = _handlers[key];
    if (handler == null) {
      _pending = key;
    } else {
      handler();
    }
  }

  Future<void> _initialize() async {
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
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _open(launch!.notificationResponse?.payload);
    }
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
      payload: memorizeReminderPayload,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _id);

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
    final bundled = sound.bundled, uri = sound.uri;
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime(
        tz.local,
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      ),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          // (An adhan: shown at the top of the screen too.)
          importance: bundled != null || uri != null
              ? Importance.high
              : Importance.defaultImportance,
          priority: bundled != null || uri != null
              ? Priority.high
              : Priority.defaultPriority,
          playSound: !sound.silent,
          enableVibration: sound.vibrate,
          sound: bundled != null
              ? RawResourceAndroidNotificationSound(bundled)
              : uri != null
              ? UriAndroidNotificationSound(uri)
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: !sound.silent,
          sound: bundled == null ? null : '$bundled.caf',
        ),
      ),
      androidScheduleMode: exact && await exactAllowed()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<bool> exactAllowed() async {
    final android = _android;
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
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
    // The first time: today's (or that weekday's) yet to come.
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      at = tz.TZDateTime(tz.local, at.year, at.month, at.day + 1, hour, minute);
    }
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: at,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// The web: no reminder.
class UnsupportedReminderScheduler implements DailyReminderScheduler {
  const UnsupportedReminderScheduler();

  @override
  bool get supported => false;
  @override
  Future<void> initialize() async {}
  @override
  void onOpen(String payload, void Function() handler) {}
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
  }) async {}
  @override
  Future<bool> exactAllowed() async => false;
  @override
  Future<void> requestExact() async {}
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
  }) async {}
  @override
  Future<void> cancelIds(Iterable<int> ids) async {}
  @override
  Future<void> cancelAll() async {}
}

final dailyReminderSchedulerProvider = Provider<DailyReminderScheduler>(
  (ref) =>
      ref.watch(platformCapabilitiesProvider).supportsScheduledNotifications
      ? LocalNotificationsReminderScheduler()
      : const UnsupportedReminderScheduler(),
);
