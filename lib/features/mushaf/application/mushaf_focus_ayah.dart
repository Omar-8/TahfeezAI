import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tint of a run of ayahs opened (a topic's passage): the same
/// gold as an ayah opened alone (the page engine's highlight band,
/// RGBA 0xd6a3264d — owner, 2026-11-14).
const openedRunColor = Color(0x4DD6A326);

/// The ayah a Mushaf screen was opened at (e.g. Home's Daily Ayah) — or
/// the run of ayahs (a topic's passage, [lastAyahId]) — highlighted on its
/// page while that screen is open: its stable id and the screen that set
/// it.
typedef FocusAyah = ({Object owner, int ayahId, int? lastAyahId});

class MushafFocusAyah extends Notifier<FocusAyah?> {
  @override
  FocusAyah? build() => null;

  /// [ayahId] — through [lastAyahId], a run of ayahs (same surah).
  void focus(Object owner, int ayahId, {int? lastAyahId}) {
    if (!ref.mounted) return;
    state = (owner: owner, ayahId: ayahId, lastAyahId: lastAyahId);
  }

  /// Clears the focus only if [owner] still holds it.
  void clear(Object owner) {
    if (!ref.mounted) return;
    if (state?.owner == owner) state = null;
  }
}

/// Whether [ayahId] is in [focus] (its ayah, or its run's).
bool isFocusedAyah(FocusAyah? focus, int ayahId) {
  if (focus == null) return false;
  final last = focus.lastAyahId;
  return last == null
      ? focus.ayahId == ayahId
      : ayahId >= focus.ayahId && ayahId <= last;
}

final mushafFocusAyahProvider = NotifierProvider<MushafFocusAyah, FocusAyah?>(
  MushafFocusAyah.new,
);
