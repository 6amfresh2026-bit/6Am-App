import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/errors/app_exception.dart';
import '../../core/local_storage/local_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../data/repository_impl/api_paths.dart';

/// An incoming push, reduced to what the app acts on.
///
/// The backend sends `data.type`, `data.orderId` and a web `data.link`; only
/// the first two are portable to app routes.
class PushMessage {
  const PushMessage({
    this.title = '',
    this.body = '',
    this.data = const {},
  });

  factory PushMessage.fromRemote(RemoteMessage message) => PushMessage(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
        data: message.data.map((k, v) => MapEntry(k, '$v')),
      );

  final String title;
  final String body;
  final Map<String, String> data;

  String get type => data['type'] ?? '';

  /// The order this push is about, when it is about one.
  String get orderId => (data['orderId'] ?? data['orderMongoId'] ?? '').trim();
}

/// Push registration and delivery. The backend owns sending (FCM); the app's
/// job is to keep the server holding the current device token for the signed-in
/// user, and to react to what arrives.
abstract interface class NotificationService {
  Future<bool> requestPermission();

  Future<String?> deviceToken();

  /// Uploads the current token and keeps it fresh for the rest of the session.
  /// Safe to call more than once — a token already on the server is not resent.
  Future<void> registerDevice();

  /// Drops this device's token server-side. Called before sign-out, while the
  /// access token is still valid.
  Future<void> unregisterDevice();

  /// Pushes arriving while the app is in the foreground. Android does not
  /// render these itself, so the app surfaces them in-app.
  Stream<PushMessage> get onForegroundMessage;

  /// Notification taps that brought the app to the foreground.
  Stream<PushMessage> get onNotificationTap;

  /// The notification that cold-started the app, if any. Consumed once.
  Future<PushMessage?> initialMessage();
}

class FcmNotificationService implements NotificationService {
  FcmNotificationService(this._client, this._storage);

  final ApiClient _client;
  final LocalStorage _storage;

  StreamSubscription<String>? _refreshSubscription;

  /// What the backend was last told. Avoids re-posting the same token on every
  /// app start.
  String? _syncedToken;

  bool get _isSignedIn =>
      (_storage.getString(StorageKeys.accessToken) ?? '').isNotEmpty;

  /// The Settings switch, on by default. Guarded here rather than at each call
  /// site so a relaunch cannot quietly re-register a device the user muted.
  bool get _pushEnabled =>
      _storage.getBool(StorageKeys.notificationsEnabled) ?? true;

  @override
  Future<bool> requestPermission() async {
    try {
      // The messaging SDK owns this prompt on both platforms (iOS always,
      // Android from 13). Below Android 13 it resolves as already authorized.
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      // Same posture as `deviceToken`: no Firebase on this platform, or Play
      // Services missing. Registration continues without the prompt rather
      // than taking down the sign-in that triggered it.
      AppLogger.debug('notification permission unavailable: $e', scope: 'push');
      return false;
    }
  }

  @override
  Future<String?> deviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        AppLogger.debug('FCM TOKEN GENERATED', scope: 'push');
      }
      return token;
    } catch (e) {
      // No Firebase config on this platform, or Play Services missing. Push is
      // not worth failing a login over.
      AppLogger.debug('FCM token unavailable: $e', scope: 'push');
      return null;
    }
  }

  @override
  Future<void> registerDevice() async {
    if (!_pushEnabled) return;

    // Android 13+ denies POST_NOTIFICATIONS until the user is actually asked,
    // and the system then drops every push without a word — no error, no
    // callback, nothing in the logs. Until this call was here the only place
    // that asked was the Settings toggle, so a normal install never got the
    // prompt and never received a notification.
    //
    // Registering the token is still worth doing when the answer is no: data
    // messages continue to arrive, and the user can grant it later from
    // Settings without needing another token round trip.
    final granted = await requestPermission();
    AppLogger.debug(
      'notification permission: ${granted ? 'granted' : 'denied'}',
      scope: 'push',
    );

    // FCM rotates tokens on its own schedule; without this the backend holds a
    // dead token and the user silently stops receiving order updates.
    if (_refreshSubscription == null) {
      try {
        _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh
            .listen((token) {
          AppLogger.debug('FCM TOKEN REFRESHED', scope: 'push');
          _upload(token);
        }, onError: (Object e) {
          AppLogger.debug('FCM token refresh failed: $e', scope: 'push');
        });
      } catch (e) {
        AppLogger.debug('FCM refresh stream unavailable: $e', scope: 'push');
      }
    }

    final token = await deviceToken();
    if (token != null) await _upload(token);
  }

  @override
  Future<void> unregisterDevice() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    final token = _syncedToken ?? await deviceToken();
    _syncedToken = null;
    if (token == null || !_isSignedIn) return;

    try {
      await _client.delete(
        ApiPaths.fcmTokenRemove,
        body: {'token': token, 'platform': 'mobile'},
        requiresAuth: true,
      );
    } on AppException catch (e) {
      // Sign-out must never be blocked by this; a stale token is pruned server
      // side once FCM reports it unregistered.
      AppLogger.debug('FCM token removal failed: ${e.message}', scope: 'push');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Nothing to delete, or no Firebase on this platform.
    }
  }

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(PushMessage.fromRemote);

  @override
  Stream<PushMessage> get onNotificationTap =>
      FirebaseMessaging.onMessageOpenedApp.map(PushMessage.fromRemote);

  @override
  Future<PushMessage?> initialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : PushMessage.fromRemote(message);
    } catch (e) {
      AppLogger.debug('FCM initial message unavailable: $e', scope: 'push');
      return null;
    }
  }

  Future<void> _upload(String token) async {
    if (token.isEmpty || token == _syncedToken) return;
    if (!_isSignedIn) {
      AppLogger.debug('FCM token not sent: signed out', scope: 'push');
      return;
    }

    try {
      AppLogger.debug('FCM TOKEN SENT TO BACKEND', scope: 'push');
      await _client.post(
        ApiPaths.fcmTokenSave,
        body: {'token': token, 'platform': 'mobile'},
        requiresAuth: true,
      );
      _syncedToken = token;
      // Tail only — the token is a credential for reaching this device, and it
      // has no business sitting whole in a log. The short-token guard keeps a
      // truncated token from making the log line throw.
      final tail = token.substring(token.length < 12 ? 0 : token.length - 12);
      AppLogger.debug('FCM TOKEN SAVED SUCCESSFULLY (…$tail)', scope: 'push');
    } on AppException catch (e) {
      // Retried on the next launch, and whenever FCM rotates the token.
      AppLogger.debug('FCM TOKEN SAVE FAILED: ${e.message}', scope: 'push');
    }
  }
}
