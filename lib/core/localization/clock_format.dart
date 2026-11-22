import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

/// How times of day are written (owner, 2026-11-22): as the phone is set,
/// or 12-hour, or 24-hour — everywhere in the app (the app's MediaQuery)
/// and on the home-screen widgets.
enum ClockFormat { system, h12, h24 }

class ClockFormatController extends Notifier<ClockFormat> {
  static const storageKey = 'clock.format';

  @override
  ClockFormat build() {
    unawaited(_restore());
    return ClockFormat.system;
  }

  Future<void> _restore() async {
    final raw = await ref.read(browserStorageProvider).getString(storageKey);
    for (final f in ClockFormat.values) {
      if (f.name == raw && ref.mounted) state = f;
    }
  }

  Future<void> set(ClockFormat format) async {
    state = format;
    await ref.read(browserStorageProvider).setString(storageKey, format.name);
  }
}

final clockFormatProvider =
    NotifierProvider<ClockFormatController, ClockFormat>(
      ClockFormatController.new,
    );

/// Whether times are 24-hour, given the phone's own choice [phone24].
bool use24Hour(ClockFormat format, {required bool phone24}) => switch (format) {
  ClockFormat.system => phone24,
  ClockFormat.h12 => false,
  ClockFormat.h24 => true,
};

/// [child] with the app's time format applied to its MediaQuery (so every
/// time shown — `alwaysUse24HourFormat`, TimeOfDay, the time pickers —
/// follows it).
class ClockFormatScope extends ConsumerWidget {
  const ClockFormatScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(clockFormatProvider);
    if (format == ClockFormat.system) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(alwaysUse24HourFormat: format == ClockFormat.h24),
      child: child,
    );
  }
}
