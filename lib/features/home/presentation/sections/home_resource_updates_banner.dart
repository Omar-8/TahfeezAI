import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../application/home_providers.dart';

/// Home's resource/update-notices region. Mirrors the reference app's own
/// "shown only if there is something to say" banner behavior
/// (`docs/reference/11_HOME_SPEC.md` §2): it renders nothing at all while
/// [outdatedResourceSummariesProvider] is empty, which is the only state
/// reachable today since no concrete `ResourceRepository` exists yet
/// (Milestone 13).
class HomeResourceUpdatesBanner extends ConsumerWidget {
  const HomeResourceUpdatesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(outdatedResourceSummariesProvider);

    return summaries.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            TahfeezSpacing.md,
            0,
            TahfeezSpacing.md,
            TahfeezSpacing.md,
          ),
          child: TahfeezCard(
            child: Row(
              spacing: TahfeezSpacing.sm,
              children: [
                Icon(Icons.info_outline, color: scheme.primary),
                Expanded(child: Text(list.join(', '))),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
