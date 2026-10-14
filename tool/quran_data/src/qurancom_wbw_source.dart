// Aligns Quran.com's word-by-word English (fetched by
// `fetch_sources.dart wbw` into `.cache/qurancom_wbw/`) to Tahfeez's
// canonical words (Tanzil), so each meaning is keyed by the canonical
// (ayahId, wordIndex) — never by Quran.com's own word positions.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:crypto/crypto.dart';
import 'package:tahfeez_ai/core/downloads/resource_integrity.dart';
import 'package:tahfeez_ai/quran/domain/models/ayah_models.dart';
import 'package:tahfeez_ai/wbw/domain/models/wbw_models.dart';

/// The pack's words, with what the alignment did.
class QuranComWbwResult {
  const QuranComWbwResult({
    required this.pack,
    required this.words,
    required this.sourceHash,
    required this.joined,
    required this.respelled,
  });

  final WbwLanguagePack pack;
  final List<WbwWordEntry> words;
  final String sourceHash;

  /// Canonical words that Quran.com writes as one (e.g. "بَعْدَ مَا"),
  /// each given the joint meaning; and positions matched despite a
  /// different spelling.
  final int joined, respelled;
}

/// The letters of a word: no vowel or recitation marks, spaces, tatweel or
/// directional marks; one alif; final yaa as dotless.
String _skeleton(String word) {
  var t = word.replaceAll(RegExp(r'[\sً-ٰٟۖ-ۭـ‎‏]'), '');
  for (final alif in const ['ٱ', 'آ', 'أ', 'إ']) {
    t = t.replaceAll(alif, 'ا');
  }
  return t.replaceAll('ى', 'ي');
}

/// Quran.com's name for each language it serves word meanings in.
const quranComLanguageNames = {
  'en': 'english',
  'ur': 'urdu',
  'id': 'indonesian',
  'tr': 'turkish',
  'fa': 'persian',
  'bn': 'bengali',
};

/// [languageCode]'s meanings, aligned. A meaning Quran.com serves in
/// another language (its English, where it has none in this one) is left
/// out — the app shows the English pack's for that word instead. The
/// transliteration (the same in every language) is kept in English's only.
QuranComWbwResult alignQuranComWbw({
  required Directory cacheDir,
  required List<AyahWord> canonicalWords,
  required String packId,
  String languageCode = 'en',
  String displayName = 'English word by word (Quran.com)',
}) {
  final languageName = quranComLanguageNames[languageCode]!;
  final withTransliteration = languageCode == 'en';
  final canon = <int, List<AyahWord>>{};
  for (final w in canonicalWords) {
    (canon[w.ayahId] ??= []).add(w);
  }
  for (final ws in canon.values) {
    ws.sort((a, b) => a.wordIndex.compareTo(b.wordIndex));
  }

  final hashInput = BytesBuilder();
  final source = <int, List<Map>>{};
  for (var surah = 1; surah <= 114; surah++) {
    final bytes = File('${cacheDir.path}/$surah.json').readAsBytesSync();
    hashInput.add(bytes);
    for (final v in (jsonDecode(utf8.decode(bytes)) as List).cast<Map>()) {
      final [chapter, verse] = '${v['verse_key']}'
          .split(':')
          .map(int.parse)
          .toList();
      source[chapter * 1000 + verse] = [
        for (final w in (v['words'] as List).cast<Map>())
          if (w['char_type_name'] == 'word') w,
      ];
    }
  }

  final words = <WbwWordEntry>[];
  var joined = 0, respelled = 0;
  for (final MapEntry(key: ayahId, value: cw) in canon.entries) {
    final qw = source[ayahId] ?? const [];
    String? meaning(Map w) {
      final t = w['translation'] as Map?;
      final text = (t?['text'] as String?)?.trim();
      return t?['language_name'] == languageName &&
              text != null &&
              text.isNotEmpty
          ? text
          : null;
    }

    String? latin(Map w) => withTransliteration
        ? ((w['transliteration'] as Map?)?['text'] as String?)
        : null;
    void add(AyahWord c, Map q) => words.add(
      WbwWordEntry(
        packId: packId,
        ayahId: ayahId,
        wordIndex: c.wordIndex,
        translation: meaning(q),
        transliteration: latin(q),
      ),
    );

    if (qw.length == cw.length) {
      // Same words: matched by position, at most one spelled differently.
      final differing = [
        for (var i = 0; i < cw.length; i++)
          if (_skeleton(cw[i].text) != _skeleton('${qw[i]['text_uthmani']}')) i,
      ];
      if (differing.length > 1) {
        throw StateError('$ayahId: ${differing.length} words differ');
      }
      respelled += differing.length;
      for (var i = 0; i < cw.length; i++) {
        add(cw[i], qw[i]);
      }
      continue;
    }
    // Quran.com joins two canonical words: both get the joint meaning.
    var c = 0;
    for (final q in qw) {
      final s = _skeleton('${q['text_uthmani']}');
      if (c < cw.length && _skeleton(cw[c].text) == s) {
        add(cw[c++], q);
      } else if (c + 1 < cw.length &&
          _skeleton(cw[c].text) + _skeleton(cw[c + 1].text) == s) {
        add(cw[c++], q);
        add(cw[c++], q);
        joined += 2;
      } else {
        throw StateError('$ayahId: cannot align "${q['text_uthmani']}"');
      }
    }
    if (c != cw.length) {
      throw StateError('$ayahId: ${cw.length - c} canonical words left over');
    }
  }
  words.sort(
    (a, b) => a.ayahId != b.ayahId
        ? a.ayahId.compareTo(b.ayahId)
        : a.wordIndex.compareTo(b.wordIndex),
  );

  final pack = WbwLanguagePack(
    id: packId,
    languageCode: languageCode,
    displayName: displayName,
    version: 1,
    checksum: computeResourceChecksum([
      for (final w in words)
        '${w.ayahId}:${w.wordIndex}:${w.translation}:${w.transliteration}',
    ]),
    source: languageCode == 'en'
        ? 'Quran.com API v4 (QUL resource 92)'
        : 'Quran.com API v4',
    license:
        'Unverified — shipped by owner decision 2026-10-09 '
        '(docs/THIRD_PARTY_RESOURCES.md)',
    hasTranslation: true,
    hasTransliteration: withTransliteration,
  );
  return QuranComWbwResult(
    pack: pack,
    words: words,
    sourceHash: sha256.convert(hashInput.takeBytes()).toString(),
    joined: joined,
    respelled: respelled,
  );
}
