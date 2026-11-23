import 'dart:ui' show DisplayFeature, DisplayFeatureType, Rect, Size;

import 'package:flutter/widgets.dart';

/// A dual-screen device's hinge (Surface Duo and the like), as Android
/// reports it while the app spans both screens: a strip nothing can be
/// drawn on. A foldable's fold isn't one (drawn on, just bent); a phone,
/// a tablet and a browser report none — so all of this does nothing there.
class DisplayHinge {
  const DisplayHinge(this.bounds, this.window);

  /// The strip, in the window's logical pixels.
  final Rect bounds;

  /// The window it divides.
  final Size window;

  /// Side by side (a vertical strip) rather than one above the other.
  bool get vertical => bounds.height >= bounds.width;

  /// The screen before it ([first]: left, or top) or after it.
  Rect screen({required bool first}) {
    final all = Offset.zero & window;
    if (vertical) {
      return first
          ? Rect.fromLTRB(0, 0, bounds.left, all.bottom)
          : Rect.fromLTRB(bounds.right, 0, all.right, all.bottom);
    }
    return first
        ? Rect.fromLTRB(0, 0, all.right, bounds.top)
        : Rect.fromLTRB(0, bounds.bottom, all.right, all.bottom);
  }

  /// The hinge dividing [media]'s window, if one does.
  static DisplayHinge? of(MediaQueryData media) =>
      fromFeatures(media.displayFeatures, media.size);

  static DisplayHinge? fromFeatures(
    List<DisplayFeature> features,
    Size window,
  ) {
    for (final f in features) {
      if (f.type != DisplayFeatureType.hinge) continue;
      final b = f.bounds;
      if (b.width <= 0 && b.height <= 0) continue;
      final hinge = DisplayHinge(b, window);
      // Across the whole window, with room on both sides.
      final whole = hinge.vertical
          ? b.top <= 0 && b.bottom >= window.height
          : b.left <= 0 && b.right >= window.width;
      final a = hinge.screen(first: true), z = hinge.screen(first: false);
      if (whole && a.width > 0 && a.height > 0 && z.width > 0 && z.height > 0) {
        return hinge;
      }
    }
    return null;
  }
}
