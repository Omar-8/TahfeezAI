import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/quran_text_style.dart';
import '../../../../quran/application/bismillah_text.dart';
import '../../../mushaf/application/mushaf_appearance_controller.dart';
import '../../../mushaf/domain/mushaf_appearance.dart';
import '../../application/quran_display_providers.dart';
import '../../application/uthmanic_hafs_font_providers.dart';

/// Al-Fatiha's first ayah's id (chapter 1, verse 1) -- the Bismillah's
/// canonical source (see `bismillah_text.dart`'s own doc comment), reused
/// here to look up the same ayah's QPC Hafs display words.
const _alFatihaVerseOneAyahId = 1001;

/// A divider marking where a chapter's Bismillah belongs, showing its real,
/// canonical Arabic text (sourced from Al-Fatiha's own ayah 1 — see
/// [bismillahTextProvider]'s doc comment for why that, and not a literal
/// string, is the correct source) once a Quran dataset is installed, or a
/// plain structural marker before then.
class BismillahDivider extends ConsumerWidget {
  const BismillahDivider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = ref.watch(bismillahTextProvider).value;
    final quranTextColor = ref
        .watch(mushafAppearanceControllerProvider)
        .colors
        .text;
    final quranFontFamily = ref
        .watch(uthmanicHafsFontManifestProvider)
        .value
        ?.fontFamily;
    final displayWords = ref
        .watch(quranDisplayRepositoryProvider)
        .displayWordsForAyah(_alFatihaVerseOneAyahId);
    final displayText = displayWords?.join(' ');
    final useQpcHafs = quranFontFamily != null && displayText != null;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TahfeezSpacing.xl,
        vertical: TahfeezSpacing.sm,
      ),
      child: text == null
          ? Row(
              children: [
                Expanded(child: Divider(color: scheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TahfeezSpacing.sm,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(child: Divider(color: scheme.outlineVariant)),
              ],
            )
          : Center(
              // Same helper, same size/color/font as `VerseBlock`'s own
              // verse text -- so the Bismillah reads as part of the same
              // running Quran text, not a separately-styled element. Joined
              // from the same per-word QPC Hafs display list `VerseBlock`
              // uses (never the ayah-by-ayah script directly): keeping one
              // single source of "is this ayah's QPC Hafs data validated"
              // logic, rather than a second path that could disagree.
              child: Text(
                useQpcHafs ? displayText : text,
                textDirection: TextDirection.rtl,
                style: quranTextStyle(
                  color: quranTextColor,
                  fontFamily: useQpcHafs ? quranFontFamily : null,
                  fontSize: quranVerseFontSize,
                ),
              ),
            ),
    );
  }
}
