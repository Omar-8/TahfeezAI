import 'package:flutter/material.dart';

/// Shows a Tahfeez dialog — a thin wrapper over [AlertDialog] (already
/// themed by `buildTahfeezTheme`) so every confirmation/destructive-action
/// dialog in the app looks and reads consistently, e.g. the bookmark
/// delete-confirmation flow described in
/// `docs/reference/12_BOOKMARK_HISTORY_SPEC.md` §2.
Future<bool> showTahfeezConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        if (isDestructive)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );

  return result ?? false;
}
