import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Where the rider actually is, expressed in terms of the drawn route.
class SnappedPosition {
  const SnappedPosition({
    required this.point,
    required this.bearing,
    required this.metresFromRoute,
    required this.segmentIndex,
  });

  /// The point ON the polyline nearest the raw fix.
  final LatLng point;

  /// Direction of travel along that segment, degrees clockwise from north.
  /// Taken from the road, not from the GPS heading, so the marker points the
  /// way the road goes instead of wobbling with every fix.
  final double bearing;

  /// How far the raw fix was from the route. The caller decides what is too
  /// far to be believable.
  final double metresFromRoute;

  final int segmentIndex;
}

const double _earthRadiusMetres = 6378137;

/// Projects [raw] onto the nearest segment of [route].
///
/// Returns null for a route with fewer than two points — there is nothing to
/// project onto, and the caller should keep using the raw fix.
///
/// The projection is planar, not spherical: over the tens of metres that
/// separate a GPS fix from its road, the curvature error is far below the
/// accuracy of the fix itself. Longitude is scaled by cos(latitude) so the
/// planar approximation stays true away from the equator.
SnappedPosition? snapToRoute(List<LatLng> route, LatLng raw) {
  if (route.length < 2) return null;

  final latScale = math.cos(raw.latitude * math.pi / 180);
  double toX(double lng) => lng * latScale;

  var bestDistanceSq = double.infinity;
  var bestIndex = 0;
  var bestT = 0.0;

  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];

    final ax = toX(a.longitude), ay = a.latitude;
    final bx = toX(b.longitude), by = b.latitude;
    final px = toX(raw.longitude), py = raw.latitude;

    final dx = bx - ax, dy = by - ay;
    final lengthSq = dx * dx + dy * dy;

    // A zero-length segment (duplicate points, which encoded polylines do
    // contain) would divide by zero; its start point is the answer.
    final t = lengthSq == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / lengthSq).clamp(0.0, 1.0);

    final cx = ax + dx * t, cy = ay + dy * t;
    final distanceSq = (px - cx) * (px - cx) + (py - cy) * (py - cy);

    if (distanceSq < bestDistanceSq) {
      bestDistanceSq = distanceSq;
      bestIndex = i;
      bestT = t;
    }
  }

  final a = route[bestIndex];
  final b = route[bestIndex + 1];
  final point = LatLng(
    a.latitude + (b.latitude - a.latitude) * bestT,
    a.longitude + (b.longitude - a.longitude) * bestT,
  );

  return SnappedPosition(
    point: point,
    bearing: bearingBetween(a, b),
    metresFromRoute: metresBetween(raw, point),
    segmentIndex: bestIndex,
  );
}

/// Great-circle distance in metres. Small enough inputs that the haversine's
/// numerical edge cases never arise.
double metresBetween(LatLng a, LatLng b) {
  const toRad = math.pi / 180;
  final dLat = (b.latitude - a.latitude) * toRad;
  final dLng = (b.longitude - a.longitude) * toRad;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * toRad) *
          math.cos(b.latitude * toRad) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * _earthRadiusMetres * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// Initial bearing from [a] to [b], normalised to 0–360.
double bearingBetween(LatLng a, LatLng b) {
  const toRad = math.pi / 180;
  final lat1 = a.latitude * toRad, lat2 = b.latitude * toRad;
  final dLng = (b.longitude - a.longitude) * toRad;
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final degrees = math.atan2(y, x) * 180 / math.pi;
  return (degrees + 360) % 360;
}

/// Interpolates between two points for marker animation. Linear is right here:
/// the two points are metres apart and a great-circle path between them is
/// indistinguishable from a straight one.
LatLng lerpLatLng(LatLng from, LatLng to, double t) => LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );

/// Interpolates a bearing the short way round, so a marker crossing north
/// turns 10° rather than spinning 350° the other way.
double lerpBearing(double from, double to, double t) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return (from + delta * t) % 360;
}
