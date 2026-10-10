import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tahfeez_ai/core/theme/app_surface_tone.dart';
import 'package:tahfeez_ai/core/theme/theme_controller.dart';
import 'package:tahfeez_ai/features/mushaf/application/mushaf_appearance_controller.dart';
import 'package:tahfeez_ai/features/mushaf/domain/mushaf_appearance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the Mushaf follows the app theme until a Mushaf theme is chosen',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(mushafAppearanceControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await container
          .read(appSurfaceToneProvider.notifier)
          .setTone(AppSurfaceTone.sepia);
      expect(
        container.read(mushafAppearanceControllerProvider),
        MushafAppearance.sepia,
      );

      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await container
          .read(appSurfaceToneProvider.notifier)
          .setTone(AppSurfaceTone.black);
      expect(
        container.read(mushafAppearanceControllerProvider),
        MushafAppearance.black,
      );

      // Chosen: kept, whatever the app theme does.
      await container
          .read(mushafAppearanceControllerProvider.notifier)
          .setAppearance(MushafAppearance.warm);
      await container
          .read(themeModeControllerProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(
        container.read(mushafAppearanceControllerProvider),
        MushafAppearance.warm,
      );
    },
  );
}
