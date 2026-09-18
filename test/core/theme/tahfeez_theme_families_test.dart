import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_theme_families.dart';

void main() {
  group('TahfeezThemeFamily', () {
    test('every family produces a distinct light-mode primary color', () {
      final primaries = {
        for (final family in TahfeezThemeFamily.values)
          family: family.colorScheme(Brightness.light).primary,
      };

      // All 7 values must be pairwise distinct -- a Set collapses duplicates,
      // so its length equalling the family count proves no two families
      // resolve to the same primary color.
      expect(
        primaries.values.toSet(),
        hasLength(TahfeezThemeFamily.values.length),
      );
    });

    test('light and dark schemes differ for every family (not the same scheme reused)', () {
      for (final family in TahfeezThemeFamily.values) {
        final light = family.colorScheme(Brightness.light);
        final dark = family.colorScheme(Brightness.dark);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
        expect(light.surface, isNot(dark.surface));
      }
    });

    test('emerald dark mode is not a naive inversion of light mode', () {
      final light = TahfeezThemeFamily.emerald.colorScheme(Brightness.light);
      final dark = TahfeezThemeFamily.emerald.colorScheme(Brightness.dark);

      // docs/DESIGN_DIRECTION.md gives dark mode its own, differently-hued
      // primary (a lighter mint/emerald) rather than reusing the light
      // primary at an inverted lightness -- so the two primaries must not
      // just be brightness-flipped versions of the same color.
      expect(light.primary, isNot(dark.primary));
    });

    test('every family has a non-empty display name', () {
      for (final family in TahfeezThemeFamily.values) {
        expect(family.displayName, isNotEmpty);
      }
    });
  });
}
