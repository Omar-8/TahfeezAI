import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core_providers.dart';

/// Felt as a zikr is counted: a light tap each time, a longer buzz once it
/// is done (owner, 2026-11-21).
final athkarHapticsProvider = Provider<void Function({required bool done})>((
  ref,
) {
  final capabilities = ref.watch(platformCapabilitiesProvider);
  final native = capabilities.isAndroid || capabilities.isIOS;
  const channel = MethodChannel('tahfeez/alert');
  return ({required bool done}) {
    if (!native) return;
    if (done) {
      unawaited(channel.invokeMethod<void>('vibrate', 160));
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  };
});
