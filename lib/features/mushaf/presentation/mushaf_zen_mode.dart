import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/mushaf_appearance.dart';

/// Focus mode: the Mushaf alone — its app bar and the phone's status and
/// navigation bars hidden, the recitation bar kept. Until turned off, or the
/// Mushaf is left.
class MushafZenMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) {
    if (!ref.mounted || on == state) return;
    state = on;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }
}

final mushafZenModeProvider = NotifierProvider<MushafZenMode, bool>(
  MushafZenMode.new,
);

/// The Mushaf app bar's way into focus mode.
class ZenModeButton extends ConsumerWidget {
  const ZenModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    key: const ValueKey('mushaf-zen'),
    // Its corner marks span 14 of the glyph's 24 units (its neighbours'
    // about 19): drawn larger to look the same size.
    icon: const Icon(Icons.fullscreen_rounded, size: 30),
    tooltip: AppLocalizations.of(context).zenMode,
    onPressed: () => ref.read(mushafZenModeProvider.notifier).set(true),
  );
}

/// Around a Mushaf screen's body: in focus mode, kept clear of the notch,
/// with a small pill at the top to leave it (fading to a hint after a
/// moment) — and Back leaves it before the Mushaf. Leaving the Mushaf ends
/// it.
class ZenModeLayer extends ConsumerStatefulWidget {
  const ZenModeLayer({super.key, required this.colors, required this.child});

  final MushafAppearanceColors colors;
  final Widget child;

  @override
  ConsumerState<ZenModeLayer> createState() => _ZenModeLayerState();
}

class _ZenModeLayerState extends ConsumerState<ZenModeLayer> {
  // Read up front: `ref` is unusable by the time dispose runs.
  late final MushafZenMode _zen;
  Timer? _fade;
  var _faded = false;

  @override
  void initState() {
    super.initState();
    _zen = ref.read(mushafZenModeProvider.notifier);
  }

  void _showPill() {
    _fade?.cancel();
    setState(() => _faded = false);
    _fade = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _faded = true);
    });
  }

  @override
  void dispose() {
    _fade?.cancel();
    final zen = _zen;
    Future.microtask(() => zen.set(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mushafZenModeProvider, (_, on) {
      if (on) _showPill();
    });
    final zen = ref.watch(mushafZenModeProvider);
    if (!zen) return widget.child;
    final l10n = AppLocalizations.of(context);
    final colors = widget.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _zen.set(false);
      },
      child: Stack(
        children: [
          SafeArea(bottom: false, child: widget.child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: TahfeezSpacing.xs),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: _faded ? 0.3 : 1,
                    child: Material(
                      color: colors.text.withValues(alpha: 0.08),
                      shape: const StadiumBorder(),
                      child: InkWell(
                        key: const ValueKey('mushaf-zen-exit'),
                        customBorder: const StadiumBorder(),
                        onTap: () => _zen.set(false),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TahfeezSpacing.smPlus,
                            vertical: TahfeezSpacing.xs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: TahfeezSpacing.xs,
                            children: [
                              Icon(
                                Icons.fullscreen_exit_rounded,
                                size: 16,
                                color: colors.secondaryText,
                              ),
                              Text(
                                l10n.zenModeExit,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: colors.secondaryText),
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
        ],
      ),
    );
  }
}
