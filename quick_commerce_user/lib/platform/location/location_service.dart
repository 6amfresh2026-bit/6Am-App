import 'package:geolocator/geolocator.dart';

import '../../domain/repository/place_repository.dart';
import '../permission/permission_service.dart';

/// A resolved device location, with whatever address detail geocoding returned.
class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.label = '',
    this.formattedAddress = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.streetLine = '',
    this.subLocality = '',
    this.country = '',
  });

  final double latitude;
  final double longitude;

  /// Neighbourhood / sub-locality, used as the short header line.
  final String label;
  final String formattedAddress;
  final String city;
  final String state;
  final String pincode;

  /// House number + road, when Google has one for this point.
  final String streetLine;

  /// Neighbourhood, offered as the landmark line.
  final String subLocality;
  final String country;

  /// False when the point could not be reverse-geocoded — the pin is still
  /// usable, but the form fields have to be typed by hand.
  bool get isResolved => formattedAddress.isNotEmpty;
}

class LocationPermissionDenied implements Exception {
  const LocationPermissionDenied({this.isPermanent = false});

  final bool isPermanent;

  @override
  String toString() => isPermanent
      ? 'Location access is turned off for Suvio Quick.'
      : 'Location permission was not granted.';
}

class LocationUnavailable implements Exception {
  const LocationUnavailable([this.message = 'Could not get your location.']);

  final String message;

  @override
  String toString() => message;
}

/// Device location, resolved to a postal address via the Geocoding API.
abstract interface class LocationService {
  Future<DeviceLocation> currentLocation();

  /// Reverse-geocodes an arbitrary point — used when the user drags the map pin.
  Future<DeviceLocation> resolve(double latitude, double longitude);
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService(this._permissions, this._places);

  final PermissionService _permissions;
  final PlaceRepository _places;

  /// Fallback centre when the device has no fix yet: Indore, which is where the
  /// backend's demo data is seeded.
  static const _fallback = DeviceLocation(
    latitude: 22.7196,
    longitude: 75.8577,
    label: 'Indore',
    city: 'Indore',
    state: 'Madhya Pradesh',
  );

  static const fallbackCentre = _fallback;

  @override
  Future<DeviceLocation> currentLocation() async {
    final status = await _permissions.requestLocation();
    if (status != PermissionStatus.granted) {
      throw LocationPermissionDenied(
        isPermanent: status == PermissionStatus.permanentlyDenied,
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable(
        'Location services are switched off on this device.',
      );
    }

    try {
      // A last-known fix returns instantly and is usually good enough to centre
      // the map while the precise one arrives.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return resolve(position.latitude, position.longitude);
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        throw const LocationUnavailable(
          'We could not get a location fix. Try again outdoors, or enter the '
          'address manually.',
        );
      }
      return resolve(last.latitude, last.longitude);
    }
  }

  @override
  Future<DeviceLocation> resolve(double latitude, double longitude) async {
    try {
      final place = await _places.reverseGeocode(
        latitude: latitude,
        longitude: longitude,
      );
      if (place == null) {
        return DeviceLocation(latitude: latitude, longitude: longitude);
      }
      return DeviceLocation(
        latitude: latitude,
        longitude: longitude,
        label: place.shortLabel,
        formattedAddress: place.formattedAddress,
        city: place.city,
        state: place.state,
        pincode: place.postalCode,
        streetLine: place.streetLine,
        subLocality: place.subLocality,
        country: place.country,
      );
    } on Exception {
      // Geocoding is an enhancement: a failure must still leave the user with a
      // usable pin they can label by hand.
      return DeviceLocation(latitude: latitude, longitude: longitude);
    }
  }
}
