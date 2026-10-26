import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_theme_families.dart';
import 'package:tahfeez_ai/features/home/presentation/home_sky.dart';

/// Text on the glass cards, over the sky at its strongest (the top of the
/// screen), in every part of the day, light and dark: readable — WCAG AA,
/// 4.5:1 for text, 3:1 for the primary colour's labels and icons.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color top, Color under) => Color.alphaBlend(top, under);

void main() {
  for (final brightness in Brightness.values) {
    final scheme = TahfeezThemeFamily.emerald.colorScheme(brightness);
    final dark = brightness == Brightness.dark;
    for (final part in DayPart.values) {
      test('${brightness.name}, ${part.name}: text on glass over the sky', () {
        var (a, b) = part.colors(brightness);
        if (!dark) {
          a = Color.lerp(a, scheme.surface, 0.12)!;
          b = Color.lerp(b, scheme.surface, 0.12)!;
        }
        for (final sky in [a, b]) {
          // The glass's least opaque edge (its gradient's end).
          final card = _over(
            scheme.surfaceContainerLow.withValues(alpha: dark ? 0.12 : 0.36),
            _over(
              scheme.surfaceContainerLowest.withValues(
                alpha: dark ? 0.22 : 0.58,
              ),
              sky,
            ),
          );
          expect(_contrast(scheme.onSurface, card), greaterThan(4.5));
          expect(_contrast(scheme.onSurfaceVariant, card), greaterThan(4.5));
          expect(_contrast(scheme.primary, card), greaterThan(3));
        }
      });
    }
  }
}
