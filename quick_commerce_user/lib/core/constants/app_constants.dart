import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({required this.name, required this.lang, this.flag});
}

/// Central App Constants for Quickdrop User Application.
class AppConstants {
  const AppConstants._();

  static const String title = '6amfresh';
  static const String appName = '6amfresh';

  /// Merchant name shown on the Razorpay checkout sheet.
  ///
  /// Without this Razorpay falls back to the legal entity registered on the
  /// account ("SWITCHEATS PRIVATE LIMITED"), which is not our consumer brand.
  static const String brandName = 'Food+taxi';

  /// Public logo URL for the Razorpay sheet. Razorpay fetches this over the
  /// network, so a bundled asset cannot be used — it must be a hosted URL.
  /// Falls back to the backend's configured business logo when set.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');
  static const String appVersion = '1.0.0';

  /// Backend REST API host domain.
  ///
  /// The merged master deployment (`/opt/master`, pm2 `master-api`, port 5007)
  /// behind nginx. One host serves every module — `/api/v1/food/*`,
  /// `/api/v1/taxi/*`, `/api/v1/qc/*` and `/api/v1/sp/*` — plus the Socket.IO
  /// endpoint, so there is exactly one origin to change when the environment
  /// moves.
  ///
  /// This is `200.141.12.68`. The previous default, `superapp.appzeto.com`,
  /// resolves to a DIFFERENT machine (145.223.21.188) running its own copy of
  /// the same build — so the two are not interchangeable: sockets, dispatch and
  /// push all have to land on the one host the other apps are pointed at. The
  /// delivery and restaurant apps must move with this value, not after it.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://6amfresh.in',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$hostUrl/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: hostUrl,
  );

  /// Firebase project configuration for the super app (com.quickdrop.user).
  ///
  /// Project `k9rides-529a8` — the same project the k9 backend authenticates
  /// as (`firebase-adminsdk-fbsvc@k9rides-529a8.iam.gserviceaccount.com`).
  /// These values must stay in sync with `android/app/google-services.json`;
  /// they are only used as a fallback when the default `Firebase.initializeApp()`
  /// fails to read the platform config (see `ensureFirebaseInitialized`).
  ///
  /// iOS is not configured yet — there is no GoogleService-Info.plist for this
  /// project, so iOS builds will fall through to the failure branch.
  // Values below are for `superapp-db039` (client `com.quickdrop.user`), taken from
  // android/app/google-services.json. They previously named `k9rides-529a8`
  // (sender 857854567102), which no longer matches the shipped config file or
  // the project the master backend sends through — so on any device that fell
  // through to this branch, FCM registered against a project the backend cannot
  // push from.
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

  /// Regional RTDB instance — note this is NOT the default `.firebaseio.com`
  /// domain, so it must always be passed explicitly to
  /// `FirebaseDatabase.instanceFor(app:, databaseURL:)`.
  // static String firebaseDatabaseUrl =
  //     "https://k9rides-529a8-default-rtdb.asia-southeast1.firebasedatabase.app";

  // static const String firebaseStorageBucket =
  //     "k9rides-529a8.firebasestorage.app"; 

  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.sixamfreshuser.app';
  static String signKey = '';

  /// Fallback FirebaseOptions for manual initialization
  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseMessagingSenderId,
        projectId: firebaseProjectId,
       // databaseURL: firebaseDatabaseUrl,
       // storageBucket: firebaseStorageBucket,
      );
}
