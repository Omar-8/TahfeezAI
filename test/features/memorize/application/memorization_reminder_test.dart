import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/features/memorize/application/memorization_reminder.dart';

class _Scheduler implements DailyReminderScheduler {
  _Scheduler({this.granted = true});

  final bool granted;
  final scheduled = <(int, int, String)>[];
  var cancelled = 0;

  @override
  bool get supported => true;
  @override
  Future<void> initialize({required void Function() onOpen}) async {}
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  ProviderContainer container(_Scheduler scheduler) {
    final c = ProviderContainer(
      overrides: [
        dailyReminderSchedulerProvider.overrideWithValue(scheduler),
        localeControllerProvider.overrideWithBuild((ref, _) => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('off by default; on schedules it daily at its time, in the app '
      'language; a new time reschedules; off cancels', () async {
    final scheduler = _Scheduler();
    final c = container(scheduler);
    final reminder = c.read(memorizationReminderProvider.notifier);
    expect(c.read(memorizationReminderProvider).enabled, isFalse);
    await Future<void>.delayed(Duration.zero);

    expect(await reminder.setEnabled(true), isTrue);
    expect(scheduler.scheduled.last, (20, 0, 'Time to memorize'));
    await reminder.setTime(6 * 60 + 30);
    expect(scheduler.scheduled.last.$1, 6);
    expect(scheduler.scheduled.last.$2, 30);
    await reminder.setEnabled(false);
    expect(scheduler.cancelled, 1);
    expect(c.read(memorizationReminderProvider).enabled, isFalse);
  });

  test('without permission it stays off', () async {
    final scheduler = _Scheduler(granted: false);
    final c = container(scheduler);
    final reminder = c.read(memorizationReminderProvider.notifier);
    expect(await reminder.setEnabled(true), isFalse);
    expect(c.read(memorizationReminderProvider).enabled, isFalse);
    expect(scheduler.scheduled, isEmpty);
  });
}
