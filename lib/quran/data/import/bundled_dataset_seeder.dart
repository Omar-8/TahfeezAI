import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/logging/app_logger.dart';
import '../../../core/storage/browser_storage.dart';
import '../../domain/quran_dataset_payload.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/repositories/tafsir_repository.dart';
import '../../domain/repositories/translation_repository.dart';
import '../../../wbw/domain/models/wbw_models.dart';
import '../../../wbw/domain/repositories/wbw_repository.dart';
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
/// three independently-seeded resources (translations, tafsir) fails on
/// its own: a corrupt or missing translation/tafsir never blocks the
/// canonical Quran, and a corrupt or missing canonical Quran is logged as a
/// critical error and left unimported rather than partially written —
/// [QuranDatasetImporter] already guarantees the latter is all-or-nothing.
///
/// **Startup cost**: [seedIfNeeded] avoids re-parsing the (multi-megabyte)
/// canonical/Mushaf JSON on every launch. It first reads only the small
/// `resource_manifest.json` and compares its recorded hashes against a
/// tiny marker string persisted in [storage] from the last successful
/// import; only a mismatch (first launch, or an updated bundled dataset)
/// triggers loading and parsing the large files. A normal subsequent
/// launch does a handful of cheap reads, never a full JSON parse.
///
/// **The Mushaf layer** is seeded only when [includeMushaf] is true
/// (defaults to `!kReleaseMode` — development/profile builds only). QUL's
/// redistribution terms for the Mushaf layout/word-by-word/font resources
/// remain unverified (`SHIP_BLOCKED_LICENSE`,
/// `docs/QURAN_DATA_PROVENANCE.md` §7/§7a/§8); this gate stops the app's
/// own code from importing or displaying that data in a release build even
/// if the asset bytes happen to be present in a naively-built package. It
/// does **not** by itself keep those bytes out of a release binary — a
/// true public release must also remove/flavor-gate the asset declarations
/// themselves; see the release checklist in
/// `docs/QURAN_DATA_PROVENANCE.md`.
class BundledDatasetSeeder {
  const BundledDatasetSeeder({
    required this.quranRepository,
    required this.quranDatabase,
    required this.translationRepository,
    required this.tafsirRepository,
    this.wbwRepository,
    required this.logger,
    required this.storage,
    this.importer = const QuranDatasetImporter(),
    this.includeMushaf = !kReleaseMode,
  });

  final QuranRepository quranRepository;
  final QuranDatabase quranDatabase;
  final TranslationRepository translationRepository;
  final TafsirRepository tafsirRepository;

  /// Where the bundled word meanings go; none seeded without one.
  final WbwRepository? wbwRepository;
  final AppLogger logger;
  final BrowserStorage storage;
  final QuranDatasetImporter importer;
  final bool includeMushaf;

  static const _manifestAsset = 'assets/quran/resource_manifest.json';
  static const _mushafAsset = 'assets/quran/mushaf/kfgqpc_v2.json';
  static const _seededVersionKey = seededVersionKey;

  /// Marks which bundled dataset is installed; kept by Reset all data.
  static const seededVersionKey = 'quran.dataset.seeded_version';

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

    await _seedCanonicalQuranAndMushaf(hashes, manifest);
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
    await _seedWbw(
      hashes,
      assetPath: 'assets/quran/wbw/en_qurancom.json',
      hashKey: 'wbw/en_qurancom.json',
    );
    // The translation milestone's launch languages (T4).
    for (final name in const [
      'ur_junagarhi',
      'id_affairs',
      'tr_rowwad',
      'fr_noor',
    ]) {
      await _seedTranslation(
        hashes,
        assetPath: 'assets/quran/translations/$name.json',
        hashKey: 'translations/$name.json',
      );
    }
    for (final name in const [
      'en_mukhtasar',
      'id_mukhtasar',
      'tr_mukhtasar',
      'fr_mukhtasar',
    ]) {
      await _seedTafsir(
        hashes,
        assetPath: 'assets/quran/tafsir/$name.json',
        hashKey: 'tafsir/$name.json',
      );
    }
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

