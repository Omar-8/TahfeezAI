import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/logging/app_logger.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../quran_database.dart';
import 'dataset_json_codec.dart';
import 'dataset_integrity_exception.dart';
import 'quran_dataset_importer.dart';

/// Seeds Tahfeez's local databases from the bundled production dataset
/// (`assets/quran/`, built by `tool/quran_data/build_production_data.dart`)
/// on first launch, so Android/iOS never need a network call to have a
/// working Quran, translations, or tafsir — per `docs/PROJECT_BRIEF.md`'s
/// offline requirement and `docs/QURAN_DATA_PROVENANCE.md`.
///
/// Every asset's bytes are hash-verified against
/// `assets/quran/resource_manifest.json` before anything is imported —
/// "verify manifest/hash, then open the local database" — and each of the
/// three resources this seeds (canonical Quran, English translation, German
/// translation, Al-Muyassar tafsir) fails independently: a corrupt or
/// missing translation/tafsir never blocks the canonical Quran, and a
/// corrupt or missing canonical Quran is logged as a critical error and
/// left unimported rather than partially written — [QuranDatasetImporter]
/// already guarantees the latter is all-or-nothing.
///
/// The Mushaf layer is not seeded here at all: no bundled Mushaf asset
/// exists yet, since the real QUL word dataset needed to populate one
/// hasn't been supplied (see `docs/QURAN_DATA_PROVENANCE.md`) and no
/// synthetic stand-in is ever created for it.
class BundledDatasetSeeder {
  const BundledDatasetSeeder({
    required this.quranRepository,
    required this.quranDatabase,
    required this.translationRepository,
    required this.tafsirRepository,
    required this.logger,
    this.importer = const QuranDatasetImporter(),
  });

  final QuranRepository quranRepository;
  final QuranDatabase quranDatabase;
  final TranslationRepository translationRepository;
  final TafsirRepository tafsirRepository;
  final AppLogger logger;
  final QuranDatasetImporter importer;

  static const _manifestAsset = 'assets/quran/resource_manifest.json';

  Future<void> seedIfNeeded() async {
    final Map<String, dynamic> manifest;
    final Map<String, dynamic> hashes;
    try {
      manifest = jsonDecode(
        await rootBundle.loadString(_manifestAsset),
      ) as Map<String, dynamic>;
      hashes = (manifest['packagedAssetHashes'] as Map).cast<String, dynamic>();
    } catch (e, st) {
      logger.error(
        'Could not read bundled Quran resource manifest — no data seeded.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
      return;
    }

    await _seedCanonicalQuran(hashes);
    await _seedTranslation(
      hashes,
      assetPath: 'assets/quran/translations/en_rowwad.json',
      hashKey: 'translations/en_rowwad.json',
    );
    await _seedTranslation(
      hashes,
      assetPath: 'assets/quran/translations/de_rowwad.json',
      hashKey: 'translations/de_rowwad.json',
    );
    await _seedTafsir(
      hashes,
      assetPath: 'assets/quran/tafsir/ar_muyassar.json',
      hashKey: 'tafsir/ar_muyassar.json',
    );
  }

  Future<Uint8List?> _loadVerified(
    Map<String, dynamic> hashes,
    String assetPath,
    String hashKey, {
    required String resourceLabel,
  }) async {
    final expectedHash = hashes[hashKey] as String?;
    if (expectedHash == null) {
      logger.error(
        '$resourceLabel: no hash recorded in the resource manifest for $hashKey.',
        tag: 'BundledDatasetSeeder',
      );
      return null;
    }
    final Uint8List bytes;
    try {
      bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
    } catch (e, st) {
      logger.error(
        '$resourceLabel: could not load bundled asset $assetPath.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
      return null;
    }
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != expectedHash) {
      logger.error(
        '$resourceLabel: bundled asset $assetPath failed hash verification '
        '(expected $expectedHash, got $actualHash) — refusing to import it.',
        tag: 'BundledDatasetSeeder',
      );
      return null;
    }
    return bytes;
  }

  Future<void> _seedCanonicalQuran(Map<String, dynamic> hashes) async {
    final existing = await quranRepository.getDatasetMetadata();

    final bytes = await _loadVerified(
      hashes,
      'assets/quran/quran_dataset.json',
      'quran_dataset.json',
      resourceLabel: 'Canonical Quran',
    );
    if (bytes == null) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final payload = quranDatasetPayloadFromJson(json);

      if (existing != null &&
          existing.contentHash == payload.metadata.contentHash) {
        return; // Already seeded with this exact dataset.
      }

      await importer.import(quranDatabase, payload);
      logger.info(
        'Seeded canonical Quran: ${payload.surahs.length} surahs, '
        '${payload.ayahs.length} ayahs.',
        tag: 'BundledDatasetSeeder',
      );
    } on DatasetIntegrityException catch (e, st) {
      logger.error(
        'Bundled canonical Quran dataset failed integrity validation — '
        'core Quran reading will be unavailable until this is fixed. '
        'Never displaying a possibly-corrupt Quran.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
    } catch (e, st) {
      logger.error(
        'Failed to seed canonical Quran from bundled asset.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _seedTranslation(
    Map<String, dynamic> hashes, {
    required String assetPath,
    required String hashKey,
  }) async {
    final bytes = await _loadVerified(
      hashes,
      assetPath,
      hashKey,
      resourceLabel: 'Translation ($hashKey)',
    );
    if (bytes == null) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final book = translationBookFromJson(
        json['book'] as Map<String, dynamic>,
      );
      final existing = await translationRepository.getInstalledTranslation(
        book.slug,
      );
      if (existing != null && existing.checksum == book.checksum) {
        return;
      }
      final verses = (json['verses'] as List)
          .cast<Map<String, dynamic>>()
          .map(translationVerseFromJson)
          .toList();
      await translationRepository.installTranslation(book, verses);
      logger.info(
        'Seeded translation "${book.slug}": ${verses.length} verses.',
        tag: 'BundledDatasetSeeder',
      );
    } catch (e, st) {
      logger.error(
        'Failed to seed translation from $assetPath — this translation will '
        'be unavailable, other resources are unaffected.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _seedTafsir(
    Map<String, dynamic> hashes, {
    required String assetPath,
    required String hashKey,
  }) async {
    final bytes = await _loadVerified(
      hashes,
      assetPath,
      hashKey,
      resourceLabel: 'Tafsir ($hashKey)',
    );
    if (bytes == null) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final work = tafsirWorkFromJson(json['work'] as Map<String, dynamic>);
      final existing = await tafsirRepository.getInstalledTafsir(work.id);
      if (existing != null && existing.checksum == work.checksum) {
        return;
      }
      final verses = (json['verses'] as List)
          .cast<Map<String, dynamic>>()
          .map(tafsirVerseFromJson)
          .toList();
      await tafsirRepository.installTafsir(work, verses);
      logger.info(
        'Seeded tafsir "${work.id}": ${verses.length} verses.',
        tag: 'BundledDatasetSeeder',
      );
    } catch (e, st) {
      logger.error(
        'Failed to seed tafsir from $assetPath — this tafsir will be '
        'unavailable, other resources are unaffected.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
    }
  }
}
