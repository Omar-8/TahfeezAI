/// Pure conversions between Drift row types (`wbw_database.g.dart`) and the
/// Flutter/Drift-independent domain models in `lib/wbw/domain/models/`,
/// mirroring `lib/quran/data/quran_mappers.dart`'s convention.
library;

import 'package:drift/drift.dart';

import '../domain/models/wbw_models.dart';
import 'wbw_database.dart';

extension WbwPackRowMapper on WbwPackRow {
  WbwLanguagePack toDomain() => WbwLanguagePack(
    id: id,
    languageCode: languageCode,
    displayName: displayName,
    version: version,
    checksum: checksum,
    source: source,
    license: license,
    hasTranslation: hasTranslation,
    hasTransliteration: hasTransliteration,
  );
}

extension WbwPackDomainMapper on WbwLanguagePack {
  WbwPacksCompanion toCompanion() => WbwPacksCompanion.insert(
    id: id,
    languageCode: languageCode,
    displayName: displayName,
    version: version,
    checksum: checksum,
    source: source,
    license: license,
    hasTranslation: hasTranslation,
    hasTransliteration: hasTransliteration,
  );
}

extension WbwWordRowMapper on WbwWordRow {
  WbwWordEntry toDomain() => WbwWordEntry(
    packId: packId,
    ayahId: ayahId,
    wordIndex: wordIndex,
    translation: translation,
    transliteration: transliteration,
  );
}

extension WbwWordEntryDomainMapper on WbwWordEntry {
  WbwWordsCompanion toCompanion() => WbwWordsCompanion.insert(
    packId: packId,
    ayahId: ayahId,
    wordIndex: wordIndex,
    translation: Value(translation),
    transliteration: Value(transliteration),
  );
}
