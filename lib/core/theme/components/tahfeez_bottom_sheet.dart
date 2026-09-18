import 'package:flutter/material.dart';

import '../app_spacing.dart';

/// Shows a Tahfeez modal bottom sheet with a consistent drag handle, header,
/// and safe-area padding.
///
/// `docs/DESIGN_DIRECTION.md` keeps "bottom-sheet interaction for secondary
/// actions" as a KEEP-worthy pattern from the reference app
/// (`docs/reference/18_VISUAL_REFERENCE_NOTES.md` §4) — this is Tahfeez's
/// own implementation of that pattern, used for verse options, filters,
/// and any other secondary/contextual action sheet.
Future<T?> showTahfeezModalBottomSheet<T>({
  required BuildContext context,
  String? title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: TahfeezSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: TahfeezSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(TahfeezSpacing.xs),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: TahfeezSpacing.md,
                  left: TahfeezSpacing.md,
                  right: TahfeezSpacing.md,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}
