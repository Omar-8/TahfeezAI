import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../application/athkar_reminder.dart';

/// The morning and evening athkar reminders: each on or off, at its time.
Future<void> showAthkarReminderSheet(BuildContext context) =>
    showTahfeezModalBottomSheet<void>(
      context: context,
      title: AppLocalizations.of(context).athkarReminders,
      builder: (context) => const _ReminderSheet(),
    );

class _ReminderSheet extends ConsumerWidget {
  const _ReminderSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reminders = ref.watch(athkarReminderProvider);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in AthkarTime.values) ...[
            SwitchListTile(
              key: ValueKey('athkar-reminder-${t.name}'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                t == AthkarTime.morning
                    ? Icons.wb_sunny_outlined
                    : Icons.nights_stay_outlined,
              ),
              title: Text(
                t == AthkarTime.morning
                    ? l10n.athkarMorningTitle
                    : l10n.athkarEveningTitle,
              ),
              subtitle: Text(
                l10n.memReminderAt(
                  _timeOf(reminders[t]!.minutes).format(context),
                ),
              ),
              value: reminders[t]!.enabled,
              onChanged: (on) async {
                final messenger = ScaffoldMessenger.of(context);
                final done = await ref
                    .read(athkarReminderProvider.notifier)
                    .setEnabled(t, on);
                if (!done) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.memReminderDenied)),
                  );
                }
              },
            ),
            ListTile(
              key: ValueKey('athkar-reminder-${t.name}-time'),
              contentPadding: const EdgeInsetsDirectional.only(start: 40),
              enabled: reminders[t]!.enabled,
              leading: const Icon(Icons.schedule),
              title: Text(l10n.memReminderTime),
              trailing: Text(_timeOf(reminders[t]!.minutes).format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _timeOf(reminders[t]!.minutes),
                );
                if (picked == null) return;
                await ref
                    .read(athkarReminderProvider.notifier)
                    .setTime(t, picked.hour * 60 + picked.minute);
              },
            ),
          ],
        ],
      ),
    );
  }
}

TimeOfDay _timeOf(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
