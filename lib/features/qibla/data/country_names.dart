import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/gunzip.dart';

/// Country names in each of the app's languages
/// (`tool/quran_data/build_country_names.py`; CLDR, Unicode License v3),
/// for a place shown as "Cairo, Egypt".
const kCountryNamesAsset = 'assets/qibla/country_names.json.gz';

class CountryNames {
  const CountryNames(this._names);

  factory CountryNames.fromJson(Map<String, Object?> json) => CountryNames({
    for (final e in (json['names']! as Map<String, Object?>).entries)
      e.key: (e.value! as Map<String, Object?>).cast<String, String>(),
  });

  final Map<String, Map<String, String>> _names;

  /// [country]'s (ISO 3166) name in [language], else in English, else
  /// `null`.
  String? of(String? country, String language) {
    if (country == null) return null;
    final c = country.toUpperCase();
    return _names[language]?[c] ?? _names['en']?[c];
  }
}

final countryNamesProvider = FutureProvider<CountryNames>((ref) async {
  final data = await rootBundle.load(kCountryNamesAsset);
  final raw = await gunzipText(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  return CountryNames.fromJson(jsonDecode(raw) as Map<String, Object?>);
});
