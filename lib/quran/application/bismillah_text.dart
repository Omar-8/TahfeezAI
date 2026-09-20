import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../quran_providers.dart';
import 'quran_script_code.dart';

part 'bismillah_text.g.dart';

/// Al-Fatiha's first ayah's id (chapter 1, verse 1) — see
/// [bismillahTextProvider]'s doc comment for why this is the Bismillah's
/// canonical source.
const _alFatihaVerseOneAyahId = 1001;

/// The Bismillah's real, canonical Arabic text — sourced from Al-Fatiha's
/// ayah 1, which *is* the Bismillah word-for-word, rather than a literal
/// string written into this codebase.
///
/// The Bismillah recurs, textually identical, before every Surah except
/// At-Tawbah (and Al-Fatiha itself, where it already appears as ayah 1 —
/// callers never need this provider there). This project's rules forbid
/// ever generating canonical Quran text with AI or hard-coding it into a
/// widget, so the only correct source for "what the Bismillah says" is the
/// canonical [AyahWord] data already verified and stored for Al-Fatiha's
/// own first ayah — never a fresh literal. Returns `null` before that
/// dataset is installed, exactly like every other canonical-text lookup in
/// this app.
@riverpod
Future<String?> bismillahText(Ref ref) async {
  final scriptCode = ref.watch(quranScriptCodeProvider);
  final words = await ref
      .watch(quranRepositoryProvider)
      .getWordsForAyah(_alFatihaVerseOneAyahId, scriptCode: scriptCode);
  if (words.isEmpty) return null;
  return words.map((w) => w.text).join(' ');
}
