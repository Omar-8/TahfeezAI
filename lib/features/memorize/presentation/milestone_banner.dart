import 'dart:async';

import '../../../core/ui/motion.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/components/components.dart';
import '../../../memorization/application/memorization_progress.dart';
import '../../../memorization/domain/milestones.dart';
import '../../recitation/application/recitation_session_controller.dart';
import 'memorize_screen.dart' show surahNames;

/// Over every screen: a milestone just reached ([milestoneProvider]), as a
/// quiet card sliding in at the top for a few seconds — never while a
/// recitation runs (it waits for its end). A tap or an upward swipe puts
/// it away.
class MilestoneLayer extends ConsumerStatefulWidget {
  const MilestoneLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MilestoneLayer> createState() => _MilestoneLayerState();
}

class _MilestoneLayerState extends ConsumerState<MilestoneLayer> {
  static const _shownFor = Duration(seconds: 5);

  Milestone? _showing;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _hide() {
    _timer?.cancel();
    if (_showing == null) return;
    setState(() => _showing = null);
    ref.read(milestoneProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(milestoneProvider);
    final reciting = ref.watch(
      recitationSessionControllerProvider.select((s) => s.isActive),
    );
    if (pending != null && _showing == null && !reciting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _showing != null) return;
        setState(() => _showing = pending);
        _timer = Timer(_shownFor, _hide);
      });
    }
    final milestone = _showing;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: motion(context, const Duration(milliseconds: 450)),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: milestone == null
                  ? const SizedBox.shrink()
                  : _Banner(
                      key: ValueKey(milestone.id),
                      milestone: milestone,
                      onDismiss: _hide,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({super.key, required this.milestone, required this.onDismiss});

  final Milestone milestone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = switch (milestone) {
      JuzMilestone(:final juz) => l10n.milestoneJuz(juz),
      SurahMilestone(:final surah) => l10n.milestoneSurah(
        surahNames(ref)[surah] ?? '$surah',
      ),
      ShareMilestone(:final percent) => l10n.memProgressShare(percent),
      StreakMilestone(:final days) => l10n.memStreakDays(days),
    };
    return Padding(
      padding: const EdgeInsets.all(TahfeezSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: GestureDetector(
            key: const ValueKey('milestone-banner'),
            onTap: onDismiss,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) onDismiss();
            },
            child: Semantics(
              liveRegion: true,
              label: '${l10n.milestoneTitle}. $message',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TahfeezRadii.lg),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh.withValues(
                        alpha: 0.86,
                      ),
                      borderRadius: BorderRadius.circular(TahfeezRadii.lg),
                      border: Border.all(
                        color: scheme.tertiary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: TahfeezGeometricPattern(
                      color: scheme.tertiary.withValues(alpha: 0.10),
                      spacing: 36,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TahfeezSpacing.md,
                          vertical: TahfeezSpacing.smPlus,
                        ),
                        child: Row(
                          spacing: TahfeezSpacing.smPlus,
                          children: [
                            TahfeezStar(color: scheme.tertiary, size: 30),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.milestoneTitle,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.tertiary,
                                    ),
                                  ),
                                  Text(
                                    message,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
