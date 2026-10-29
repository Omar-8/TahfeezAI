import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// Settings → Animations: the app's glows, fades and movement — on unless
/// turned off. Off does what the phone's "remove animations" does
/// ([AnimationsOff]): every check of it (`motion()`, the Mushaf's word
/// effects…) sees it.
class AnimationsController extends Notifier<bool> {
  static const storageKey = 'ui.animations';

  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    final stored = await ref.read(browserStorageProvider).getBool(storageKey);
    if (ref.mounted && stored != null) state = stored;
  }

  Future<void> setEnabled(bool on) async {
    state = on;
    await ref.read(browserStorageProvider).setBool(storageKey, on);
  }
}

final animationsProvider = NotifierProvider<AnimationsController, bool>(
  AnimationsController.new,
);

/// Around the app: with [animationsProvider] off, the media query says
/// animations are disabled, as the phone's own setting would.
class AnimationsOff extends ConsumerWidget {
  const AnimationsOff({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(animationsProvider)) return child;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    );
  }
}
