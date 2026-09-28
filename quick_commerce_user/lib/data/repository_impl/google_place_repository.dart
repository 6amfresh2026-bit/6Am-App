import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';
import '../../domain/model/place.dart';
import '../../domain/repository/place_repository.dart';
import '../dto/json_reader.dart';

/// Google Places + Geocoding over REST.
///
/// Deliberately uses its own [Dio] rather than the app's `ApiClient`: that
/// client is bound to the Suvio backend's base URL, auth header and
/// `{success, message, data}` envelope, none of which apply to Google.
///
/// The key comes from [AppConfig], which reads it from `config/keys.env` — the
/// same file the Android manifest and iOS xcconfig read.
class GooglePlaceRepository implements PlaceRepository {
  GooglePlaceRepository(this._config)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://maps.googleapis.com/maps/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            validateStatus: (_) => true,
          ),
        );

  final AppConfig _config;
  final Dio _dio;

  /// Logged once, not per call — a missing key fails on every keystroke.
  bool _warnedAboutKey = false;

  /// True when the Dart-side key is present. The map widget does not need it
  /// (the SDK reads a native key from the manifest / Info.plist), so a build
  /// without `--dart-define-from-file=config/keys.env` draws a perfectly good
  /// map while every Places and Geocoding call here returns nothing.
  bool get _hasKey {
    if (_config.hasMapsKey) return true;
    if (!_warnedAboutKey) {
      _warnedAboutKey = true;
      AppLogger.error(
        'MAPS_API_KEY is empty on the Dart side — Places search and reverse '
        'geocoding are disabled. Run with '
        '--dart-define-from-file=config/keys.env.',
      );
    }
    return false;
  }

  /// Keeps autocomplete requests for one editing session on a single billing
  /// session token, which is materially cheaper than billing each keystroke.
  String? _sessionToken;

  void startSession(String token) => _sessionToken = token;
  void endSession() => _sessionToken = null;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    if (!_hasKey || query.trim().length < 3) return const [];

    final json = await _get('/place/autocomplete/json', {
      'input': query.trim(),
      'key': _config.mapsApiKey,
      'components': 'country:in',
      if (_sessionToken != null) 'sessiontoken': _sessionToken,
      if (latitude != null && longitude != null) ...{
        'location': '$latitude,$longitude',
        'radius': '30000',
      },
    });
    if (json == null) return const [];

    return json.objects('predictions').map((p) {
      final formatting = p.mapAt('structured_formatting');
      return PlaceSuggestion(
        placeId: p.str('place_id'),
        primaryText: formatting.str('main_text', p.str('description')),
        secondaryText: formatting.str('secondary_text'),
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  @override
  Future<ResolvedPlace?> details(String placeId) async {
    if (!_hasKey || placeId.isEmpty) return null;

    final json = await _get('/place/details/json', {
      'place_id': placeId,
      'key': _config.mapsApiKey,
      'fields': 'geometry,formatted_address,address_component,name',
      if (_sessionToken != null) 'sessiontoken': _sessionToken,
    });
    if (json == null) return null;

    // The session ends with the details call — that is what Google bills as one
    // unit. Holding the token open past it would be charged per request.
    endSession();

    final result = json.mapOrNull('result');
    return result == null ? null : _toPlace(result);
  }

  @override
  Future<ResolvedPlace?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!_hasKey) return null;

    final json = await _get('/geocode/json', {
      'latlng': '$latitude,$longitude',
      'key': _config.mapsApiKey,
    });
    if (json == null) return null;

    final results = json.objects('results');
    if (results.isEmpty) return null;

    // Results run most-specific first, which is the one worth showing.
    return _toPlace(results.first, fallbackLat: latitude, fallbackLng: longitude);
  }

  Future<Map<String, dynamic>?> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final status = data.str('status');
      if (status == 'OK' || status == 'ZERO_RESULTS') return data;

      // REQUEST_DENIED almost always means the API is not enabled on the key or
      // billing is off — worth naming, because the symptom is a silent empty list.
      AppLogger.error(
        'Google $path failed: $status ${data.str('error_message')}',
      );
      return null;
    } on DioException catch (e) {
      AppLogger.error('Google $path unreachable', error: e);
      return null;
    }
  }

  ResolvedPlace _toPlace(
    Map<String, dynamic> json, {
    double? fallbackLat,
    double? fallbackLng,
  }) {
    final location = json.mapAt('geometry').mapAt('location');
    final components = json.objects('address_components');

    String component(String type) {
      for (final c in components) {
        if (c.strings('types').contains(type)) return c.str('long_name');
      }
      return '';
    }

    final streetNumber = component('street_number');
    final route = component('route');

    return ResolvedPlace(
      latitude: location.doubleOrNull('lat') ?? fallbackLat ?? 0,
      longitude: location.doubleOrNull('lng') ?? fallbackLng ?? 0,
      formattedAddress: json.str('formatted_address'),
      name: json.str('name'),
      subLocality: component('sublocality_level_1').isNotEmpty
          ? component('sublocality_level_1')
          : component('sublocality'),
      locality: component('locality'),
      city: component('locality').isNotEmpty
          ? component('locality')
          : component('administrative_area_level_2'),
      state: component('administrative_area_level_1'),
      postalCode: component('postal_code'),
      streetLine: [streetNumber, route].where((p) => p.isNotEmpty).join(' '),
      country: component('country'),
    );
  }
}
