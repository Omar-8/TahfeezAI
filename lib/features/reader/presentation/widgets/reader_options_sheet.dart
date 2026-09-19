import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/components/components.dart';
import '../../../../core/ui/coming_soon.dart';
import '../../application/reader_preferences_controller.dart';

/// The reader's own options — a lighter-weight, reader-scoped counterpart
/// to the "reader settings only" gear `docs/reference/04_READER_SPEC.md`
/// §3 describes, since a full Settings screen doesn't exist yet
/// (Milestone 14). Everything here is real and working; "select
/// translations" is shown disabled per this milestone's explicit
/// "intentional disabled states rather than fake behavior" instruction,
/// since no translation resource exists yet (Milestone 9).
void showReaderOptionsSheet(BuildContext context) {
  showTahfeezModalBottomSheet(
    context: context,
    title: 'Reader options',
    builder: (context) => const _ReaderOptionsBody(),
  );
}

class _ReaderOptionsBody extends ConsumerWidget {
  const _ReaderOptionsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continuousScrolling = ref.watch(
      continuousScrollingPreferenceControllerProvider,
    );
    final arabicTextVisible = ref.watch(
      arabicTextVisiblePreferenceControllerProvider,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          title: const Text('Continuous scrolling'),
          subtitle: const Text('Automatically continue into the next chapter'),
          value: continuousScrolling,
          onChanged: (value) => ref
              .read(continuousScrollingPreferenceControllerProvider.notifier)
              .setEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Show Arabic text'),
          value: arabicTextVisible,
          onChanged: (value) => ref
              .read(arabicTextVisiblePreferenceControllerProvider.notifier)
              .setVisible(value),
        ),
        ListTile(
          title: const Text('Select translations'),
          subtitle: const Text('Coming in a later milestone'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showComingSoon(context),
        ),
      ],
    );
  }
}
