import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/coming_soon.dart';
import '../../domain/reader_mode.dart';

/// A three-way mode switch (`docs/reference/04_READER_SPEC.md` §2/§3).
/// [ReaderMode.verseByVerse] (this screen) and [ReaderMode.mushaf] (a real
/// position-preserving transition into the Mushaf renderer, Milestone 7 —
/// the same intent as the reference's `handleModeTransition`, independently
/// implemented) are both real; Translation is shown but disabled with a
/// "coming soon" tap response, per this milestone's "architecturally ready
/// for translation..." requirement and its explicit "wire interfaces or
/// intentional disabled states rather than fake behavior" instruction.
class ReaderModeSwitch extends StatelessWidget {
  const ReaderModeSwitch({
    super.key,
    required this.mode,
    required this.onSwitchToMushaf,
  });

  final ReaderMode mode;

  /// Called when the user taps the Mushaf segment — resolves the current
  /// reading position to a Mushaf page and navigates there.
  final VoidCallback onSwitchToMushaf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget segment(IconData icon, String tooltip, ReaderMode segmentMode) {
      final isSelected = segmentMode == mode;
      final isAvailable =
          segmentMode == ReaderMode.verseByVerse ||
          segmentMode == ReaderMode.mushaf;
      return Tooltip(
        message: isAvailable ? tooltip : '$tooltip — coming soon',
        child: InkWell(
          onTap: () {
            if (segmentMode == ReaderMode.mushaf) {
              onSwitchToMushaf();
            } else if (!isAvailable) {
              showComingSoon(context);
            }
          },
          borderRadius: BorderRadius.circular(TahfeezSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(TahfeezSpacing.sm),
            child: Icon(
              icon,
              size: 20,
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(
                      alpha: isAvailable ? 1 : 0.4,
                    ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        segment(
          Icons.view_agenda_outlined,
          'Verse by verse',
          ReaderMode.verseByVerse,
        ),
        segment(Icons.menu_book_outlined, 'Mushaf', ReaderMode.mushaf),
        segment(
          Icons.translate_outlined,
          'Translation',
          ReaderMode.translation,
        ),
      ],
    );
  }
}
