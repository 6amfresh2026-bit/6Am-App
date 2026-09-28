import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/local_storage/shared_prefs_storage.dart';
import 'core/network/media_url.dart';
import 'core/utils/logger.dart';
import 'di/repository_providers.dart';

/// Runs in its own isolate, so nothing from the app's state is available here.
/// Notifications with a `notification` block are rendered by the OS regardless;
/// this exists so data-only messages still wake the app and are not dropped.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    await Firebase.initializeApp(options: AppConstants.firebaseOptions);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push is optional: a build without a Firebase config file must still start.
  // We first try default Firebase initialization, then fallback to AppConstants.firebaseOptions.
  try {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      await Firebase.initializeApp(options: AppConstants.firebaseOptions);
    }
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    // iOS suppresses foreground alerts unless asked; Android is handled in-app
    // by PushListener.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    AppLogger.error('Firebase init failed — push disabled', error: e);
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Keys come from config/keys.env (bundled as an asset) unless a --dart-define
  // overrides them, so the app is configured the same way however it is
  // launched.
  final config = await AppConfig.load();

  // Uploads come back root-relative (`/uploads/...`); every image field is made
  // absolute against the API host, so the origin must be known before the first
  // response is parsed.
  MediaUrl.configure(config.apiBaseUrl);

  // Storage must exist before the first provider reads it, so it is created
  // here and injected as an override rather than resolved lazily.
  final storage = await SharedPrefsStorage.create();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        appConfigProvider.overrideWithValue(config),
      ],
      child: const SuvioQuickApp(),
    ),
  );
}
