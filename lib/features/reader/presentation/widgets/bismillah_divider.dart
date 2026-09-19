import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A decorative divider marking where a chapter's Bismillah belongs.
///
/// Deliberately renders **no Arabic text** — see
/// [ReaderBismillahItem]'s doc comment
/// (`lib/features/reader/domain/reader_layout_item.dart`) for why: the
/// Bismillah is canonical Quran text with no dedicated source in this
/// milestone's schema, so this stays a structural marker only until a real
/// Mushaf line/word dataset can supply the actual text (Milestone 7).
class BismillahDivider extends StatelessWidget {
  const BismillahDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.xl,
        vertical: TahfeezSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TahfeezSpacing.sm),
            child: Icon(
              Icons.auto_awesome,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
