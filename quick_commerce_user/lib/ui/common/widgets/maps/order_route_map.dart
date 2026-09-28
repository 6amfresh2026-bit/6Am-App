import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/polyline_codec.dart';
import '../../../../domain/model/order.dart';

/// Live tracking map: the store, the destination, the rider, and the route
/// between them.
///
/// The polyline comes from the backend's `GET /orders/:id/route`, so the drawn
/// path is the real routed one, not a straight line.
class OrderRouteMap extends StatefulWidget {
  const OrderRouteMap({
    super.key,
    required this.route,
    this.riderLocation,
    this.height = 220,
  });

  final OrderRoute route;
  final GeoPoint? riderLocation;
  final double height;

  @override
  State<OrderRouteMap> createState() => _OrderRouteMapState();
}

class _OrderRouteMapState extends State<OrderRouteMap> {
  GoogleMapController? _controller;

  List<LatLng> get _path => PolylineCodec.decode(widget.route.polyline)
      .map((p) => LatLng(p.$1, p.$2))
      .toList();

  /// Every point the camera should keep in view.
  List<LatLng> get _framed {
    final points = <LatLng>[
      ..._path,
      if (widget.route.origin != null)
        LatLng(widget.route.origin!.latitude, widget.route.origin!.longitude),
      if (widget.route.destination != null)
        LatLng(
          widget.route.destination!.latitude,
          widget.route.destination!.longitude,
        ),
      if (widget.riderLocation != null)
        LatLng(widget.riderLocation!.latitude, widget.riderLocation!.longitude),
    ];
    return points;
  }

  /// The camera is framed exactly once, when the map is first ready. After that
  /// the user owns the zoom and position: a live rider/route/polyline update
  /// moves the markers and line but must never re-frame or reset the camera.
  bool _didFit = false;

  @override
  void didUpdateWidget(OrderRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the route only just arrived (map created with nothing to frame), fit
    // once now — but never again, and never on a rider move.
    if (!_didFit && _framed.isNotEmpty && _controller != null) {
      _fitBounds();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _framed;
    if (points.isEmpty) {
      return _RouteUnavailable(height: widget.height);
    }

    return ClipRRect(
      borderRadius: AppRadii.rLg,
      child: SizedBox(
        height: widget.height,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: points.first, zoom: 13),
          onMapCreated: (controller) {
            _controller = controller;
            _fitBounds();
          },
          liteModeEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          markers: _markers(),
          polylines: {
            if (_path.length > 1)
              Polyline(
                polylineId: const PolylineId('route'),
                points: _path,
                width: 5,
                color: context.colors.primary,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
          },
        ),
      ),
    );
  }

  Set<Marker> _markers() {
    final origin = widget.route.origin;
    final destination = widget.route.destination;
    final rider = widget.riderLocation;

    return {
      if (origin != null)
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(origin.latitude, origin.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Store'),
        ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Delivery address'),
        ),
      if (rider != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(rider.latitude, rider.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Your rider'),
          zIndexInt: 2,
        ),
    };
  }

  Future<void> _fitBounds() async {
    final controller = _controller;
    final points = _framed;
    if (controller == null || points.isEmpty) return;

    // One-and-done: after the first frame the user's zoom/position is sacred.
    _didFit = true;

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 15),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      ),
      northeast: LatLng(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      ),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }
}

/// Shown before dispatch, when there is no route to draw yet.
class _RouteUnavailable extends StatelessWidget {
  const _RouteUnavailable({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.semantic.surfaceAlt,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: context.semantic.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_rounded,
              size: 30,
              color: context.semantic.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'The live route appears once a rider is assigned',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
