import 'package:freezed_annotation/freezed_annotation.dart';

part 'dataset_metadata.freezed.dart';

/// Provenance/version stamp for whichever Quran dataset is currently
/// imported.
///
/// Required by this milestone's integrity rules ("dataset version/hash
/// metadata") so it is always possible to answer "exactly which dataset,
/// from which source, is this install using" — important both for support
/// and because `docs/CLEAN_ROOM_RULES.md` requires every shipped Quran
/// resource to be traceable to a recorded, license-verified source (see
/// `docs/THIRD_PARTY_RESOURCES.md` once a real dataset is integrated).
@freezed
abstract class DatasetMetadata with _$DatasetMetadata {
  const factory DatasetMetadata({
    /// Identifies the dataset source/edition (e.g. a slug for the upstream
    /// project + its version), not an app build number.
    required String datasetVersion,

    /// A content hash (e.g. SHA-256 of the canonical source files) proving
    /// the imported data matches a known-good, verified snapshot.
    required String contentHash,
    required DateTime importedAt,
  }) = _DatasetMetadata;
}
