import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';

/// Shows the composed share text for a verse/verse-range selection with a
/// real "Copy" action (`Clipboard`), satisfying this milestone's "share"
/// action as genuinely working capability rather than a disabled stub.
/// `docs/reference/04_READER_SPEC.md` §9 flags OS-level share-sheet
/// integration as a `NEEDS_VERIFICATION`/reference-only detail — Tahfeez
/// designs its own share surface here rather than reproducing that one,
/// and defers adding a native share-sheet plugin dependency until that is
/// an explicit product decision.
void showVerseShareSheet(BuildContext context, String shareText) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Share',
    builder: (context) => _VerseShareBody(shareText: shareText),
  );
}

class _VerseShareBody extends StatelessWidget {
  const _VerseShareBody({required this.shareText});

  final String shareText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TahfeezSpacing.md,
        0,
        TahfeezSpacing.md,
        TahfeezSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: TahfeezSpacing.md,
        children: [
          TahfeezCard(child: Text(shareText)),
          FilledButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareText));
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
