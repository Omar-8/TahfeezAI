import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import '../theme/app_spacing.dart';

/// A sheet's last row: Cancel (closing the sheet) — or [secondary] in its
/// place — then its main button ([primary]) taking the rest of the row to
/// its end. The first is only as wide as its word, never more than 40% of
/// the row, so it is always the narrower of the two (its word on two lines
/// at large text sizes).
class SheetActions extends StatelessWidget {
  const SheetActions({super.key, required this.primary, this.secondary});

  final Widget primary;

  /// In Cancel's place (a plan being edited: Stop plan).
  final Widget? secondary;

  static const cancelKey = ValueKey('sheet-cancel');

  /// A label for the first button: on two lines rather than overflowing.
  static Widget label(String text) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
          child:
              secondary ??
              TextButton(
                key: cancelKey,
                onPressed: () => Navigator.of(context).maybePop(),
                child: label(AppLocalizations.of(context).commonCancel),
              ),
        ),
        const SizedBox(width: TahfeezSpacing.sm),
        Expanded(child: primary),
      ],
    ),
  );
}
