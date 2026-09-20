import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/coming_soon.dart';
import '../../domain/reader_mode.dart';

/// A three-way mode switch (`docs/reference/04_READER_SPEC.md` §2/§3).
/// [ReaderMode.verseByVerse] and [ReaderMode.mushaf] both switch in place,
/// preserving reading position in both directions (`reader_screen.dart`);
/// Translation is shown but disabled with a "coming soon" tap response, per
/// this milestone's "architecturally ready for translation..." requirement
/// and its explicit "wire interfaces or intentional disabled states rather
/// than fake behavior" instruction.
class ReaderModeSwitch extends StatelessWidget {
  const ReaderModeSwitch({
    super.key,
    required this.mode,
    required this.onSwitchToMode,
    this.showTranslationSegment = true,
    this.compact = false,
  });

  final ReaderMode mode;

  /// Called when the user taps an available (non-"coming soon") segment
  /// other than the currently active one, to switch in place — resolving
  /// and preserving the current reading position across the switch.
  final ValueChanged<ReaderMode> onSwitchToMode;

  /// `false` in Mushaf mode's app bar: a permanently-disabled stub segment
  /// is the first thing worth dropping when that app bar's live Surah/
  /// page/Juz title is already competing for room. Still shown in
  /// verse-by-verse mode, per this milestone's original "wire interfaces
  /// or intentional disabled states rather than fake behavior" instruction.
  final bool showTranslationSegment;

  /// Tighter per-segment padding — Mushaf mode's app bar (title + this
  /// switch + Appearance) is the tightest on horizontal space of the two
  /// places this renders.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final segmentPadding = compact ? TahfeezSpacing.xs : TahfeezSpacing.sm;

    Widget segment(IconData icon, String tooltip, ReaderMode segmentMode) {
      final isSelected = segmentMode == mode;
      final isAvailable =
          segmentMode == ReaderMode.verseByVerse ||
          segmentMode == ReaderMode.mushaf;
      return Tooltip(
        message: isAvailable ? tooltip : '$tooltip — coming soon',
        child: InkWell(
          onTap: () {
            if (isSelected) return;
            if (isAvailable) {
              onSwitchToMode(segmentMode);
            } else {
              showComingSoon(context);
            }
          },
          borderRadius: BorderRadius.circular(TahfeezSpacing.sm),
          child: Padding(
            padding: EdgeInsets.all(segmentPadding),
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
        if (showTranslationSegment)
          segment(
            Icons.translate_outlined,
            'Translation',
            ReaderMode.translation,
          ),
      ],
    );
  }
}
