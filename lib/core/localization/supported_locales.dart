import 'package:flutter/widgets.dart';

/// Locales Tahfeez's UI ships with today.
///
/// This starts intentionally small (English + Arabic, the latter proving
/// the RTL foundation). `docs/reference/15_LOCALIZATION_SPEC.md` documents
/// the reference app's much larger 22-language roster as *reference
/// behavior*, not a Tahfeez requirement — Tahfeez grows this list over time
/// as real translations are authored and reviewed, per its own roadmap.
const kTahfeezSupportedLocales = <Locale>[Locale('en'), Locale('ar')];
