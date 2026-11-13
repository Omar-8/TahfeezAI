import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_providers.dart';

const _enabledKey = 'memorize.reminder_enabled';
const _minutesKey = 'memorize.reminder_minutes';

/// The daily memorization reminder's settings: on or off, and its time
/// (minutes after midnight, local time).
typedef MemorizationReminder = ({bool enabled, int minutes});

/// The opt-in daily reminder (`docs/MEMORIZATION_MILESTONE.md`, M5):
/// persisted, rescheduled on every start (so its text follows the app's
/// language), and opening the Memorize tab when tapped. Off by default.
class MemorizationReminderController extends Notifier<MemorizationReminder> {
  static const defaultMinutes = 20 * 60;

  DailyReminderScheduler get _scheduler =>
      ref.read(dailyReminderSchedulerProvider);

  @override
  MemorizationReminder build() {
    _restore();
    return (enabled: false, minutes: defaultMinutes);
  }

  Future<void> _restore() async {
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    scheduler.onOpen(memorizeReminderPayload, _openMemorize);
    await scheduler.initialize();
    final storage = ref.read(browserStorageProvider);
    final enabled = await storage.getBool(_enabledKey) ?? false;
    final minutes =
        int.tryParse(await storage.getString(_minutesKey) ?? '') ??
        defaultMinutes;
    if (!ref.mounted) return;
    state = (enabled: enabled, minutes: minutes);
    if (enabled) await _schedule();
  }

  void _openMemorize() {
    // After the first frame: the router may not be built yet at launch.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted) ref.read(appRouterProvider).go(AppRoutes.memorize);
    });
  }

  /// Turns the reminder on (asking for permission first) or off. `false`
  /// when it could not be turned on (permission denied).
  Future<bool> setEnabled(bool enabled) async {
    final scheduler = _scheduler;
    if (enabled && !await scheduler.requestPermission()) return false;
    state = (enabled: enabled, minutes: state.minutes);
    await ref.read(browserStorageProvider).setBool(_enabledKey, enabled);
    if (enabled) {
      await _schedule();
    } else {
      await scheduler.cancel();
    }
    return true;
  }

  Future<void> setTime(int minutes) async {
    state = (enabled: state.enabled, minutes: minutes);
    await ref.read(browserStorageProvider).setString(_minutesKey, '$minutes');
    if (state.enabled) await _schedule();
  }

  Future<void> _schedule() async {
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    await _scheduler.schedule(
      hour: state.minutes ~/ 60,
      minute: state.minutes % 60,
      title: l10n.memReminderNotifTitle,
      body: l10n.memReminderNotifBody,
      channelName: l10n.memReminderChannel,
    );
  }
}

final memorizationReminderProvider =
    NotifierProvider<MemorizationReminderController, MemorizationReminder>(
      MemorizationReminderController.new,
    );
