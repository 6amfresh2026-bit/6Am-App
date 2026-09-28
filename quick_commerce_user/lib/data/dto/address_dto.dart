import 'json_reader.dart';

/// A saved address subdocument. The backend adds `latitude`/`longitude` when
/// the point parses, and omits them entirely when it does not.
class AddressDto {
  const AddressDto({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.state,
    this.additionalDetails = '',
    this.zipCode = '',
    this.phone = '',
    this.flatNumber = '',
    this.blockNumber = '',
    this.colonyName = '',
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String state;
  final String additionalDetails;
  final String zipCode;
  final String phone;
  final String flatNumber;
  final String blockNumber;
  final String colonyName;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  factory AddressDto.fromJson(Map<String, dynamic> json) {
    var lat = json.doubleOrNull('latitude') ?? json.doubleOrNull('lat');
    var lng = json.doubleOrNull('longitude') ?? json.doubleOrNull('lng');

    // Fall back to the GeoJSON point, which is always [lng, lat].
    if (lat == null || lng == null) {
      final coords = json.mapAt('location')['coordinates'];
      if (coords is List && coords.length >= 2) {
        lng ??= (coords[0] as num?)?.toDouble();
        lat ??= (coords[1] as num?)?.toDouble();
      }
    }

    return AddressDto(
      id: json.id(),
      label: json.str('label', 'Other'),
      street: json.str('street'),
      city: json.str('city'),
      state: json.str('state'),
      additionalDetails: json.str('additionalDetails'),
      zipCode: json.str('zipCode'),
      phone: json.str('phone'),
      flatNumber: json.str('flatNumber'),
      blockNumber: json.str('blockNumber'),
      colonyName: json.str('colonyName'),
      latitude: lat,
      longitude: lng,
      isDefault: json.boolean('isDefault'),
    );
  }
}
