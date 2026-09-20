import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../quran/data/quran_display_manifest_codec.dart';
import '../../../quran/domain/models/quran_display_models.dart';

part 'quran_display_providers.g.dart';

const _qpcHafsDisplayWordsAsset =
    'assets/quran/quran_display/qpc_hafs_display_words.json';

/// The verified QPC Hafs display-word manifest — verse-by-verse mode's
/// Quran text display source, kept separate from canonical `AyahWord`
/// (Tanzil, `QuranRepository`) and Mushaf mode's `MushafToken` (QPC V2).
/// See `docs/QURAN_DATA_PROVENANCE.md` §17. `null` in a release build
/// (`SHIP_BLOCKED_LICENSE`, same gate as every other QUL-sourced resource)
/// or if the manifest asset isn't bundled — both honest, expected states
/// that [QuranDisplayRepository] falls back from, never an error.
@Riverpod(keepAlive: true)
Future<QpcHafsDisplayManifest?> qpcHafsDisplayManifest(Ref ref) async {
  if (kReleaseMode) return null;

  final String raw;
  try {
    raw = await rootBundle.loadString(_qpcHafsDisplayWordsAsset);
  } catch (_) {
    return null;
  }
  return qpcHafsDisplayManifestFromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
}

/// Verse-by-verse mode's one entry point for "what QPC Hafs text should
/// this canonical ayah's words display as" — the `QuranDisplayRepository`
/// this milestone's architecture calls for, deliberately this small: the
/// manifest is a flat, pre-validated lookup (built and validated at
/// generation time, not at read time), so there is no query logic to hide
/// behind a larger interface.
class QuranDisplayRepository {
  const QuranDisplayRepository(this._manifest);

  final QpcHafsDisplayManifest? _manifest;

  /// The QPC Hafs display words for [ayahId], in the same order as (and
  /// exactly as many as) that ayah's real `AyahWord`s — so a caller can
  /// always zip `ayah.words[i]` (canonical identity, tap targets,
  /// word-by-word/audio-highlighting) with `displayWordsForAyah(ayahId)![i]`
  /// (the text to actually paint) and know both refer to the same word.
  ///
  /// Returns `null` when no validated QPC Hafs entry exists for this ayah
  /// — no manifest bundled/loaded, or this specific ayah was excluded by
  /// the build-time validation (currently just 37:130, a genuine
  /// Tanzil/QPC word-segmentation difference — see the manifest's own
  /// `excludedAyahIds`). Callers must treat `null` as "fall back to
  /// canonical text," never as an error.
  List<String>? displayWordsForAyah(int ayahId) {
    return _manifest?.wordsByAyahId[ayahId];
  }
}

// `keepAlive: true`, matching every other manifest/repository-shaped
// provider in this codebase (`uthmanicHafsFontManifestProvider` and
// siblings): a stable, cheap-to-hold wrapper that should persist for the
// app's lifetime, not be autoDispose-torn-down whenever momentarily
// unwatched (e.g. between two verses' own `VerseBlock`s rebuilding).
@Riverpod(keepAlive: true)
QuranDisplayRepository quranDisplayRepository(Ref ref) {
  final manifest = ref.watch(qpcHafsDisplayManifestProvider).value;
  return QuranDisplayRepository(manifest);
}
