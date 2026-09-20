import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/components/components.dart';
import '../application/mushaf_text_boldness_controller.dart';
import '../domain/mushaf_text_boldness.dart';

/// Lets the user pick how bold Mushaf-mode Quran glyph text looks
/// (Light/Medium/Bold) — a paint-only stroke-behind-fill treatment, never
/// a `FontWeight` change (see `mushaf_text_boldness.dart`'s doc comment).
/// Mushaf-only: this sheet is never shown from the verse-by-verse reader.
void showMushafTextBoldnessSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Quran text boldness',
    builder: (context) => const _MushafTextBoldnessBody(),
  );
}

class _MushafTextBoldnessBody extends ConsumerWidget {
  const _MushafTextBoldnessBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mushafTextBoldnessControllerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final boldness in MushafTextBoldness.values)
            ChoiceChip(
              label: Text(boldness.label),
              selected: boldness == selected,
              onSelected: (_) => ref
                  .read(mushafTextBoldnessControllerProvider.notifier)
                  .setBoldness(boldness),
            ),
        ],
      ),
    );
  }
}
