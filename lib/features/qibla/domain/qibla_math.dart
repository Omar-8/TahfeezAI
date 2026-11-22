import 'dart:math' as math;

/// The Kaaba's centre (Masjid al-Haram, Makkah), degrees.
const kaabaLatitude = 21.422487;
const kaabaLongitude = 39.826206;

/// Within this many degrees of the qibla, the phone counts as facing it.
const qiblaFacingTolerance = 3.0;

/// The qibla from [latitude], [longitude] (degrees): the direction of the
/// shortest path (great circle) to the Kaaba, in degrees clockwise from
/// true north, 0 ≤ result < 360.
double qiblaBearing(double latitude, double longitude) {
  final phi = _rad(latitude);
  final dLambda = _rad(kaabaLongitude - longitude);
  final phiK = _rad(kaabaLatitude);
  final y = math.sin(dLambda);
  final x = math.cos(phi) * math.tan(phiK) - math.sin(phi) * math.cos(dLambda);
  return normalizeDegrees(_deg(math.atan2(y, x)));
}

/// The distance to the Kaaba along the earth's surface, kilometres
/// (haversine, mean earth radius).
double distanceToKaabaKm(double latitude, double longitude) {
  const earthRadiusKm = 6371.0088;
  final dPhi = _rad(kaabaLatitude - latitude);
  final dLambda = _rad(kaabaLongitude - longitude);
  final a =
      math.pow(math.sin(dPhi / 2), 2) +
      math.cos(_rad(latitude)) *
          math.cos(_rad(kaabaLatitude)) *
          math.pow(math.sin(dLambda / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// [degrees] in 0 ≤ result < 360.
double normalizeDegrees(double degrees) {
  final d = degrees % 360;
  return d < 0 ? d + 360 : d;
}

/// How far to turn from [heading] to face [bearing]: −180 < result ≤ 180,
/// positive clockwise (to the right).
double turnTowards(double heading, double bearing) {
  final d = normalizeDegrees(bearing - heading);
  return d > 180 ? d - 360 : d;
}

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;
