import 'package:flutter/widgets.dart';

/// Locales Tahfeez's UI ships with today.
///
/// `docs/reference/15_LOCALIZATION_SPEC.md` documents the reference app's
/// much larger 22-language roster as *reference behavior*, not a Tahfeez
/// requirement — Tahfeez grows this list as translations are authored.
const kTahfeezSupportedLocales = <Locale>[
  Locale('en'),
  Locale('ar'),
  Locale('ur'),
  Locale('tr'),
  Locale('fr'),
  Locale('de'),
  Locale('id'),
  Locale('es'),
  Locale('ru'),
  Locale('fa'),
  Locale('bn'),
];

/// Settings → Language: each UI language's code, flag and own name.
const kAppLanguages = <(String, String, String)>[
  ('en', '🇬🇧', 'English'),
  ('ar', '🇸🇦', 'العربية'),
  ('ur', '🇵🇰', 'اردو'),
  ('tr', '🇹🇷', 'Türkçe'),
  ('fr', '🇫🇷', 'Français'),
  ('de', '🇩🇪', 'Deutsch'),
  ('id', '🇮🇩', 'Bahasa Indonesia'),
  ('es', '🇪🇸', 'Español'),
  ('ru', '🇷🇺', 'Русский'),
  ('fa', '🇮🇷', 'فارسی'),
  ('bn', '🇧🇩', 'বাংলা'),
];
