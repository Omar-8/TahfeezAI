import '../models/wbw_models.dart';

/// Read/manage access to locally installed word-by-word (WBW) language
/// packs.
///
/// Backed by its own physically separate database (`lib/wbw/data/wbw_database.dart`),
/// never the immutable canonical `QuranDatabase` — per `docs/ARCHITECTURE.md`
/// §4's "Resource metadata (translations/tafsir/WBW/audio/atlas)" row, WBW
/// content is downloadable/optional resource data, not canonical Quran data,
/// even though it is keyed against canonical word indices. Implemented by
/// `DriftWbwRepository` (`lib/wbw/data/repositories/drift_wbw_repository.dart`).
///
/// Every method here is local-only; per `docs/PROJECT_BRIEF.md`'s
/// offline-first requirement, an installed pack must remain fully usable
/// with no network.
abstract class WbwRepository {
  /// Packs currently installed locally.
  Future<List<WbwLanguagePack>> getInstalledPacks();

  Future<WbwLanguagePack?> getInstalledPack(String packId);

  /// Installs [pack] together with [words] as one atomic operation — calling
  /// this again for a [pack] with the same `id` but a newer `version`
  /// replaces the previously installed pack and its words in place (an
  /// "update"), mirroring `QuranDatasetImporter`'s transactional-replace
  /// shape (`lib/quran/data/import/quran_dataset_importer.dart`).
  Future<void> installPack(WbwLanguagePack pack, List<WbwWordEntry> words);

  Future<void> deletePack(String packId);

  /// The single word [pack] has for (ayahId, wordIndex), or `null` if that
  /// pack is not installed or has no entry for that word.
  Future<WbwWordEntry?> getWord({
    required String packId,
    required int ayahId,
    required int wordIndex,
  });

  /// Every word [packId] has for [ayahId], in word order (one query).
  Future<List<WbwWordEntry>> getAyahWords({
    required String packId,
    required int ayahId,
  });
}
