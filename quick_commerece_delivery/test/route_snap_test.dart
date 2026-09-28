import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/core/utils/route_snap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The projection that keeps the rider marker on the drawn route.
///
/// Worth testing rather than eyeballing: a sign error or an unclamped
/// projection puts the bike confidently in the wrong place, which is the exact
/// failure this code exists to fix.
void main() {
  // A short east-west leg then a north leg, in Indore. Real-ish coordinates so
  // the cos(latitude) scaling is actually exercised.
  const corner = LatLng(22.7282, 75.8845);
  final route = <LatLng>[
    const LatLng(22.7282, 75.8835),
    corner,
    const LatLng(22.7292, 75.8845),
  ];

  test('a fix beside the route snaps onto it', () {
    // ~11m north of the first (east-west) leg.
    final snapped = snapToRoute(route, const LatLng(22.7283, 75.8840))!;

    expect(snapped.segmentIndex, 0);
    expect(snapped.point.latitude, closeTo(22.7282, 1e-6));
    expect(snapped.point.longitude, closeTo(75.8840, 1e-5));
    expect(snapped.metresFromRoute, closeTo(11, 2));
  });

  test('the bearing comes from the road, not the fix', () {
    // Due east along the first leg…
    expect(snapToRoute(route, const LatLng(22.7283, 75.8840))!.bearing,
        closeTo(90, 1));
    // …and due north once past the corner.
    expect(snapToRoute(route, const LatLng(22.7288, 75.8846))!.bearing,
        closeTo(0, 1));
  });

  test('a fix beyond the end clamps to the endpoint, never past it', () {
    // Well north of the route's final point. Without clamping the projection
    // would run off the end of the segment and place the rider somewhere the
    // road does not go.
    final snapped = snapToRoute(route, const LatLng(22.7350, 75.8845))!;
    expect(snapped.point.latitude, closeTo(22.7292, 1e-6));
    expect(snapped.point.longitude, closeTo(75.8845, 1e-6));
  });

  test('the nearest segment wins, not the first one', () {
    final snapped = snapToRoute(route, const LatLng(22.7291, 75.8846))!;
    expect(snapped.segmentIndex, 1);
  });

  test('a route with nothing to project onto returns null', () {
    expect(snapToRoute(const [], corner), isNull);
    expect(snapToRoute(const [corner], corner), isNull);
  });

  test('duplicate points do not divide by zero', () {
    final degenerate = [corner, corner, const LatLng(22.7292, 75.8845)];
    expect(() => snapToRoute(degenerate, const LatLng(22.7285, 75.8846)),
        returnsNormally);
  });

  test('bearing interpolation takes the short way across north', () {
    // 350° → 10° is a 20° right turn, not a 340° left one.
    expect(lerpBearing(350, 10, 0.5) % 360, closeTo(0, 0.001));
  });

  test('distance matches a known separation', () {
    // 0.001° of latitude is ~111m anywhere on Earth.
    expect(
      metresBetween(const LatLng(22.7282, 75.8845), const LatLng(22.7292, 75.8845)),
      closeTo(111, 2),
    );
  });
}
