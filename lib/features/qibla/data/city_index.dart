import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/qibla_place.dart';
import '../../../core/data/gunzip.dart';

/// The bundled city list (`tool/quran_data/build_cities.py`; GeoNames,
/// CC BY 4.0): every city of 50,000 people or more, the largest first —
/// gzipped, unzipped as it is read.
const kCitiesAsset = 'assets/qibla/cities.json.gz';

class _City {
  const _City(this.place, this.keys);

  final QiblaPlace place;

  /// Its names, normalized ([normalizeCityQuery]).
  final List<String> keys;
}

/// Finds cities by name, in Latin or their own script.
class CityIndex {
  CityIndex._(this._cities);

  factory CityIndex.fromJson(Map<String, Object?> json) => CityIndex._([
    for (final row in (json['cities']! as List).cast<List>())
      _City(
        QiblaPlace(
          name: row[0] as String,
          country: row[1] as String,
          latitude: (row[2] as num).toDouble(),
          longitude: (row[3] as num).toDouble(),
        ),
        [
          normalizeCityQuery(row[0] as String),
          for (final other in (row[4] as String).split('|'))
            if (other.isNotEmpty) normalizeCityQuery(other),
        ],
      ),
  ]);

  final List<_City> _cities;

  int get length => _cities.length;

  /// Up to [limit] cities whose name starts with [query] (any of its names;
  /// then those containing it), the largest first in each group.
  List<QiblaPlace> search(String query, {int limit = 40}) {
    final q = normalizeCityQuery(query);
    if (q.isEmpty) return const [];
    final starts = <QiblaPlace>[], contains = <QiblaPlace>[];
    for (final city in _cities) {
      if (city.keys.any((k) => k.startsWith(q))) {
        starts.add(city.place);
        if (starts.length >= limit) break;
      } else if (contains.length < limit &&
          city.keys.any((k) => k.contains(q))) {
        contains.add(city.place);
      }
    }
    return [...starts, ...contains].take(limit).toList();
  }
}

extension CityIndexNearest on CityIndex {
  /// The city nearest [latitude], [longitude] (of 50,000 people or more —
  /// to name a place found by the phone).
  QiblaPlace? nearest(double latitude, double longitude) {
    QiblaPlace? best;
    var bestD = double.infinity;
    final cosLat = math.cos(latitude * math.pi / 180);
    for (final c in _cities) {
      final dy = c.place.latitude - latitude;
      var dx = (c.place.longitude - longitude).abs();
      if (dx > 180) dx = 360 - dx;
      final d = dy * dy + dx * dx * cosLat * cosLat;
      if (d < bestD) {
        bestD = d;
        best = c.place;
      }
    }
    return best;
  }
}

/// [text] for matching: lower case, Latin accents dropped, Arabic vowel
/// marks and tatweel dropped and the alef's forms as one, spaces and
/// hyphens as one space.
String normalizeCityQuery(String text) {
  final lower = text.toLowerCase().trim();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final c = String.fromCharCode(rune);
    if (_arabicMarks.hasMatch(c)) continue;
    out.write(_folded[c] ?? c);
  }
  return out.toString().replaceAll(RegExp(r"[\s\-'’]+"), ' ');
}

final _arabicMarks = RegExp('[ؐ-ًؚ-ٰٟـ]');

const _folded = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'ç': 'c',
  'č': 'c',
  'ć': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ě': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ı': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ō': 'o',
  'ø': 'o',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ṣ': 's',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'ḥ': 'h',
  'ṭ': 't',
  'ḍ': 'd',
  'ẓ': 'z',
  'ğ': 'g',
  'ß': 'ss',
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ى': 'ي',
  'ة': 'ه',
};

CityIndex _parse(String raw) =>
    CityIndex.fromJson(jsonDecode(raw) as Map<String, Object?>);

/// The city list, read the first time it is needed (off the UI thread
/// where there is one).
final cityIndexProvider = FutureProvider<CityIndex>((ref) async {
  final data = await rootBundle.load(kCitiesAsset);
  final raw = await gunzipText(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  return compute(_parse, raw);
});
