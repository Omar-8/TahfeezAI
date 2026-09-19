import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/components/components.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../core/ui/coming_soon.dart';
import '../../../../quran/domain/models/ayah_models.dart';
import 'verse_share_sheet.dart';

/// One verse — `docs/reference/04_READER_SPEC.md` §5's `VerseView`,
/// independently designed: an ayah-reference badge (tap to copy), the
/// per-verse action row, and (when
/// [ArabicTextVisiblePreferenceController] allows) the Arabic text itself,
/// rendered right-to-left in [quranTextStyle] regardless of the app's UI
/// locale.
///
/// Content comes only from [ayah] (an [AyahWithWords], loaded by
/// `ReaderSessionController` through the batched repository call) — never
/// a literal string in this widget, per this milestone's "do not hard-code
/// Quran text into widgets" requirement.
///
/// Play/Bookmark/Tafsir are wired, real widgets whose action is an honest
/// "coming soon" today (no verse-audio source, no `UserDataRepository`
/// implementation, no Tafsir dataset exist yet) rather than fake behavior,
/// per this milestone's explicit instruction. Copy and Share are genuinely
/// functional today.
class VerseBlock extends StatelessWidget {
  const VerseBlock({
    super.key,
    required this.ayah,
    required this.arabicVisible,
    required this.isSelected,
    required this.hasActiveSelection,
    required this.onToggleSelection,
  });

  final AyahWithWords ayah;
  final bool arabicVisible;
  final bool isSelected;
  final bool hasActiveSelection;
  final VoidCallback onToggleSelection;

  String get _reference => '${ayah.ayah.chapterNo}:${ayah.ayah.verseNo}';

  String get _arabicText => ayah.words.map((w) => w.text).join(' ');

  void _copyReference(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _reference));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Copied $_reference')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: hasActiveSelection ? onToggleSelection : null,
        onLongPress: onToggleSelection,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TahfeezSpacing.md,
            vertical: TahfeezSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: TahfeezSpacing.sm,
            children: [
              TahfeezVerseActionBar(
                trailing: InkWell(
                  onTap: () => _copyReference(context),
                  borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TahfeezSpacing.sm,
                      vertical: TahfeezSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(TahfeezRadii.pill),
                    ),
                    child: Text(
                      _reference,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
                actions: [
                  TahfeezVerseAction(
                    icon: Icons.play_circle_outline,
                    tooltip: 'Play',
                    onPressed: () => showComingSoon(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.bookmark_border,
                    tooltip: 'Bookmark',
                    onPressed: () => showComingSoon(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.menu_book_outlined,
                    tooltip: 'Tafsir',
                    onPressed: () => showComingSoon(context),
                  ),
                  TahfeezVerseAction(
                    icon: Icons.ios_share_outlined,
                    tooltip: 'Share',
                    onPressed: () => showVerseShareSheet(
                      context,
                      '$_reference\n\n$_arabicText',
                    ),
                  ),
                ],
              ),
              if (arabicVisible)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    _arabicText,
                    textAlign: TextAlign.right,
                    style: quranTextStyle(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
