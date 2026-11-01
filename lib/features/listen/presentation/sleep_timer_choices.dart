import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../application/quran_audio_player.dart';
import '../application/sleep_timer.dart';

/// The sleep timer's choices — off, minutes, or the end of the ayah
/// playing (only while one plays) — and when it will pause.
class SleepTimerChoices extends ConsumerWidget {
  const SleepTimerChoices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final timer = ref.watch(sleepTimerProvider);
    final controller = ref.read(sleepTimerProvider.notifier);
    final playing = ref.watch(quranAudioPlayerProvider);
    final ayahPlaying = playing != null && !playing.isWord;
    final endsAt = timer?.endsAt;
    final status = timer == null
        ? null
        : timer.afterAyah
        ? l10n.sleepTimerPausesAfterAyah
        : l10n.sleepTimerPausesAt(
            MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(endsAt!)),
          );
    return Column(
      // As tall as its choices (a sheet of its own, not a full-height one).
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TahfeezSpacing.sm,
      children: [
        Wrap(
          key: const ValueKey('sleep-timer-choices'),
          spacing: TahfeezSpacing.sm,
          runSpacing: TahfeezSpacing.sm,
          children: [
            ChoiceChip(
              key: const ValueKey('sleep-timer-off'),
              showCheckmark: false,
              label: Text(l10n.sleepTimerOff),
              selected: timer == null,
              onSelected: (_) => controller.cancel(),
            ),
            for (final minutes in sleepTimerMinutes)
              ChoiceChip(
                key: ValueKey('sleep-timer-$minutes'),
                showCheckmark: false,
                label: Text(l10n.sleepTimerMinutes(minutes)),
                selected: timer?.minutes == minutes,
                onSelected: (_) => controller.setMinutes(minutes),
              ),
            if (ayahPlaying)
              ChoiceChip(
                key: const ValueKey('sleep-timer-ayah'),
                showCheckmark: false,
                label: Text(l10n.sleepTimerAfterAyah),
                selected: timer?.afterAyah ?? false,
                onSelected: (_) => controller.setAfterAyah(),
              ),
          ],
        ),
        if (status != null)
          Text(
            status,
            key: const ValueKey('sleep-timer-status'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The sleep timer on the playing bar: a moon, filled while it is set;
/// its choices in a sheet.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key, this.style});

  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(sleepTimerProvider) != null;
    return IconButton(
      key: const ValueKey('listen-sleep-timer'),
      style: style,
      isSelected: on,
      icon: const Icon(Icons.bedtime_outlined),
      selectedIcon: const Icon(Icons.bedtime),
      tooltip: l10n.sleepTimer,
      onPressed: () => showTahfeezModalBottomSheet<void>(
        context: context,
        title: l10n.sleepTimer,
        builder: (context) => const Padding(
          padding: EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            0,
            TahfeezSpacing.md,
            TahfeezSpacing.lg,
          ),
          child: SleepTimerChoices(),
        ),
      ),
    );
  }
}
