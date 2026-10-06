import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/storage_providers.dart';

const _appSurfaceTonePrefKey = 'core.app_surface_tone';

/// The app's surface tone on top of its light or dark scheme: the
/// standard surfaces, or the warm, sepia (light) and black (dark) papers
/// the Mushaf page also offers — chosen independently of the page's own
/// appearance, so the two can be mixed.
enum AppSurfaceTone {
  standard,
  warm(Color(0xFFFBF1DE), Color(0xFF3B2E1E), Color(0xFF7A6448)),
  sepia(Color(0xFFF0E2C6), Color(0xFF4B3A22), Color(0xFF7C6444)),
  black(Color(0xFF000000), Color(0xFFE6E6E6), Color(0xFFA3A3A3));

  const AppSurfaceTone([this.surface, this.onSurface, this.onSurfaceVariant]);

  final Color? surface, onSurface, onSurfaceVariant;

  /// Which brightness the tone belongs to (`null`: either).
  Brightness? get brightness => switch (this) {
    standard => null,
    warm || sepia => Brightness.light,
    black => Brightness.dark,
  };

  /// [scheme] on this tone's paper: its surfaces stepped from the paper
  /// towards the ink, the accent colors left as they are.
  ColorScheme apply(ColorScheme scheme) {
    final paper = surface, ink = onSurface;
    if (paper == null || ink == null || scheme.brightness != brightness) {
      return scheme;
    }
    Color step(double t) => Color.lerp(paper, ink, t)!;
    return scheme.copyWith(
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: onSurfaceVariant,
      surfaceDim: step(0.08),
      surfaceBright: paper,
      surfaceContainerLowest: paper,
      surfaceContainerLow: step(0.03),
      surfaceContainer: step(0.05),
      surfaceContainerHigh: step(0.08),
      surfaceContainerHighest: step(0.11),
      outlineVariant: step(0.18),
    );
  }
}

/// The persisted [AppSurfaceTone] (with [ThemeModeController] choosing
/// light or dark).
class AppSurfaceToneController extends Notifier<AppSurfaceTone> {
  @override
  AppSurfaceTone build() {
    _restore();
    return AppSurfaceTone.standard;
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(browserStorageProvider)
        .getString(_appSurfaceTonePrefKey);
    for (final tone in AppSurfaceTone.values) {
      if (tone.name == stored && ref.mounted && tone != state) {
        state = tone;
        return;
      }
    }
  }

  Future<void> setTone(AppSurfaceTone tone) async {
    state = tone;
    await ref
        .read(browserStorageProvider)
        .setString(_appSurfaceTonePrefKey, tone.name);
  }
}

final appSurfaceToneProvider =
    NotifierProvider<AppSurfaceToneController, AppSurfaceTone>(
      AppSurfaceToneController.new,
    );
