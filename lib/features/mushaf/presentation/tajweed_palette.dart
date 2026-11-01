import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../quran/domain/models/tajweed_models.dart';

/// Tajweed colours, chosen for Tahfeez: the madds from gold to deep red
/// as they lengthen, the nasal rules in greens and blue, qalqala in teal,
/// unpronounced letters faded. Each in a lighter tone on a dark page.
Color tajweedColor(TajweedGroup group, {required bool dark}) =>
    (dark ? _dark : _light)[group]!;

/// Whether [background] is a dark page (the reader's dark and black
/// themes).
bool isDarkPage(Color background) => background.computeLuminance() < 0.25;

const _light = {
  TajweedGroup.unpronounced: Color(0xFF9A9FA5),
  TajweedGroup.maddNatural: Color(0xFFB07D00),
  TajweedGroup.maddPermissible: Color(0xFFDB6E00),
  TajweedGroup.maddObligatory: Color(0xFFD03A26),
  TajweedGroup.maddNecessary: Color(0xFF9C1030),
  TajweedGroup.ghunnah: Color(0xFF178A44),
  TajweedGroup.ikhfa: Color(0xFF5E9416),
  TajweedGroup.iqlab: Color(0xFF2471C8),
  TajweedGroup.idgham: Color(0xFF7A55A8),
  TajweedGroup.qalqala: Color(0xFF00879A),
};

const _dark = {
  TajweedGroup.unpronounced: Color(0xFF7D838A),
  TajweedGroup.maddNatural: Color(0xFFE2B547),
  TajweedGroup.maddPermissible: Color(0xFFFF9E45),
  TajweedGroup.maddObligatory: Color(0xFFFF7461),
  TajweedGroup.maddNecessary: Color(0xFFFF5C7F),
  TajweedGroup.ghunnah: Color(0xFF5CD38A),
  TajweedGroup.ikhfa: Color(0xFFA6D861),
  TajweedGroup.iqlab: Color(0xFF6FB2FF),
  TajweedGroup.idgham: Color(0xFFC0A0F0),
  TajweedGroup.qalqala: Color(0xFF4DD6E6),
};

/// Each colour's name.
String tajweedGroupName(AppLocalizations l10n, TajweedGroup group) =>
    switch (group) {
      TajweedGroup.unpronounced => l10n.tajweedUnpronounced,
      TajweedGroup.maddNatural => l10n.tajweedMaddNatural,
      TajweedGroup.maddPermissible => l10n.tajweedMaddPermissible,
      TajweedGroup.maddObligatory => l10n.tajweedMaddObligatory,
      TajweedGroup.maddNecessary => l10n.tajweedMaddNecessary,
      TajweedGroup.ghunnah => l10n.tajweedGhunnah,
      TajweedGroup.ikhfa => l10n.tajweedIkhfa,
      TajweedGroup.iqlab => l10n.tajweedIqlab,
      TajweedGroup.idgham => l10n.tajweedIdgham,
      TajweedGroup.qalqala => l10n.tajweedQalqala,
    };

/// What each colour means: a dot and its name, in the app's theme.
class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Wrap(
      key: const ValueKey('tajweed-legend'),
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final group in TajweedGroup.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: tajweedColor(group, dark: dark),
                  shape: BoxShape.circle,
                ),
              ),
              // Wrapping on a narrow screen at large text.
              Flexible(
                child: Text(
                  tajweedGroupName(l10n, group),
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
