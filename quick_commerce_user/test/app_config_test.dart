import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/config/app_config.dart';

void main() {
  test('keys.env values are used when no dart-define is present', () {
    final config = AppConfig.fromEnvironment(fallbacks: const {
      'MAPS_API_KEY': 'AIzaSyTest',
      'API_BASE_URL': 'https://staging.example.com/api/v1/',
      'APP_ENV': 'production',
    });

    expect(config.mapsApiKey, 'AIzaSyTest');
    expect(config.hasMapsKey, isTrue);
    // Trailing slash trimmed, so paths never double up.
    expect(config.apiBaseUrl, 'https://staging.example.com/api/v1');
    expect(config.isProduction, isTrue);
    expect(config.enableNetworkLogs, isFalse);
  });

  test('an empty or placeholder key still reads as unconfigured', () {
    expect(AppConfig.fromEnvironment().hasMapsKey, isFalse);
    expect(
      AppConfig.fromEnvironment(
        fallbacks: const {'MAPS_API_KEY': 'YOUR_GOOGLE_MAPS_API_KEY_HERE'},
      ).hasMapsKey,
      isFalse,
    );
  });
}
