import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../quran_providers.dart';
import 'quran_script_code.dart';

part 'canonical_ayah_word_text.g.dart';

/// One word's canonical, standard-Unicode Arabic text — the *only* safe
/// source for displaying a Quran word's Arabic script outside its own
/// specific rendering context.
///
/// Exists so a caller resolving a tap to `(ayahId, wordIndex)` (the Mushaf
/// renderer's [MushafWordPlacement], the verse-by-verse reader's
/// [AyahWord]) never needs to pass its own already-in-hand text string
/// into a shared display surface like the word detail sheet. That matters
/// specifically for the Mushaf renderer: a [MushafToken]'s `displayText` is
/// QCF page-specific-glyph text — private-use-area codepoints meaningful
/// *only* when painted with that exact page's own font (see
/// `docs/QURAN_DATA_PROVENANCE.md`). Rendering those codepoints with any
/// other font (e.g. the word detail sheet's generic Arabic-capable system
/// font) does not fail loudly — it silently reinterprets the codepoints
/// against an unrelated glyph table and can display a completely different,
/// wrong-looking word. Looking the word up here instead, by its canonical
/// `(ayahId, wordIndex)` identity, always returns real [AyahWord] text,
/// which is standard Unicode Arabic and safe to render with any
/// Arabic-capable font — consistent with this project's "AyahWord is the
/// sole authority for canonical Quran word semantics" rule.
@riverpod
Future<String?> canonicalAyahWordText(
  Ref ref, {
  required int ayahId,
  required int wordIndex,
}) async {
  final scriptCode = ref.watch(quranScriptCodeProvider);
  final words = await ref
      .watch(quranRepositoryProvider)
      .getWordsForAyah(ayahId, scriptCode: scriptCode);
  for (final word in words) {
    if (word.wordIndex == wordIndex) return word.text;
  }
  return null;
}

/// An ayah's canonical words joined by spaces — the same safe source as
/// [canonicalAyahWordText], for a whole ayah (the Mushaf's ayah sheet).
@riverpod
Future<String?> canonicalAyahText(Ref ref, {required int ayahId}) async {
  final scriptCode = ref.watch(quranScriptCodeProvider);
  final words = await ref
      .watch(quranRepositoryProvider)
      .getWordsForAyah(ayahId, scriptCode: scriptCode);
  if (words.isEmpty) return null;
  return [for (final w in words) w.text].join(' ');
}
