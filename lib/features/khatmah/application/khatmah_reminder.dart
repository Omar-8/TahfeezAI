import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_providers.dart';
import '../../../memorization/application/memorization_today.dart'
    show memorizationClockProvider;
import '../domain/khatmah.dart';
import 'khatmah_controller.dart';

const _enabledKey = 'khatmah.reminder_enabled';
const _minutesKey = 'khatmah.reminder_minutes';

/// The khatmah reminder's settings: on or off, and its time (minutes after
/// midnight, local time).
typedef KhatmahReminder = ({bool enabled, int minutes});

/// The khatmah's daily reminder, off by default: a notification each day
/// at its time with that day's pages ("Today: pages 81–100"). The next
/// [ahead] days are scheduled one by one, again whenever the khatmah
/// changes (a page read, its days, its end) and at every start — so a
/// day's pages are always those left, today's is left out once they are
/// read, and none comes after the khatmah is done. A tap opens Home.
class KhatmahReminderController extends Notifier<KhatmahReminder> {
  static const defaultMinutes = 7 * 60;

  /// How many days ahead are scheduled.
  static const ahead = 14;

  /// The notifications' ids: one per day ahead.
  static final ids = [for (var i = 0; i < ahead; i++) 100 + i];

  static const payload = 'khatmah';

  DailyReminderScheduler get _scheduler =>
      ref.read(dailyReminderSchedulerProvider);

  @override
  KhatmahReminder build() {
    ref.listen(khatmahProvider, (_, next) {
      if (next.hasValue && state.enabled) _reschedule();
    });
    _restore();
    return (enabled: false, minutes: defaultMinutes);
  }

  Future<void> _restore() async {
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    scheduler.onOpen(payload, _openHome);
    await scheduler.initialize();
    final storage = ref.read(browserStorageProvider);
    final enabled = await storage.getBool(_enabledKey) ?? false;
    final minutes =
        int.tryParse(await storage.getString(_minutesKey) ?? '') ??
        defaultMinutes;
    if (!ref.mounted) return;
    state = (enabled: enabled, minutes: minutes);
    if (enabled) await _reschedule();
  }

  void _openHome() {
    // After the first frame: the router may not be built yet at launch.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (ref.mounted) ref.read(appRouterProvider).go(AppRoutes.home);
    });
  }

  /// Turns the reminder on (asking for permission first) or off. `false`
  /// when it could not be turned on (permission denied).
  Future<bool> setEnabled(bool enabled) async {
    final scheduler = _scheduler;
    if (enabled && !await scheduler.requestPermission()) return false;
    state = (enabled: enabled, minutes: state.minutes);
    await ref.read(browserStorageProvider).setBool(_enabledKey, enabled);
    await _reschedule();
    return true;
  }

  Future<void> setTime(int minutes) async {
    state = (enabled: state.enabled, minutes: minutes);
    await ref.read(browserStorageProvider).setString(_minutesKey, '$minutes');
    await _reschedule();
  }

  /// The days ahead scheduled again from the khatmah as it is now (or
  /// none: off, no khatmah, or done).
  Future<void> _reschedule() async {
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    await scheduler.cancelIds(ids);
    final khatmah = ref.read(khatmahProvider).value;
    if (!state.enabled || khatmah == null) return;
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    final plan = khatmahReminderPlan(
      khatmah,
      ref.read(memorizationClockProvider)(),
      state.minutes,
      ahead: ahead,
    );
    for (final (i, (at, share)) in plan.indexed) {
      final past = share.dayNo > share.days;
      await scheduler.scheduleOnce(
        id: ids[i],
        at: at,
        title: past
            ? l10n.khatmahTitle
            : '${l10n.khatmahTitle} · '
                  '${l10n.khatmahDayOf(share.dayNo, share.days)}',
        body: [
          if (past) l10n.khatmahPastEnd,
          share.pages == 1
              ? l10n.khatmahTodayPage(share.from)
              : l10n.khatmahTodayPages(share.from, share.to),
        ].join('\n'),
        channelId: 'khatmah_reminder',
        channelName: l10n.khatmahReminderChannel,
        payload: payload,
      );
    }
  }
}

final khatmahReminderProvider =
    NotifierProvider<KhatmahReminderController, KhatmahReminder>(
      KhatmahReminderController.new,
    );
