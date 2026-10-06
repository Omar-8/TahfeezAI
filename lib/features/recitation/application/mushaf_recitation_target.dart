import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../quran/domain/models/quran_location.dart';

/// The Mushaf currently on screen, as reported by `RecitationMushafAnchor`:
/// `null` when no Mushaf is open. [MushafRecitationTarget.location] is the
/// page a new session would start from (`null` until the page resolves).
class MushafRecitationTarget {
  const MushafRecitationTarget(this.owner, this.location);

  final Object owner;
  final QuranLocation? location;
}

class MushafRecitationTargetNotifier extends Notifier<MushafRecitationTarget?> {
  @override
  MushafRecitationTarget? build() => null;

  void show(Object owner, QuranLocation? location) {
    if (!ref.mounted) return;
    state = MushafRecitationTarget(owner, location);
  }

  /// Clears the target only if [owner] still holds it, so a Mushaf screen
  /// being disposed never clears one that replaced it.
  void clear(Object owner) {
    // The whole scope may already be gone (e.g. app teardown).
    if (!ref.mounted) return;
    if (state?.owner == owner) state = null;
  }
}

final mushafRecitationTargetProvider =
    NotifierProvider<MushafRecitationTargetNotifier, MushafRecitationTarget?>(
      MushafRecitationTargetNotifier.new,
    );
