import '../model/place.dart';

/// Google Places and Geocoding, behind an interface so the UI and domain never
/// see an HTTP call or an API key.
abstract interface class PlaceRepository {
  /// Autocomplete for the address search field. [origin] biases results toward
  /// the map's current centre, which matters a lot for short queries.
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? latitude,
    double? longitude,
  });

  /// Resolves a suggestion into coordinates and address components.
  Future<ResolvedPlace?> details(String placeId);

  /// Turns a dropped map pin into a postal address.
  Future<ResolvedPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}
