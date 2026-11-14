/// Each surah's aims (مقاصد السورة) as Al-Mukhtasar fi Tafsir al-Qur'an
/// al-Karim gives them — verbatim, in the languages its editions publish
/// them in — and, where none does, Tahfeez AI's translations of the
/// English edition's ([isTranslated];
/// `tool/quran_data/build_surah_aims.py`).
class SurahAims {
  const SurahAims(this._byLanguage, [this._translated = const {}]);

  factory SurahAims.fromJson(Map<String, Object?> json) => SurahAims(
    {
      for (final MapEntry(key: language, value: texts)
          in (json['aims']! as Map<String, Object?>).entries)
        language: [for (final t in texts! as List) t as String],
    },
    {
      for (final MapEntry(key: language, value: surahs)
          in ((json['translated'] as Map<String, Object?>?) ?? const {})
              .entries)
        language: {for (final s in surahs! as List) s as int},
    },
  );

  /// Language code → the 114 surahs' aims, in order.
  final Map<String, List<String>> _byLanguage;

  /// Language code → the surahs whose aims are Tahfeez AI's translations.
  final Map<String, Set<int>> _translated;

  /// Whether [surahNo]'s aims in [language] are Tahfeez AI's translation
  /// (not an edition's own).
  bool isTranslated(int surahNo, String language) =>
      _translated[language]?.contains(surahNo) ?? false;

  Iterable<String> get languages => _byLanguage.keys;

  /// [surahNo]'s aims in [language]; `null` where it has none in it.
  String? of(int surahNo, String language) {
    final texts = _byLanguage[language];
    if (texts == null || surahNo < 1 || surahNo > texts.length) return null;
    final text = texts[surahNo - 1];
    return text.isEmpty ? null : text;
  }
}
