import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/domain/model/place.dart';
import 'package:quick_commerce_user/domain/repository/place_repository.dart';
import 'package:quick_commerce_user/platform/location/location_service.dart';
import 'package:quick_commerce_user/platform/permission/permission_service.dart';

class _FakePlaces implements PlaceRepository {
  _FakePlaces(this.place, {this.throws = false});

  final ResolvedPlace? place;
  final bool throws;

  @override
  Future<ResolvedPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (throws) throw Exception('network down');
    return place;
  }

  @override
  Future<List<PlaceSuggestion>> autocomplete(String q, {double? latitude, double? longitude}) async => const [];

  @override
  Future<ResolvedPlace?> details(String placeId) async => null;
}

class _GrantedPermissions implements PermissionService {
  @override
  Future<PermissionStatus> checkLocation() async => PermissionStatus.granted;
  @override
  Future<PermissionStatus> requestLocation() async => PermissionStatus.granted;
  @override
  Future<void> openSettings() async {}
}

void main() {
  test('every address component Google returns reaches the form', () async {
    final service = GeolocatorLocationService(
      _GrantedPermissions(),
      _FakePlaces(
        const ResolvedPlace(
          latitude: 22.72,
          longitude: 75.86,
          formattedAddress: '12 Curewell Hospital Rd, Indore, MP 452001, India',
          streetLine: '12 Curewell Hospital Rd',
          subLocality: 'New Palasia',
          city: 'Indore',
          state: 'Madhya Pradesh',
          postalCode: '452001',
          country: 'India',
        ),
      ),
    );

    final location = await service.resolve(22.72, 75.86);

    expect(location.isResolved, isTrue);
    expect(location.streetLine, '12 Curewell Hospital Rd');
    expect(location.subLocality, 'New Palasia');
    expect(location.city, 'Indore');
    expect(location.state, 'Madhya Pradesh');
    expect(location.pincode, '452001');
    expect(location.country, 'India');
  });

  test('a geocoding failure still yields a usable pin', () async {
    final service = GeolocatorLocationService(
      _GrantedPermissions(),
      _FakePlaces(null, throws: true),
    );

    final location = await service.resolve(22.72, 75.86);

    expect(location.latitude, 22.72);
    expect(location.isResolved, isFalse); // form stays empty and editable
    expect(location.city, '');
  });
}
