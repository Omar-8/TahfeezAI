import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';

/// Shared feedback for Home entry points whose destination screen doesn't
/// exist yet (the Reader, Explore categories, ...). Keeps those entry
/// points honestly interactive — tappable, giving feedback — rather than
/// either doing nothing or crashing on a missing route.
void showComingSoon(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.comingSoonMessage)));
}
