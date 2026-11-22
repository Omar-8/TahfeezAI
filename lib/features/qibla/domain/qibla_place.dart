import 'dart:convert';

/// Where the qibla is worked out from: the phone's own position (no name),
/// or a city chosen by hand.
class QiblaPlace {
  const QiblaPlace({
    required this.latitude,
    required this.longitude,
    this.name,
    this.country,
  });

  final double latitude, longitude;

  /// A chosen city's name, `null` for the phone's own position.
  final String? name;

  /// Its country's ISO 3166 code ("EG"), when a city.
  final String? country;

  bool get isCity => name != null;

  /// The country's flag (its two regional-indicator letters), "" if none.
  String get flag {
    final c = country;
    if (c == null || c.length != 2) return '';
    return String.fromCharCodes([
      for (final unit in c.toUpperCase().codeUnits) 0x1F1E6 + unit - 0x41,
    ]);
  }

  String encode() => jsonEncode({
    'lat': latitude,
    'lon': longitude,
    'name': ?name,
    'country': ?country,
  });

  static QiblaPlace? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      return QiblaPlace(
        latitude: (m['lat']! as num).toDouble(),
        longitude: (m['lon']! as num).toDouble(),
        name: m['name'] as String?,
        country: m['country'] as String?,
      );
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is QiblaPlace &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.name == name &&
      other.country == country;

  @override
  int get hashCode => Object.hash(latitude, longitude, name, country);
}
