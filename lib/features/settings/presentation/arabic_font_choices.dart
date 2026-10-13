import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';

/// The Arabic UI font, one chip per font, each name in its own font — in
/// Settings and in Ayah mode's view settings, one choice for both.
class ArabicFontChoices extends ConsumerWidget {
  const ArabicFontChoices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(arabicFontControllerProvider);
    return Wrap(
      key: const ValueKey('settings-arabic-font'),
      spacing: TahfeezSpacing.sm,
      runSpacing: TahfeezSpacing.sm,
      children: [
        for (final font in ArabicUiFont.values)
          ChoiceChip(
            key: ValueKey('settings-arabic-font-${font.name}'),
            label: Text(
              font.arabicName,
              style: TextStyle(fontFamily: font.family),
            ),
            selected: font == selected,
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(arabicFontControllerProvider.notifier).setFont(font),
          ),
      ],
    );
  }
}
