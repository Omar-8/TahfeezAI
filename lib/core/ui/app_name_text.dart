import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's name with its "AI" in the brand's green (as the website has
/// it): the accent in a light theme, its lighter mint in a dark one.
class AppNameText extends StatelessWidget {
  const AppNameText(this.name, {super.key, this.style, this.aiColor});

  /// "TahfeezAI", "تحفيظ AI"…
  final String name;
  final TextStyle? style;

  /// The "AI"'s colour, when the ground is fixed (the splash); otherwise
  /// the theme's.
  final Color? aiColor;

  @override
  Widget build(BuildContext context) {
    final at = name.indexOf('AI');
    if (at < 0) return Text(name, style: style);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green =
        aiColor ??
        (dark
            ? TahfeezExplorationPalette.darkPrimary
            : TahfeezExplorationPalette.lightPrimaryAccent);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name.substring(0, at)),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: green),
          ),
          TextSpan(text: name.substring(at + 2)),
        ],
      ),
      style: style,
    );
  }
}
