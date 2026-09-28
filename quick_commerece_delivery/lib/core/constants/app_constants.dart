import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({required this.name, required this.lang, this.flag});
}

/// Central App Constants for Quick Commerce Delivery Application.
class AppConstants {
  const AppConstants._();

  static const String title = '6amfresh Delivery';
  static const String appName = '6amfresh Delivery';

  /// Merchant / consumer-facing brand.
  static const String brandName = '6amfresh';

  /// Second line of the stacked wordmark on the referral ticket.
  static const String brandSuffix = 'Delivery';

  /// Public logo URL for checkout/branding sheets.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');

  static const String appVersion = '1.0.0';
  static const String appFontFamily = 'Latin';

  /// Backend REST API host domain.
  ///
  /// Central origin (`https://6amfresh.in`). One host serves every module —
  /// `/api/v1/food/*`, `/api/v1/taxi/*`, `/api/v1/qc/*` and `/api/v1/sp/*` — plus
  /// the Socket.IO endpoint.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://6amfresh.in',
  );

  /// Backend origin override via environment variable.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Backend origin. API_BASE_URL is the common cross-app override; hostUrl (API_HOST)
  /// is used as default.
  static String get apiHost {
    final raw = _apiBaseUrlOverride.trim();
    if (raw.isNotEmpty) {
      final uri = Uri.tryParse(raw);
      if (uri != null && uri.hasAuthority) {
        return Uri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
        ).toString().replaceFirst(RegExp(r'/$'), '');
      }
    }
    return hostUrl.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static String get baseUrl {
    final raw = _apiBaseUrlOverride.trim();
    if (raw.isNotEmpty) return raw.replaceFirst(RegExp(r'/+$'), '');
    return '$apiHost/api/v1';
  }

  static bool get hasValidApiBaseUrl =>
      Uri.tryParse(baseUrl)?.path.replaceAll(RegExp(r'/+$'), '') == '/api/v1';

  /// Socket.IO server URL.
  static String get socketUrl =>
      String.fromEnvironment('SOCKET_URL', defaultValue: apiHost);

  /// Turns a backend-relative upload path (`/uploads/...`) into a full URL,
  /// leaving absolute and data URLs untouched.
  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  /// Google Maps key used for map preview & services.
  static const String mapKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak',
  );

  /// Firebase project configuration.
  static String firebaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyBX7EIxRbikqf6jGiVArNGZxk8i1kmQCzg"
      : "ios firebase api key";

  static String get firbaseApiKey => firebaseApiKey;

  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:288841633330:android:8c09ad2a862de03b8bf62b"
      : "ios firebase app id";

  static String firebaseMessagingSenderId = (kIsWeb || Platform.isAndroid)
      ? "288841633330"
      : "ios firebase sender id";

  static String get firebasemessagingSenderId => firebaseMessagingSenderId;

  static String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "amfresh-addee"
      : "ios firebase project id";

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.sixamfresh.delivery';
  static String signKey = '';

  /// Fallback FirebaseOptions for manual initialization
  static FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: firebaseApiKey,
    appId: firebaseAppId,
    messagingSenderId: firebaseMessagingSenderId,
    projectId: firebaseProjectId,
  );
}
