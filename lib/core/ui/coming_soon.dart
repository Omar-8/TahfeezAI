import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';

/// Shared feedback for entry points whose destination/behavior doesn't
/// exist yet (an Explore category, a reader action tied to a later
/// milestone's audio/bookmarks/tafsir...). Keeps those entry points
/// honestly interactive — tappable, giving feedback — rather than either
/// doing nothing or crashing on a missing route.
///
/// Lives under `core/ui` (not one feature's `presentation/` folder) because
/// more than one feature needs it — first Home alone (Milestone 4), now
/// also the Quran index and Reader (Milestone 6) — and per
/// `docs/ARCHITECTURE.md` §1, feature areas must not depend on each other
/// directly.
void showComingSoon(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(l10n.comingSoonMessage)));
}
