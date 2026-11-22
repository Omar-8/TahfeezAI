import 'dart:async';

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/notifications/daily_reminder_scheduler.dart';
import '../../../core/notifications/reminder_locale.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/athkar.dart';

/// Morning or evening.
enum AthkarTime {
  morning(6 * 60 + 30, 300),
  evening(17 * 60 + 30, 320);

  const AthkarTime(this.defaultMinutes, this.firstId);

  /// Its time unless changed (minutes after midnight, local time).
  final int defaultMinutes;

  /// Its notification's id (and the next 13: those once scheduled a day
  /// at a time, cleared).
  final int firstId;
}

/// One reminder's settings.
typedef AthkarReminderSetting = ({bool enabled, int minutes});

/// The morning and evening athkar reminders (owner, 2026-11-21), off by
/// default: a notification each day at its time; a tap opens Morning &
/// Evening, each repeating daily (scheduled again at every start).
class AthkarReminderController
    extends Notifier<Map<AthkarTime, AthkarReminderSetting>> {
  static const ahead = 14;
  static const payload = 'athkar';

  DailyReminderScheduler get _scheduler =>
      ref.read(dailyReminderSchedulerProvider);

  static String _enabledKey(AthkarTime t) => 'athkar.reminder.${t.name}';
  static String _minutesKey(AthkarTime t) =>
      'athkar.reminder.${t.name}.minutes';

  static List<int> idsOf(AthkarTime t) => [
    for (var i = 0; i < ahead; i++) t.firstId + i,
  ];

  @override
  Map<AthkarTime, AthkarReminderSetting> build() {
    unawaited(_restore());
    return {
      for (final t in AthkarTime.values)
        t: (enabled: false, minutes: t.defaultMinutes),
    };
  }

  Future<void> _restore() async {
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    scheduler.onOpen(payload, _open);
    await scheduler.initialize();
    final storage = ref.read(browserStorageProvider);
    final restored = <AthkarTime, AthkarReminderSetting>{};
    for (final t in AthkarTime.values) {
      restored[t] = (
        enabled: await storage.getBool(_enabledKey(t)) ?? false,
        minutes:
            int.tryParse(await storage.getString(_minutesKey(t)) ?? '') ??
            t.defaultMinutes,
      );
    }
    if (!ref.mounted) return;
    state = restored;
    await _reschedule();
  }

  void _open() {
    // After the first frame: the router may not be built yet at launch.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      final router = ref.read(appRouterProvider)..go(AppRoutes.home);
      unawaited(
        router.push(AppRoutes.athkarCategory(AthkarBook.morningEvening)),
      );
    });
  }

  /// Turns [time]'s reminder on (asking for permission first) or off.
  /// `false` when it could not be turned on (permission denied).
  Future<bool> setEnabled(AthkarTime time, bool enabled) async {
    if (enabled && !await _scheduler.requestPermission()) return false;
    state = {...state, time: (enabled: enabled, minutes: state[time]!.minutes)};
    await ref.read(browserStorageProvider).setBool(_enabledKey(time), enabled);
    await _reschedule();
    return true;
  }

  Future<void> setTime(AthkarTime time, int minutes) async {
    state = {...state, time: (enabled: state[time]!.enabled, minutes: minutes)};
    await ref
        .read(browserStorageProvider)
        .setString(_minutesKey(time), '$minutes');
    await _reschedule();
  }

  Future<void> _reschedule() async {
    final scheduler = _scheduler;
    if (!scheduler.supported) return;
    final l10n = lookupAppLocalizations(reminderLocale(ref));
    for (final t in AthkarTime.values) {
      // (Those scheduled a day at a time before 2026-11-21 too.)
      await scheduler.cancelIds(idsOf(t));
      final setting = state[t]!;
      if (!setting.enabled) continue;
      // Every day at its time: one pending notification (an iPhone keeps
      // 64 in all).
      await scheduler.scheduleRepeating(
        id: t.firstId,
        hour: setting.minutes ~/ 60,
        minute: setting.minutes % 60,
        title: t == AthkarTime.morning
            ? l10n.athkarMorningTitle
            : l10n.athkarEveningTitle,
        body: t == AthkarTime.morning
            ? l10n.athkarMorningBody
            : l10n.athkarEveningBody,
        channelId: 'athkar_reminder',
        channelName: l10n.athkarReminderChannel,
        payload: payload,
      );
    }
  }
}

final athkarReminderProvider =
    NotifierProvider<
      AthkarReminderController,
      Map<AthkarTime, AthkarReminderSetting>
    >(AthkarReminderController.new);
