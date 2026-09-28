import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/local_storage/local_storage.dart';
import 'package:quick_commerce_user/core/network/api_client.dart';
import 'package:quick_commerce_user/data/repository_impl/api_paths.dart';
import 'package:quick_commerce_user/navigation/route_paths.dart';
import 'package:quick_commerce_user/platform/notification/notification_service.dart';
import 'package:quick_commerce_user/platform/notification/push_listener.dart';

class _FakeStorage implements LocalStorage {
  final _values = <String, Object>{};

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String> getStringList(String key) =>
      (_values[key] as List<String>?) ?? const [];

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Records the calls the service makes instead of hitting the network.
class _RecordingClient implements ApiClient {
  final posts = <(String, Object?)>[];
  final deletes = <(String, Object?)>[];

  @override
  Future<dynamic> post(String path,
      {Object? body, Map<String, dynamic>? query, bool requiresAuth = false}) async {
    posts.add((path, body));
    return null;
  }

  @override
  Future<dynamic> delete(String path,
      {Object? body, bool requiresAuth = false}) async {
    deletes.add((path, body));
    return null;
  }

  @override
  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, bool requiresAuth = false}) async =>
      null;

  @override
  Future<dynamic> patch(String path, {Object? body, bool requiresAuth = false}) async =>
      null;

  @override
  Future<dynamic> put(String path, {Object? body, bool requiresAuth = false}) async =>
      null;
}

/// Stands in for the FCM plugin, which needs a platform channel.
class _TestPushService extends FcmNotificationService {
  _TestPushService(super.client, super.storage, {this.token});

  String? token;

  @override
  Future<String?> deviceToken() async => token;
}

/// The device token is what lets the backend reach this user at all. These
/// guards are the difference between a silent 401 on every launch and a
/// duplicate write per app start.
void main() {
  late _RecordingClient client;
  late _FakeStorage storage;
  late _TestPushService push;

  setUp(() {
    client = _RecordingClient();
    storage = _FakeStorage();
    push = _TestPushService(client, storage, token: 'tok-1');
  });

  void signIn() => storage.setString(StorageKeys.accessToken, 'access-abc');

  test('a signed-in device uploads its token to the mobile save route', () async {
    signIn();
    await push.registerDevice();

    expect(client.posts, hasLength(1));
    expect(client.posts.single.$1, ApiPaths.fcmTokenSave);
    expect(
      client.posts.single.$2,
      {'token': 'tok-1', 'platform': 'mobile'},
    );
  });

  test('a signed-out device never posts — the route is authenticated', () async {
    await push.registerDevice();
    expect(client.posts, isEmpty);
  });

  test('an unchanged token is not re-sent on the next launch', () async {
    signIn();
    await push.registerDevice();
    await push.registerDevice();

    expect(client.posts, hasLength(1));
  });

  test('a rotated token is sent again', () async {
    signIn();
    await push.registerDevice();
    push.token = 'tok-2';
    await push.registerDevice();

    expect(client.posts.map((p) => (p.$2 as Map)['token']), ['tok-1', 'tok-2']);
  });

  test('a muted device stays muted across relaunches', () async {
    signIn();
    storage.setBool(StorageKeys.notificationsEnabled, false);
    await push.registerDevice();

    expect(client.posts, isEmpty);
  });

  test('signing out removes the token while the session is still valid', () async {
    signIn();
    await push.registerDevice();
    await push.unregisterDevice();

    expect(client.deletes, hasLength(1));
    expect(client.deletes.single.$1, ApiPaths.fcmTokenRemove);
    expect((client.deletes.single.$2 as Map)['token'], 'tok-1');
  });


  group('notification tap routing', () {
    test('a new-order push opens that order', () {
      const message = PushMessage(
        data: {'type': 'order_created', 'orderId': 'o-1'},
      );

      expect(routeForPush(message), RoutePaths.orderDetailsOf('o-1'));
    });

    test('a status-change push opens live tracking', () {
      const message = PushMessage(
        data: {'type': 'order_status', 'orderId': 'o-2'},
      );

      expect(routeForPush(message), RoutePaths.orderTrackingOf('o-2'));
    });

    test('the mongo id is accepted when orderId is absent', () {
      const message = PushMessage(
        data: {'type': 'order_status', 'orderMongoId': 'o-3'},
      );

      expect(routeForPush(message), RoutePaths.orderTrackingOf('o-3'));
    });

    test('a push about nothing in particular lands in the inbox', () {
      expect(
        routeForPush(const PushMessage(data: {'type': 'promo'})),
        RoutePaths.notifications,
      );
    });
  });
}
