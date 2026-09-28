import 'package:geolocator/geolocator.dart';

/// Outcome of a permission request.
enum PermissionStatus { granted, denied, permanentlyDenied }

/// Platform permission gateway. Kept as an interface so tests and previews can
/// substitute a deterministic implementation.
abstract interface class PermissionService {
  Future<PermissionStatus> requestLocation();
  Future<PermissionStatus> checkLocation();

  /// Opens the OS settings page — the only route back from a permanent denial.
  Future<void> openSettings();
}

class GeolocatorPermissionService implements PermissionService {
  const GeolocatorPermissionService();

  @override
  Future<PermissionStatus> checkLocation() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<PermissionStatus> requestLocation() async {
    var permission = await Geolocator.checkPermission();

    // `deniedForever` must not be re-requested: the OS returns the same answer
    // without showing a dialog, which reads to the user as a frozen button.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _map(permission);
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  static PermissionStatus _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          PermissionStatus.granted,
        LocationPermission.deniedForever => PermissionStatus.permanentlyDenied,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine =>
          PermissionStatus.denied,
      };
}
