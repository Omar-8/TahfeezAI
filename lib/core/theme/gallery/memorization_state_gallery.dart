import 'package:flutter/material.dart';

import '../app_spacing.dart';
import '../components/tahfeez_card.dart';

/// A visual sketch of every memorization state
/// `docs/DESIGN_DIRECTION.md`'s "Memorization visual language" section
/// requires — visible/hidden/partially-revealed text, current ayah/word,
/// listening, correct/skipped/incorrect word, hesitation, self-correction,
/// weak memory range, scheduled revision, completed session.
///
/// **This is a placeholder, not the real feature.** The Memorization
/// milestone (17) owns the actual implementation, wired to real session
/// state. What matters here, per this milestone's own scope, is proving the
/// *visual vocabulary* — overlays, backgrounds, underlines, opacity, masks,
/// never editing the underlying text — works and reads clearly in every
/// theme family/brightness. Every placeholder word below is ordinary
/// English UI copy, deliberately **not** Quran text or anything resembling
/// it, per `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules: this
/// gallery must never be mistaken for a source of canonical text.
class MemorizationStateGallery extends StatelessWidget {
  const MemorizationStateGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wordStyle = Theme.of(context).textTheme.titleMedium;

    Widget word(String label, String state, Widget child) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TahfeezSpacing.smPlus,
              vertical: TahfeezSpacing.sm,
            ),
            child: DefaultTextStyle.merge(style: wordStyle, child: child),
          ),
          const SizedBox(height: TahfeezSpacing.xs),
          Text(state, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
    }

    return TahfeezCard(
      child: Wrap(
        spacing: TahfeezSpacing.md,
        runSpacing: TahfeezSpacing.md,
        children: [
          word('visible', 'Visible text', const Text('sample word')),
          word(
            'hidden',
            'Hidden text',
            Container(
              width: 90,
              height: 20,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          word(
            'partial',
            'Partially revealed',
            const Opacity(opacity: 0.35, child: Text('sample word')),
          ),
          word(
            'current-ayah',
            'Current ayah',
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TahfeezSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(TahfeezSpacing.sm),
              ),
              child: const Text('sample ayah'),
            ),
          ),
          word(
            'current-word',
            'Current word',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('word'),
            ),
          ),
          word(
            'listening',
            'Listening',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, size: 18, color: scheme.primary),
                const SizedBox(width: 4),
                const Text('sample'),
              ],
            ),
          ),
          word(
            'correct',
            'Correct recognition',
            Text('sample', style: TextStyle(color: scheme.primary)),
          ),
          word(
            'skipped',
            'Skipped word',
            Text(
              'sample',
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          word(
            'incorrect',
            'Incorrect word',
            Text(
              'sample',
              style: TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: scheme.error,
                color: scheme.error,
              ),
            ),
          ),
          word(
            'hesitation',
            'Hesitation',
            Text(
              'sample',
              style: TextStyle(
                color: scheme.tertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          word(
            'self-correction',
            'Self-correction',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'sample',
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('word'),
              ],
            ),
          ),
          word(
            'weak-range',
            'Weak memory range',
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: TahfeezSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(TahfeezSpacing.sm),
              ),
              child: const Text('sample range'),
            ),
          ),
          word(
            'scheduled',
            'Scheduled revision',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_repeat, size: 18, color: scheme.tertiary),
                const SizedBox(width: 4),
                const Text('sample'),
              ],
            ),
          ),
          word(
            'completed',
            'Completed session',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 18, color: scheme.primary),
                const SizedBox(width: 4),
                const Text('sample'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
