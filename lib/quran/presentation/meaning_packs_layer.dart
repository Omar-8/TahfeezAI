import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/ui/motion.dart';
import '../application/meaning_packs.dart';

/// Over every screen: while a language's translations, tafsir and word
/// meanings go on the phone ([meaningPacksProvider]), a short wait — the
/// app dimmed, a card saying what's happening; and when that failed, the
/// error, kept on screen until it works, with a way to try again.
///
/// A download waiting for the network: said once, for a few seconds (the
/// app goes on in English meanwhile).
class MeaningPacksLayer extends ConsumerStatefulWidget {
  const MeaningPacksLayer({super.key, required this.child});

  final Widget child;

  /// How long the offline notice shows.
  static const offlineNotice = Duration(seconds: 6);

  @override
  ConsumerState<MeaningPacksLayer> createState() => _MeaningPacksLayerState();
}

class _MeaningPacksLayerState extends ConsumerState<MeaningPacksLayer> {
  bool _offlineSaid = false;
  bool _offlineShown = false;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(meaningPacksProvider.select((s) => s.waitingForNetwork), (
      _,
      waiting,
    ) {
      if (!waiting || _offlineSaid) return;
      _offlineSaid = true;
      setState(() => _offlineShown = true);
      _hide = Timer(MeaningPacksLayer.offlineNotice, () {
        if (mounted) setState(() => _offlineShown = false);
      });
    });
    final child = widget.child;
    final packs = ref.watch(meaningPacksProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failure = packs.failure;
    return Stack(
      children: [
        child,
        // (Built only while showing: its spinner would keep animating.)
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: motion(context, const Duration(milliseconds: 200)),
            child: !packs.busy
                ? const SizedBox.shrink()
                : ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.32),
                    child: Center(
                      child: Card(
                        key: const ValueKey('meaning-packs-busy'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TahfeezSpacing.lg,
                            vertical: TahfeezSpacing.md,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: TahfeezSpacing.md,
                            children: [
                              const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  l10n.meaningPacksPreparing,
                                  style: theme.textTheme.bodyLarge,
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: motion(context, const Duration(milliseconds: 200)),
              child: !_offlineShown || failure != null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.all(TahfeezSpacing.md),
                      child: Material(
                        key: const ValueKey('meaning-packs-offline'),
                        color: scheme.inverseSurface,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(TahfeezSpacing.md),
                          child: Row(
                            spacing: TahfeezSpacing.md,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color: scheme.onInverseSurface,
                              ),
                              Expanded(
                                child: Text(
                                  l10n.meaningPacksOffline,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onInverseSurface,
                                  ),
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
        if (failure != null && !packs.busy)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(TahfeezSpacing.md),
                child: Material(
                  key: const ValueKey('meaning-packs-failed'),
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(TahfeezSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: TahfeezSpacing.sm,
                      children: [
                        Text(
                          l10n.meaningPacksFailed,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        SelectableText(
                          failure.length > 400
                              ? '${failure.substring(0, 400)}…'
                              : failure,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () =>
                                ref.read(meaningPacksProvider.notifier).retry(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.quranSetupRetry),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
