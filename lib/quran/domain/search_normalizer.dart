/// Script-aware text normalization for Tahfeez's search index and queries —
/// independently designed from, but functionally equivalent to, the
/// normalization rules `docs/reference/07_SEARCH_SPEC.md` §3 documents:
/// the same normalized form must be produced for index content and for an
/// incoming query, or the two would never match.
///
/// Per `docs/CLEAN_ROOM_RULES.md`'s Quran-correctness rules, normalized text
/// produced here is only ever written to a *derived* search-index table
/// (`lib/quran/data/search_index_database.dart`) — never back onto
/// canonical Quran/translation text.
class SearchNormalizer {
  const SearchNormalizer();

  static final _diacritics = RegExp('[ً-ٰٟۖ-ۭ]');
  static const _tatweel = 'ـ';
  static final _alefVariants = RegExp('[آأإٱ]');
  static const _bareAlef = 'ا';
  static const _alefMaksura = 'ى';
  static const _yaa = 'ي';
  static final _whitespace = RegExp(r'\s+');

  /// The generic base pass every normalization starts from: lowercase, trim,
  /// and collapse internal whitespace. (The reference app also applies
  /// Unicode NFKC here; Tahfeez does not pull in a dedicated Unicode-
  /// normalization dependency for it, since none of the scripts this
  /// milestone targets — Arabic and Latin-script ASCII/Latin-1 content —
  /// have compatibility-decomposition forms that matter for search
  /// matching at this milestone's scope.)
  String _base(String input) {
    return input.trim().toLowerCase().replaceAll(_whitespace, ' ');
  }

  /// Normalizes Arabic-script text: strips tashkeel/other combining marks
  /// and tatweel, folds hamza-bearing alef variants (أ إ آ ٱ) to bare alef
  /// (ا), and folds alef-maksura (ى) to yaa (ي) — the same fold set
  /// `docs/reference/07_SEARCH_SPEC.md` §3 documents for Arabic-script
  /// languages.
  String normalizeArabic(String input) {
    var text = _base(input);
    text = text.replaceAll(_diacritics, '');
    text = text.replaceAll(_tatweel, '');
    text = text.replaceAll(_alefVariants, _bareAlef);
    text = text.replaceAll(_alefMaksura, _yaa);
    return text.replaceAll(_whitespace, ' ').trim();
  }

  /// Normalizes Latin-script text: the generic base pass is sufficient
  /// (lowercase covers case-insensitivity; Latin-script languages have no
  /// further script-specific folding at this milestone's scope).
  String normalizeLatin(String input) => _base(input);

  /// Splits [input] into search tokens after normalizing it with
  /// [normalizeArabic] (if [arabicScript]) or [normalizeLatin], dropping
  /// tokens shorter than 2 characters or containing no letter/digit —
  /// mirrors `FtsQueryBuilder`'s token-filtering rules
  /// (`docs/reference/07_SEARCH_SPEC.md` §4). Returns an empty list for a
  /// query with no valid tokens (e.g. all punctuation), signaling "there is
  /// nothing meaningful to search for."
  List<String> tokenize(String input, {required bool arabicScript}) {
    final normalized = arabicScript
        ? normalizeArabic(input)
        : normalizeLatin(input);
    if (normalized.isEmpty) return const [];
    final hasLetterOrDigit = RegExp(r'[a-z0-9؀-ۿ]');
    return normalized
        .split(' ')
        .where((token) => token.length >= 2 && hasLetterOrDigit.hasMatch(token))
        .toList();
  }
}
