import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_user/core/config/app_config.dart';
import 'package:quick_commerce_user/core/errors/app_exception.dart';
import 'package:quick_commerce_user/core/network/dio_api_client.dart';

/// An authenticated call with no usable token must never leave the device.
///
/// It used to go out bare, come back 401, and the 401 handler then cleared the
/// session — so a customer whose token had not been restored yet was silently
/// signed out mid-flow. That surfaced as "unauthorized" when saving the first
/// address right after signing in.
class _FakeTokenStore implements AuthTokenStore {
  _FakeTokenStore({this.access, this.refresh, this.refreshSucceeds = false});

  String? access;
  String? refresh;
  bool refreshSucceeds;

  int refreshCalls = 0;
  bool cleared = false;

  @override
  String? get accessToken => access;

  @override
  String? get refreshToken => refresh;

  @override
  Future<bool> refreshSession() async {
    refreshCalls++;
    if (refreshSucceeds) access = 'refreshed-token';
    return refreshSucceeds;
  }

  @override
  Future<void> clearSession() async => cleared = true;
}

void main() {
  final config = AppConfig.fromEnvironment(
    fallbacks: const {'API_BASE_URL': 'https://example.invalid/api/v1'},
  );

  DioApiClient clientWith(_FakeTokenStore store) =>
      DioApiClient(config: config, tokenStore: store);

  group('authenticated calls without a token', () {
    test('fail fast with a message that says what to do', () async {
      final store = _FakeTokenStore();
      await expectLater(
        clientWith(store).get('/food/user/addresses', requiresAuth: true),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            contains('sign in again'),
          ),
        ),
      );
      // No refresh token, so no pointless refresh attempt either.
      expect(store.refreshCalls, 0);
    });

    test('are not attempted when only the access token is blank', () async {
      final store = _FakeTokenStore(access: '', refresh: '');
      await expectLater(
        clientWith(store).post('/food/user/addresses', requiresAuth: true),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(store.refreshCalls, 0);
    });

    test('try the refresh token first when there is one', () async {
      // Refresh fails here, so the call still stops — but it stops *after*
      // giving the stored refresh token its chance, which is what keeps a
      // recoverable session from being thrown away.
      final store = _FakeTokenStore(refresh: 'refresh-abc');
      await expectLater(
        clientWith(store).get('/food/user/subscriptions', requiresAuth: true),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(store.refreshCalls, 1);
    });

    test('proceed once a refresh restores the session', () async {
      // The whole point of trying the refresh token: a recoverable session is
      // recovered and the call goes out. It then fails on the unroutable host,
      // which is the proof it got past the auth guard rather than being
      // rejected by it.
      final store = _FakeTokenStore(
        refresh: 'refresh-abc',
        refreshSucceeds: true,
      );
      await expectLater(
        clientWith(store).get('/food/user/addresses', requiresAuth: true),
        throwsA(isA<AppException>().having(
          (e) => e is UnauthorizedException,
          'is not an auth error',
          isFalse,
        )),
      );
      expect(store.refreshCalls, 1);
      expect(store.access, 'refreshed-token');
      expect(store.cleared, isFalse);
    });
  });

  test('unauthenticated calls are unaffected by a missing token', () async {
    // A public path must not be blocked by the guard. The host is unroutable,
    // so this fails at the network layer rather than with an auth error.
    final store = _FakeTokenStore();
    await expectLater(
      clientWith(store).get('/food/admin/fee-settings/public'),
      throwsA(isA<AppException>().having(
        (e) => e is UnauthorizedException,
        'is not an auth error',
        isFalse,
      )),
    );
  });
}
