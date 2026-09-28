import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../constants/app_constants.dart';

/// Build-time configuration — the single source of truth for hosts and keys on
/// the Dart side.
///
/// Values come from `config/keys.env`, which also feeds the Android manifest
/// placeholder and the iOS xcconfig, so a key is written down exactly once.
/// That file is bundled as an asset and read by [load] at startup, so no launch
/// flag is required:
///
///   flutter run
///
/// A `--dart-define` still wins over the file, which is how CI and release
/// pipelines inject keys they do not keep on disk:
///
///   flutter build apk --dart-define=MAPS_API_KEY=…
///
/// Individual `--dart-define`s still override it for one-off runs.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.mapsApiKey,
    required this.environment,
    required this.enableNetworkLogs,
  });

  final String apiBaseUrl;

  /// Used by the Dart-side Google REST calls (Places autocomplete, place
  /// details, reverse geocoding). The native map SDKs read the same key from
  /// the manifest / Info.plist instead — they are configured before Dart runs.
  final String mapsApiKey;

  final String environment;
  final bool enableNetworkLogs;

  bool get isProduction => environment == 'production';

  /// False when the key is absent or still the template placeholder. Map
  /// features check this and degrade with an explanation rather than showing a
  /// blank grey tile.
  bool get hasMapsKey =>
      mapsApiKey.isNotEmpty && mapsApiKey != _mapsKeyPlaceholder;

  /// The shared hosted backend. Per `FLUTTER_API_SPEC.md` the base is
  /// `{HOST}/api/v1` and every route is written as `/food/...` on top of it —
  /// so the `/v1` segment belongs here, not in the paths.
  static String get _defaultBaseUrl => AppConstants.baseUrl;

  /// Kept in sync with `config/keys.example.env`.
  static const _mapsKeyPlaceholder = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  /// Reads `config/keys.env`, which is bundled as an asset, and lets any
  /// `--dart-define` win over it.
  ///
  /// The dart-define path alone proved too easy to lose: run the app from an
  /// IDE button that does not pass `--dart-define-from-file` and the key is
  /// silently empty, which shows up much later as "address lookup is not
  /// configured". The Android build already reads this same file at
  /// manifest-merge time; this makes the Dart side read it too, so one file
  /// configures everything however the app is launched.
  static Future<AppConfig> load() async {
    Map<String, String> fileValues = const {};
    try {
      final raw = await rootBundle.loadString('config/keys.env');
      fileValues = {
        for (final line in const LineSplitter().convert(raw))
          if (!line.trimLeft().startsWith('#') && line.contains('='))
            line.substring(0, line.indexOf('=')).trim():
                line.substring(line.indexOf('=') + 1).trim(),
      };
    } catch (_) {
      // No keys.env in this build — dart-defines are the only source.
    }

    return AppConfig.fromEnvironment(fallbacks: fileValues);
  }

  factory AppConfig.fromEnvironment({Map<String, String> fallbacks = const {}}) {
    const urlDefine = String.fromEnvironment('API_BASE_URL');
    const envDefine = String.fromEnvironment('APP_ENV');
    const mapsDefine = String.fromEnvironment('MAPS_API_KEY');

    final url = urlDefine.isNotEmpty
        ? urlDefine
        : (fallbacks['API_BASE_URL']?.isNotEmpty ?? false)
            ? fallbacks['API_BASE_URL']!
            : _defaultBaseUrl;
    final env = envDefine.isNotEmpty
        ? envDefine
        : fallbacks['APP_ENV'] ?? 'development';
    final mapsKey = mapsDefine.isNotEmpty
        ? mapsDefine
        : (fallbacks['MAPS_API_KEY']?.isNotEmpty ?? false)
            ? fallbacks['MAPS_API_KEY']!
            : AppConstants.mapKey;
    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    // A base URL missing the version segment 404s every single call, and does
    // it silently at runtime. Fail loudly in debug instead.
    assert(
      base.endsWith('/api/v1'),
      'API_BASE_URL must end with /api/v1 (got "$base"). '
      'Route paths are written as /food/... on top of it.',
    );

    return AppConfig(
      apiBaseUrl: base,
      mapsApiKey: mapsKey,
      environment: env,
      enableNetworkLogs: env != 'production',
    );
  }
}
