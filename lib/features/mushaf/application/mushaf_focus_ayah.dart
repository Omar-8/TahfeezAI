import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ayah a Mushaf screen was opened at (e.g. Home's Daily Ayah),
/// highlighted on its page while that screen is open: its stable id and
/// the screen that set it.
class MushafFocusAyah extends Notifier<({Object owner, int ayahId})?> {
  @override
  ({Object owner, int ayahId})? build() => null;

  void focus(Object owner, int ayahId) {
    if (!ref.mounted) return;
    state = (owner: owner, ayahId: ayahId);
  }

  /// Clears the focus only if [owner] still holds it.
  void clear(Object owner) {
    if (!ref.mounted) return;
    if (state?.owner == owner) state = null;
  }
}

final mushafFocusAyahProvider =
    NotifierProvider<MushafFocusAyah, ({Object owner, int ayahId})?>(
      MushafFocusAyah.new,
    );
