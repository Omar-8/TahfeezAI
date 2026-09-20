import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  test(
    'defaults to MushafAppearance.light when the system is in light mode',
    () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(mushafAppearanceControllerProvider),
        MushafAppearance.light,
      );
    },
  );

  test(
    'defaults to MushafAppearance.dark when the system is in dark mode -- '
    'a real device already in dark mode should not open to a bright page',
    () {
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(mushafAppearanceControllerProvider),
        MushafAppearance.dark,
      );
    },
  );
}
