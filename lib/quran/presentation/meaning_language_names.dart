/// A language's name in itself, for translation and tafsir lists (the
/// languages bundled today).
String nativeLanguageName(String code) => switch (code) {
  'ar' => 'العربية',
  'en' => 'English',
  'de' => 'Deutsch',
  'fr' => 'Français',
  'id' => 'Bahasa Indonesia',
  'tr' => 'Türkçe',
  'ur' => 'اردو',
  _ => code,
};
