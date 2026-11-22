import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/tahfeez_motion.dart';
import '../../../core/theme/tahfeez_tones.dart';
import '../../athkar/application/athkar_haptics.dart';
import '../../mushaf/application/reader_mode.dart';
import '../application/habits_controller.dart';
import '../domain/habit_catalog.dart';
import 'habit_parts.dart';

/// A wird counted (owner, 2026-11-21: 100 ṣalawāt, 100 takbīr…): its
/// words, and a tap anywhere for one more — felt, the last one more so —
/// up to its target, on [day].
class HabitCounterScreen extends ConsumerWidget {
  const HabitCounterScreen({super.key, required this.id, required this.day});

  final String id;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = ref.watch(habitsProvider);
    final habit = s.habit(id);
    if (habit == null) {
      return HabitsScaffold(title: l10n.habitsTitle, body: const SizedBox());
    }
    final target = habit.target ?? 1;
    final count = s.amountOn(id, day) ?? 0;
    final done = count >= target;
    final phrase = templateOf(habit)?.phrase ?? habitName(l10n, habit);
    final font = ref.watch(ayahViewPreferencesProvider).quranFont.family;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    void tap() {
      if (done) return;
      final now = ref.read(habitsProvider.notifier).countOne(habit, day);
      ref.read(athkarHapticsProvider)(done: now >= target);
    }

    return HabitsScaffold(
      title: l10n.habitsCount,
      body: GestureDetector(
        key: const ValueKey('habit-counter'),
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.all(TahfeezSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: TahfeezSpacing.lg,
            children: [
              Text(
                phrase,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: font,
                  height: 1.8,
                ),
              ),
              SizedBox.square(
                dimension: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: count / target),
                        duration: still
                            ? Duration.zero
                            : TahfeezMotionDuration.fast,
                        builder: (context, v, _) => CircularProgressIndicator(
                          value: v.clamp(0, 1),
                          strokeWidth: 10,
                          backgroundColor: scheme.progressTrack,
                        ),
                      ),
                    ),
                    if (done)
                      Icon(Icons.check_rounded, size: 72, color: scheme.primary)
                    else
                      Text(
                        '$count',
                        key: const ValueKey('habit-counter-count'),
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                done
                    ? habitAmountText(l10n, habit.unit, count) ?? ''
                    : '$count / $target  ·  ${l10n.athkarTapToCount}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
