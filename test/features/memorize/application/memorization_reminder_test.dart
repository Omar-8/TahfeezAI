import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:tahfeez_ai/core/localization/locale_controller.dart';
import 'package:tahfeez_ai/core/notifications/daily_reminder_scheduler.dart';
import 'package:tahfeez_ai/features/memorize/application/memorization_reminder.dart';

import '../../../test_helpers/fake_reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  ProviderContainer container(FakeReminderScheduler scheduler) {
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
    final scheduler = FakeReminderScheduler();
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
    final scheduler = FakeReminderScheduler(granted: false);
    final c = container(scheduler);
    final reminder = c.read(memorizationReminderProvider.notifier);
    expect(await reminder.setEnabled(true), isFalse);
    expect(c.read(memorizationReminderProvider).enabled, isFalse);
    expect(scheduler.scheduled, isEmpty);
  });
}
