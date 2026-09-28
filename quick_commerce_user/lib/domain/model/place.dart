/// A place the user picked or that geocoding resolved.
class ResolvedPlace {
  const ResolvedPlace({
    required this.latitude,
    required this.longitude,
    this.formattedAddress = '',
    this.name = '',
    this.subLocality = '',
    this.locality = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.streetLine = '',
    this.country = '',
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String name;
  final String subLocality;
  final String locality;
  final String city;
  final String state;
  final String postalCode;

  /// House/street portion, pre-filled into the address form's first field.
  final String streetLine;

  final String country;

  /// Shortest meaningful label for the home header.
  String get shortLabel {
    for (final candidate in [name, subLocality, locality, city]) {
      if (candidate.trim().isNotEmpty) return candidate.trim();
    }
    return formattedAddress.split(',').first.trim();
  }
}

/// One row in the autocomplete list. Coordinates are not included — Places
/// returns them only on the follow-up details call, which is why picking a
/// suggestion costs a second request.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    this.secondaryText = '',
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  String get fullText =>
      secondaryText.isEmpty ? primaryText : '$primaryText, $secondaryText';
}
