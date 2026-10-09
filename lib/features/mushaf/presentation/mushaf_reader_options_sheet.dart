import 'package:flutter/material.dart';

import 'mushaf_appearance_sheet.dart';

/// Mushaf mode's "Reader options": the Mushaf page themes, directly (the
/// only Mushaf-page setting), with no menu in between. Shared by both
/// Mushaf surfaces — `reader_screen.dart`'s in-place Mushaf mode and
/// [MushafReaderScreen] — so they never drift apart.
void showMushafReaderOptionsSheet(BuildContext context) =>
    showMushafAppearanceSheet(context);