  Future<void> _seedCanonicalQuranAndMushaf(
    Map<String, dynamic> hashes,
    Map<String, dynamic> manifest,
  ) async {
    final canonicalHash = hashes['quran_dataset.json'] as String?;
    final mushafHash = includeMushaf
        ? manifest['mushafGeneratedDatasetHash'] as String?
        : null;
    final versionMarker = '$canonicalHash::${mushafHash ?? 'excluded'}';

    final existingMeta = await quranRepository.getDatasetMetadata();
    final storedMarker = await storage.getString(_seededVersionKey);
    if (existingMeta != null && storedMarker == versionMarker) {
      // Cheap path: already seeded with this exact combination — never
      // touches the large canonical/Mushaf JSON files on this launch.
      return;
    }

    final bytes = await _loadVerified(
      hashes,
      'assets/quran/quran_dataset.json',
      'quran_dataset.json',
      resourceLabel: 'Canonical Quran',
    );
    if (bytes == null) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      var payload = quranDatasetPayloadFromJson(json);

      if (includeMushaf) {
        payload = await _mergeMushaf(payload, mushafHash);
      }

      await importer.import(quranDatabase, payload);
      await storage.setString(_seededVersionKey, versionMarker);
      logger.info(
        'Seeded canonical Quran: ${payload.surahs.length} surahs, '
        '${payload.ayahs.length} ayahs'
        '${payload.mushafs.isEmpty ? '' : ' + Mushaf (${payload.mushafLines.length} lines, ${payload.mushafTokens.length} tokens)'}.',
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

  /// Loads and hash-verifies the (development-only) bundled Mushaf dataset
  /// and merges it into [payload], or returns [payload] unchanged if the
  /// asset is absent/unverifiable — a missing Mushaf dataset is an honest,
  /// expected state (`SHIP_BLOCKED_LICENSE`), never an error that blocks
  /// canonical Quran seeding.
  Future<QuranDatasetPayload> _mergeMushaf(
    QuranDatasetPayload payload,
    String? expectedHash,
  ) async {
    final Uint8List bytes;
    try {
      bytes = (await rootBundle.load(_mushafAsset)).buffer.asUint8List();
    } catch (_) {
      // Logged (not silently swallowed) even though an absent Mushaf asset
      // is an expected, honest state in a release build: at `debug` level
      // so it never looks like an error, but still visible via
      // `adb logcat`/`flutter logs` if someone genuinely expected the
      // asset to be present (e.g. a debug build where it was bundled but
      // failed to load for some other reason) and needs to tell the two
      // cases apart.
      logger.debug(
        'Mushaf dataset asset not loadable at "$_mushafAsset" — treating '
        'as not bundled in this build.',
        tag: 'BundledDatasetSeeder',
      );
      return payload; // Not bundled in this build — expected in release.
    }

    if (expectedHash == null) {
      logger.warning(
        'Mushaf dataset asset is present but the manifest has no recorded '
        'hash for it — skipping Mushaf seeding.',
        tag: 'BundledDatasetSeeder',
      );
      return payload;
    }
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != expectedHash) {
      logger.error(
        'Mushaf dataset failed hash verification (expected $expectedHash, '
        'got $actualHash) — refusing to import it.',
        tag: 'BundledDatasetSeeder',
      );
      return payload;
    }

    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final mushaf = mushafFromJson(json['mushaf'] as Map<String, dynamic>);
    final lines = (json['mushafLines'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafLineFromJson)
        .toList();
    final tokens = (json['mushafTokens'] as List)
        .cast<Map<String, dynamic>>()
        .map(mushafTokenFromJson)
        .toList();

    return QuranDatasetPayload(
      surahs: payload.surahs,
      surahLocalizations: payload.surahLocalizations,
      ayahs: payload.ayahs,
      ayahWords: payload.ayahWords,
      scripts: payload.scripts,
      scriptVariants: payload.scriptVariants,
      mushafs: [mushaf],
      mushafLines: lines,
      mushafTokens: tokens,
      navigationRanges: payload.navigationRanges,
      metadata: payload.metadata,
    );
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

  /// Installs a bundled word-meaning pack (`[ayahId, wordIndex, meaning,
  /// transliteration]` rows) unless the same checksum is installed.
  Future<void> _seedWbw(
    Map<String, dynamic> hashes, {
    required String assetPath,
    required String hashKey,
  }) async {
    final repository = wbwRepository;
    if (repository == null || !hashes.containsKey(hashKey)) return;
    final bytes = await _loadVerified(
      hashes,
      assetPath,
      hashKey,
      resourceLabel: 'Word meanings ($hashKey)',
    );
    if (bytes == null) return;
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final p = json['pack'] as Map<String, dynamic>;
      final pack = WbwLanguagePack(
        id: p['id'] as String,
        languageCode: p['languageCode'] as String,
        displayName: p['displayName'] as String,
        version: p['version'] as int,
        checksum: p['checksum'] as String,
        source: p['source'] as String,
        license: p['license'] as String,
        hasTranslation: p['hasTranslation'] as bool,
        hasTransliteration: p['hasTransliteration'] as bool,
      );
      final existing = await repository.getInstalledPack(pack.id);
      if (existing != null && existing.checksum == pack.checksum) return;
      final words = [
        for (final w in (json['words'] as List).cast<List>())
          WbwWordEntry(
            packId: pack.id,
            ayahId: w[0] as int,
            wordIndex: w[1] as int,
            translation: w[2] as String?,
            transliteration: w[3] as String?,
          ),
      ];
      await repository.installPack(pack, words);
      logger.info(
        'Seeded word meanings "${pack.id}": ${words.length} words.',
        tag: 'BundledDatasetSeeder',
      );
    } catch (e, st) {
      logger.error(
        'Failed to seed word meanings from $assetPath — word meanings will be '
        'unavailable, other resources are unaffected.',
        tag: 'BundledDatasetSeeder',
        error: e,
        stackTrace: st,
      );
    }
  }
}
