import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_colors.dart';
import 'package:tahfeez_ai/core/theme/tahfeez_tones.dart';

/// Light mode's pale tones, visible on the light glass (owner, 2026-11-21:
/// Progress's ring and the side menu's icon circles hardly showed).
void main() {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  const white = Color(0xFFFFFFFF);
  final light = buildLightColorScheme();

  test('a progress track shows on white', () {
    expect(contrast(light.progressTrack, white), greaterThan(1.35));
  });

  test('"marked, not recited" stands apart from both the track and the '
      'recited', () {
    expect(
      contrast(light.progressPartial, light.progressTrack),
      greaterThan(1.5),
    );
    expect(contrast(light.primary, light.progressPartial), greaterThan(1.8));
  });

  test('icon circles (primary container) show on white, their icons '
      'readable', () {
    expect(contrast(light.primaryContainer, white), greaterThan(1.25));
    expect(
      contrast(light.onPrimaryContainer, light.primaryContainer),
      greaterThan(4.5),
    );
  });

  test('dark mode as it was', () {
    final dark = buildDarkColorScheme();
    expect(dark.progressTrack, dark.surfaceContainerHighest);
    expect(
      dark.primaryContainer,
      TahfeezExplorationPalette.darkPrimaryContainer,
    );
  });
}
